import Foundation
@preconcurrency import AVFoundation
import os

/// Protótipo de transcrição STREAMING (ao vivo) com Deepgram Nova-3.
///
/// Objetivo: PROVAR a fluidez do microfone nativo (ativa na hora, sem re-pedir
/// permissão, sem "clico e nada") — o bug que o Luiz tinha no laudousg web era
/// da camada navegador. Aqui é AVAudioEngine direto + WebSocket nativo.
///
/// Fluxo: backend `/api/deepgram/token` → conecta wss://api.deepgram.com/v1/listen
/// → AVAudioEngine tapa o mic → converte pra linear16/16kHz/mono → envia binário
/// (fila separada, não do thread de áudio) → recebe JSON (interim/final).
///
/// Revisado com dex1: converter sempre p/ 16000; fila de envio; receive loop
/// contínuo; separar interim/final; tratar interrupção + route change.
@Observable
@MainActor
final class DeepgramLiveService {
    // Estado pra UI
    var isStreaming = false
    var status: String = "Pronto"
    var finalText: String = ""        // transcript confirmado (acumulado)
    var interimText: String = ""      // parcial (ao vivo, ainda mudando)
    var errorMessage: String?
    /// Texto completo (final + interim) pra exibir.
    var liveTranscript: String {
        let i = interimText.isEmpty ? "" : (finalText.isEmpty ? interimText : " " + interimText)
        return finalText + i
    }

    // Métricas pra UI de gravação (espelha o que o overlay consumia do SpeechService).
    var audioLevel: Float = 0          // 0–1, nível RMS pra waveform
    var elapsed: TimeInterval = 0      // segundos de gravação
    private var startDate: Date?
    /// Contagem aproximada de palavras transcritas até agora.
    var wordCount: Int {
        liveTranscript.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }
    /// Chamado pelo timer da UI (~12 fps) pra atualizar o tempo decorrido.
    func tick() {
        if let s = startDate { elapsed = Date().timeIntervalSince(s) }
    }

    private let log = Logger(subsystem: "com.laudousg.LaudoUSG", category: "deepgram")

    // Áudio
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true
    )!

    // WebSocket
    private var wsTask: URLSessionWebSocketTask?
    private let wsSession = URLSession(configuration: .default)
    private let sendQueue = DispatchQueue(label: "com.laudousg.deepgram.send")

    // MARK: - API pública

    func start() async {
        guard !isStreaming else { return }
        errorMessage = nil
        finalText = ""
        interimText = ""
        audioLevel = 0
        elapsed = 0
        startDate = Date()
        status = "Pedindo permissão…"

        guard await requestMicPermission() else {
            errorMessage = "Permissão de microfone negada. Ajustes → LaudoUSG → Microfone."
            status = "Sem permissão"
            return
        }

        status = "Obtendo token…"
        let token: TokenInfo
        do {
            token = try await fetchToken()
        } catch {
            errorMessage = "Falha ao obter token Deepgram: \(error.localizedDescription)"
            status = "Erro de token"
            return
        }

        status = "Conectando…"
        do {
            try connectWebSocket(token: token)
            try configureAudioSession()
            try startEngine()
        } catch {
            errorMessage = "Falha ao iniciar áudio/WS: \(error.localizedDescription)"
            status = "Erro ao iniciar"
            await stop()
            return
        }

        registerNotifications()
        isStreaming = true
        status = "Ouvindo — fale…"
        log.info("deepgram streaming iniciado")
    }

    func stop() async {
        guard isStreaming || wsTask != nil else { return }
        isStreaming = false
        status = "Encerrando…"

        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        // Sinaliza fim do stream pro Deepgram e fecha.
        sendQueue.async { [wsTask] in
            wsTask?.send(.string("{\"type\":\"CloseStream\"}")) { _ in }
        }
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        unregisterNotifications()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        audioLevel = 0
        status = "Pronto"
        log.info("deepgram streaming parado")
    }

    // MARK: - Token

    private struct TokenInfo: Decodable {
        let token: String
        let scheme: String
        let temporary: Bool
        let model: String
        let language: String
    }

    private func fetchToken() async throws -> TokenInfo {
        let data = try await APIClient.shared.postRawJSON("/api/deepgram/token", body: Data("{}".utf8))
        return try JSONDecoder().decode(TokenInfo.self, from: data)
    }

    // MARK: - WebSocket

    private func connectWebSocket(token: TokenInfo) throws {
        var comps = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        comps.queryItems = [
            .init(name: "model", value: token.model),          // nova-3
            .init(name: "language", value: token.language),    // pt-BR
            .init(name: "encoding", value: "linear16"),
            .init(name: "sample_rate", value: "16000"),
            .init(name: "channels", value: "1"),
            .init(name: "interim_results", value: "true"),
            .init(name: "smart_format", value: "true"),
            .init(name: "punctuate", value: "true"),
            .init(name: "endpointing", value: "300"),
        ]
        guard let url = comps.url else { throw DeepgramError.badURL }

        var req = URLRequest(url: url)
        // Token temporário usa "Bearer"; fallback de protótipo (API key) usa "Token".
        req.setValue("\(token.scheme) \(token.token)", forHTTPHeaderField: "Authorization")

        let task = wsSession.webSocketTask(with: req)
        wsTask = task
        task.resume()
        receiveLoop()
    }

    /// Loop recursivo de recepção (URLSessionWebSocketTask entrega 1 msg por vez).
    private func receiveLoop() {
        wsTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    Task { @MainActor in self?.handleMessage(text) }
                }
                self?.receiveLoop()
            case .failure(let error):
                Task { @MainActor in self?.handleSocketError(error) }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let resp = try? JSONDecoder().decode(DeepgramResponse.self, from: data) else { return }
        let transcript = resp.channel?.alternatives?.first?.transcript ?? ""
        guard !transcript.isEmpty else { return }

        if resp.isFinal == true {
            finalText += (finalText.isEmpty ? "" : " ") + transcript
            interimText = ""
        } else {
            interimText = transcript   // parcial ao vivo
        }
    }

    private func handleSocketError(_ error: Error) {
        guard isStreaming else { return }   // ignorar erro pós-stop
        log.error("ws erro: \(error.localizedDescription)")
        errorMessage = "Conexão perdida: \(error.localizedDescription)"
        status = "Conexão caiu"
        Task { await stop() }
    }

    // MARK: - Áudio

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        let conv = AVAudioConverter(from: inputFormat, to: targetFormat)
        converter = conv

        // Captura as referências LOCALMENTE — o tap roda no thread de áudio
        // (nonisolated) e não pode tocar nas props @MainActor. Captura uma vez
        // por sessão (sem reconexão mid-stream no protótipo).
        let target = targetFormat
        let queue = sendQueue
        let task = wsTask
        // Publica o nível RMS no main actor pra waveform (sem tocar estado do tap).
        let levelSink: @Sendable (Float) -> Void = { [weak self] lvl in
            Task { @MainActor in self?.audioLevel = lvl }
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
            Self.processAndSend(buffer, inputFormat: inputFormat,
                                converter: conv, target: target, queue: queue,
                                task: task, levelSink: levelSink)
        }
        engine.prepare()
        try engine.start()
    }

    /// Converte o buffer pra linear16/16kHz e ENFILEIRA o envio (não envia do
    /// thread de áudio). Função pura — não toca em estado isolado.
    private nonisolated static func processAndSend(
        _ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat,
        converter: AVAudioConverter?, target: AVAudioFormat,
        queue: DispatchQueue, task: URLSessionWebSocketTask?,
        levelSink: @Sendable (Float) -> Void
    ) {
        guard let converter else { return }
        let ratio = target.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

        var consumed = false
        var convError: NSError?
        converter.convert(to: outBuffer, error: &convError) { _, outStatus in
            if consumed { outStatus.pointee = .noDataNow; return nil }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard convError == nil, outBuffer.frameLength > 0,
              let channel = outBuffer.int16ChannelData else { return }

        let frames = Int(outBuffer.frameLength)
        // Nível RMS normalizado (0–1) com curva agradável pra waveform.
        var sumSquares: Double = 0
        for i in 0..<frames {
            let s = Double(channel[0][i]) / 32768.0
            sumSquares += s * s
        }
        let rms = frames > 0 ? (sumSquares / Double(frames)).squareRoot() : 0
        let level = Float(min(1.0, rms * 3.2))   // ganho visual
        levelSink(level)

        let byteCount = frames * MemoryLayout<Int16>.size
        let data = Data(bytes: channel[0], count: byteCount)
        queue.async { task?.send(.data(data)) { _ in } }
    }

    // MARK: - Permissão

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    // MARK: - Interrupções / route change

    private func registerNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
    }
    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc private nonisolated func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            Task { @MainActor in
                self.status = "Interrompido (ligação/áudio)"
                await self.stop()
            }
        }
    }

    @objc private nonisolated func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        if reason == .oldDeviceUnavailable {   // ex.: tirou o fone
            Task { @MainActor in
                self.status = "Fonte de áudio mudou"
                await self.stop()
            }
        }
    }
}

private enum DeepgramError: Error { case badURL }

/// Resposta de streaming do Deepgram.
private struct DeepgramResponse: Decodable {
    let isFinal: Bool?
    let speechFinal: Bool?
    let channel: Channel?

    enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case speechFinal = "speech_final"
        case channel
    }
    struct Channel: Decodable {
        let alternatives: [Alternative]?
    }
    struct Alternative: Decodable {
        let transcript: String?
    }
}
