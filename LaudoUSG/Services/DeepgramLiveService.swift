import Foundation
@preconcurrency import AVFoundation
import os

/// Holder THREAD-SAFE da conexão WS corrente. Permite RECONECTAR sem reinstalar
/// o tap do microfone: o tap (thread de áudio) envia sempre pra conexão atual,
/// e a reconexão só troca o task aqui dentro. Tem fila própria pra não bloquear
/// o thread de render de áudio.
private final class WSConnection: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionWebSocketTask?
    private var pending = 0
    private let maxPending = 64   // ~1-2s de áudio; dropa o excesso (limita memória)
    private let queue = DispatchQueue(label: "com.laudousg.deepgram.send")

    func set(_ t: URLSessionWebSocketTask?) {
        lock.lock(); task = t; lock.unlock()
    }
    func send(_ data: Data) {
        lock.lock()
        // Dropa SEM enfileirar quando não há conexão (reconectando) ou a fila
        // está cheia — evita crescimento de memória se a rede cair (dex1).
        guard task != nil, pending < maxPending else { lock.unlock(); return }
        pending += 1
        lock.unlock()
        queue.async { [weak self] in
            guard let self else { return }
            self.lock.lock(); let t = self.task; self.lock.unlock()
            t?.send(.data(data)) { _ in }
            self.lock.lock(); self.pending -= 1; self.lock.unlock()
        }
    }
}

/// Transcrição STREAMING (ao vivo) com Deepgram Nova-3.
///
/// AVAudioEngine tapa o mic → converte pra linear16/16kHz/mono → WebSocket nativo
/// → recebe JSON (interim/final). Robustez: PRÉ-AQUECIMENTO do token (início
/// instantâneo), AUTO-RECONEXÃO em queda de rede (mantém o texto), FALLBACK de
/// keyterms (reconecta sem eles se a conexão com keyterms falhar).
///
/// Revisado com dex1: converter p/ 16000; fila de envio; receive loop por task;
/// keyterms via URLComponents sem encoding manual; tratar erro de handshake como
/// erro de conexão (não de mic).
@Observable
@MainActor
final class DeepgramLiveService {
    // Estado pra UI
    var isStreaming = false
    var isReconnecting = false
    var status: String = "Pronto"
    var finalText: String = ""        // transcript confirmado (acumulado)
    var interimText: String = ""      // parcial (ao vivo, ainda mudando)
    var errorMessage: String?
    /// Texto completo (final + interim) pra exibir.
    var liveTranscript: String {
        let i = interimText.isEmpty ? "" : (finalText.isEmpty ? interimText : " " + interimText)
        return finalText + i
    }

    // Métricas pra UI de gravação.
    var audioLevel: Float = 0          // 0–1, nível RMS pra waveform
    var elapsed: TimeInterval = 0      // segundos de gravação
    private var startDate: Date?
    var wordCount: Int {
        liveTranscript.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }
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
    private let connection = WSConnection()
    private let wsSession = URLSession(configuration: .default)

    // Token / pré-aquecimento
    private var currentToken: TokenInfo?
    private var prewarmedToken: TokenInfo?

    // Reconexão + fallback de keyterms
    private var reconnectAttempts = 0
    private let maxReconnects = 4
    private var lastReconnectAt: Date?
    private var receivedAnyTranscript = false
    private var keytermsDisabled = false

    // MARK: - Pré-aquecimento

    /// Busca o token ANTES do toque no mic (ex.: ao abrir a tela de gerar) e
    /// cacheia, pra o início ficar instantâneo. A key direta não expira (modo
    /// protótipo); quando virar token temporário, re-busca se expirar.
    func prewarm() async {
        guard prewarmedToken == nil, !isStreaming else { return }
        if let t = try? await fetchToken() {
            prewarmedToken = t
            log.info("deepgram: token pré-aquecido")
        }
    }

    // MARK: - Start / Stop

    func start() async {
        guard !isStreaming else { return }
        errorMessage = nil
        finalText = ""; interimText = ""
        audioLevel = 0; elapsed = 0; startDate = Date()
        reconnectAttempts = 0; receivedAnyTranscript = false
        keytermsDisabled = false; isReconnecting = false
        status = "Pedindo permissão…"

        guard await requestMicPermission() else {
            errorMessage = "Permissão de microfone negada. Ajustes → LaudoUSG → Microfone."
            status = "Sem permissão"
            return
        }

        status = "Obtendo token…"
        let token: TokenInfo
        if let pre = prewarmedToken {
            token = pre; prewarmedToken = nil   // usa o pré-aquecido
        } else {
            do { token = try await fetchToken() }
            catch {
                errorMessage = "Falha ao obter token Deepgram: \(error.localizedDescription)"
                status = "Erro de token"
                return
            }
        }
        currentToken = token

        status = "Conectando…"
        do {
            try connect(token: token, withKeyterms: true)
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
        isReconnecting = false
        status = "Encerrando…"

        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        // Sinaliza fim do stream pro Deepgram e fecha.
        wsTask?.send(.string("{\"type\":\"CloseStream\"}")) { _ in }
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        connection.set(nil)
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
        let keyterms: [String]?   // boost de vocabulário (controlado pelo backend)
    }

    private func fetchToken() async throws -> TokenInfo {
        let data = try await APIClient.shared.postRawJSON("/api/deepgram/token", body: Data("{}".utf8))
        return try JSONDecoder().decode(TokenInfo.self, from: data)
    }

    // MARK: - WebSocket

    private func connect(token: TokenInfo, withKeyterms: Bool) throws {
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
            .init(name: "numerals", value: "true"),   // medidas como dígitos (2,5 cm)
            .init(name: "endpointing", value: "300"),
        ]
        // Keyterm Prompting: 1 query item por termo (URLComponents URL-encoda os
        // espaços — sem encoding manual, dex1). Vem do backend (tunar/desligar
        // sem rebuild). `withKeyterms` false = fallback se a conexão com eles falhar.
        let keyterms = withKeyterms ? (token.keyterms ?? []) : []
        comps.queryItems?.append(contentsOf: keyterms.map {
            URLQueryItem(name: "keyterm", value: $0)
        })
        guard let url = comps.url else { throw DeepgramError.badURL }
        log.info("deepgram WS: urlLen=\(url.absoluteString.count) keyterms=\(keyterms.count)")

        var req = URLRequest(url: url)
        req.setValue("\(token.scheme) \(token.token)", forHTTPHeaderField: "Authorization")

        let task = wsSession.webSocketTask(with: req)
        wsTask = task
        connection.set(task)   // o tap passa a enviar pra ESTA conexão
        task.resume()
        receiveLoop(for: task)
    }

    /// Loop recursivo de recepção, AMARRADO ao task (pra ignorar erros de uma
    /// conexão antiga já substituída por reconexão).
    private func receiveLoop(for task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    Task { @MainActor in self?.handleMessage(text, from: task) }
                }
                self?.receiveLoop(for: task)
            case .failure(let error):
                Task { @MainActor in self?.handleSocketError(error, on: task) }
            }
        }
    }

    private func handleMessage(_ text: String, from task: URLSessionWebSocketTask) {
        guard task === wsTask else { return }   // ignora msg de conexão ANTIGA (evita duplicar — dex1)
        guard let data = text.data(using: .utf8),
              let resp = try? JSONDecoder().decode(DeepgramResponse.self, from: data) else { return }
        let transcript = resp.channel?.alternatives?.first?.transcript ?? ""
        guard !transcript.isEmpty else { return }

        receivedAnyTranscript = true
        if isReconnecting { isReconnecting = false; status = "Ouvindo — fale…" }
        // Reseta o orçamento de reconexão só após ESTABILIDADE (>8s desde a última
        // reconexão) — evita reconectar pra sempre se a rede oscilar (dex1).
        if let last = lastReconnectAt, Date().timeIntervalSince(last) > 8 {
            reconnectAttempts = 0
            lastReconnectAt = nil
        }

        if resp.isFinal == true {
            // Dedupe leve: não repete a última frase final (eco de reconexão).
            if !finalText.hasSuffix(transcript) {
                finalText += (finalText.isEmpty ? "" : " ") + transcript
            }
            interimText = ""
        } else {
            interimText = transcript   // parcial ao vivo
        }
    }

    private func handleSocketError(_ error: Error, on task: URLSessionWebSocketTask) {
        guard isStreaming else { return }           // ignora erro pós-stop
        guard task === wsTask else { return }       // ignora erro de conexão antiga
        log.error("ws erro: \(error.localizedDescription)")

        // FALLBACK DE KEYTERMS: nunca recebeu transcript + keyterms estavam ligados
        // → suspeita deles. Reconecta SEM keyterms (não conta como retry de rede).
        if !receivedAnyTranscript, !keytermsDisabled,
           let token = currentToken, !((token.keyterms ?? []).isEmpty) {
            keytermsDisabled = true
            log.error("deepgram: reconectando SEM keyterms (suspeita de falha por keyterm)")
            reconnect(reason: "Otimizando…")
            return
        }

        // AUTO-RECONEXÃO: queda no meio do ditado → reconecta mantendo o texto.
        if reconnectAttempts < maxReconnects {
            reconnectAttempts += 1
            reconnect(reason: "Reconectando…")
            return
        }

        // Esgotou as tentativas → desiste (texto já transcrito fica preservado).
        errorMessage = "Conexão perdida. O texto até aqui foi mantido."
        Task { await stop() }
    }

    private func reconnect(reason: String) {
        guard isStreaming else { return }
        isReconnecting = true
        lastReconnectAt = Date()
        interimText = ""              // descarta o parcial pendente da conexão caída
        status = reason
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        connection.set(nil)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)   // backoff curto
            guard isStreaming else { return }
            // Re-busca token (fresco; barato com skip-grant), fallback p/ o atual.
            let token = (try? await fetchToken()) ?? currentToken
            guard let token, isStreaming else {
                errorMessage = "Não foi possível reconectar."
                await stop(); return
            }
            currentToken = token
            do {
                try connect(token: token, withKeyterms: !keytermsDisabled)
                // o status volta a "Ouvindo" quando chegar o 1º transcript
            } catch {
                if reconnectAttempts < maxReconnects {
                    reconnectAttempts += 1
                    reconnect(reason: "Reconectando…")
                } else {
                    errorMessage = "Não foi possível reconectar."
                    await stop()
                }
            }
        }
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

        // Captura referências LOCAIS — o tap roda no thread de áudio (nonisolated)
        // e não pode tocar nas props @MainActor. A `connection` é estável (a
        // reconexão só troca o task DENTRO dela), então o tap sobrevive à reconexão.
        let target = targetFormat
        let conn = connection
        let levelSink: @Sendable (Float) -> Void = { [weak self] lvl in
            Task { @MainActor in self?.audioLevel = lvl }
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
            Self.processAndSend(buffer, inputFormat: inputFormat,
                                converter: conv, target: target,
                                connection: conn, levelSink: levelSink)
        }
        engine.prepare()
        try engine.start()
    }

    /// Converte o buffer pra linear16/16kHz e envia pra conexão CORRENTE (não
    /// bloqueia o thread de áudio — a WSConnection tem fila própria).
    private nonisolated static func processAndSend(
        _ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat,
        converter: AVAudioConverter?, target: AVAudioFormat,
        connection: WSConnection, levelSink: @Sendable (Float) -> Void
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
        // Nível RMS normalizado (0–1) pra waveform.
        var sumSquares: Double = 0
        for i in 0..<frames {
            let s = Double(channel[0][i]) / 32768.0
            sumSquares += s * s
        }
        let rms = frames > 0 ? (sumSquares / Double(frames)).squareRoot() : 0
        levelSink(Float(min(1.0, rms * 3.2)))

        let byteCount = frames * MemoryLayout<Int16>.size
        connection.send(Data(bytes: channel[0], count: byteCount))
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
