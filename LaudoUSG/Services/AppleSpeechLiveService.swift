import Foundation
@preconcurrency import AVFoundation
import Observation
import Speech
import os

/// Transcrição STREAMING **on-device** com o `SpeechTranscriber` da Apple (iOS 26+).
///
/// Contraparte do `DeepgramLiveService`: mesma superfície observável (`LiveMicEngine`),
/// motor completamente diferente — nada de rede, nada de token, áudio nunca sai do
/// aparelho.
///
/// Pipeline: `AVAudioEngine` tapa o mic → converte pro formato que o analisador pede
/// → `AsyncStream<AnalyzerInput>` → `SpeechAnalyzer` → `transcriber.results`
/// (voláteis = parcial ao vivo; finais = confirmado).
///
/// LIMITAÇÕES conhecidas, deliberadas:
/// - Não aceita glossário. `contextualStrings` do `AnalysisContext` só vale pro
///   `DictationTranscriber`, não pro `SpeechTranscriber`. Ou seja: os 110 keyterms
///   médicos do backend NÃO têm efeito aqui. É exatamente isso que o teste mede.
/// - Não existe no watchOS.
/// - O modelo do idioma é baixado sob demanda na primeira vez (ver `prewarm()`).
@available(iOS 26.0, *)
@Observable
@MainActor
final class AppleSpeechLiveService: LiveMicEngine {
    // Estado pra UI — espelha o DeepgramLiveService.
    var isStreaming = false
    /// On-device não reconecta (não há conexão). Sempre falso.
    var isReconnecting = false
    var status: String = "Pronto"
    var finalText: String = ""
    var interimText: String = ""
    var errorMessage: String?

    var liveTranscript: String {
        let i = interimText.isEmpty ? "" : (finalText.isEmpty ? interimText : " " + interimText)
        return finalText + i
    }

    var audioLevel: Float = 0
    var elapsed: TimeInterval = 0
    private var startDate: Date?

    var wordCount: Int {
        liveTranscript.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }

    func tick() {
        if let s = startDate { elapsed = Date().timeIntervalSince(s) }
    }

    /// Casa com o nome que o usuário escolheu em Preferências → Ditado.
    var engineLabel: String? { "NATIVA · NO APARELHO" }

    private let log = Logger(subsystem: "com.laudousg.LaudoUSG", category: "apple-speech")

    // Áudio
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?

    // Speech
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    /// Formato que o analisador aceita — descoberto no prewarm, não na hora do toque.
    private var analyzerFormat: AVAudioFormat?
    private var isPrepared = false

    private let localeIdentifier = "pt_BR"

    // MARK: - Preparação (modelo + formato)

    /// Garante que o modelo de pt-BR está instalado e que sabemos o formato de áudio.
    /// Na PRIMEIRA vez isso baixa o modelo (dezenas a centenas de MB) — por isso roda
    /// ao abrir a tela, não no toque do microfone.
    func prewarm() async {
        guard !isPrepared, !isStreaming else { return }
        do {
            try await prepare()
        } catch {
            log.error("prewarm falhou: \(error.localizedDescription, privacy: .public)")
            // Não vira errorMessage aqui: o prewarm é silencioso. O erro real
            // aparece no start(), onde o usuário está esperando resposta.
        }
    }

    private func prepare() async throws {
        guard SpeechTranscriber.isAvailable else {
            throw AppleSpeechError.unavailable
        }

        let requested = Locale(identifier: localeIdentifier)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
            throw AppleSpeechError.localeUnsupported(localeIdentifier)
        }

        // `.volatileResults` = parciais ao vivo (equivalente ao interim_results do
        // Deepgram). Sem eles, o texto só apareceria ao final de cada trecho.
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        // Download do modelo do idioma, se ainda não estiver instalado.
        let installStatus = await AssetInventory.status(forModules: [transcriber])
        if installStatus != .installed {
            status = "Baixando modelo de voz…"
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        }
        // Reserva o idioma pra o sistema não recuperar o espaço. Best-effort:
        // se estourar o limite de locales reservados, seguimos assim mesmo.
        _ = try? await AssetInventory.reserve(locale: locale)

        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard analyzerFormat != nil else { throw AppleSpeechError.noCompatibleFormat }

        isPrepared = true
        status = "Pronto"
        log.info("apple speech pronto — locale=\(locale.identifier(.bcp47), privacy: .public)")
    }

    // MARK: - Start / Stop

    func start() async {
        guard !isStreaming else { return }
        errorMessage = nil
        finalText = ""; interimText = ""
        audioLevel = 0; elapsed = 0; startDate = Date()
        status = "Pedindo permissão…"

        guard await requestMicPermission() else {
            errorMessage = "Permissão de microfone negada. Ajustes → LaudoUSG → Microfone."
            status = "Sem permissão"
            return
        }
        // O reconhecimento roda no aparelho, mas o sistema ainda pede este
        // consentimento. Se for negado, seguimos — e o erro real (se houver)
        // aparece no stream de resultados, com mensagem específica.
        _ = await requestSpeechAuthorization()

        if !isPrepared {
            status = "Preparando…"
            do {
                try await prepare()
            } catch {
                errorMessage = Self.message(for: error)
                status = "Indisponível"
                return
            }
        }

        guard let transcriber, let analyzerFormat else {
            errorMessage = "Motor de voz não inicializou."
            status = "Indisponível"
            return
        }

        status = "Iniciando…"
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        // Consome os resultados ANTES de começar a mandar áudio.
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    self.handle(result)
                }
            } catch {
                guard let self else { return }
                self.log.error("results falhou: \(error.localizedDescription, privacy: .public)")
                self.errorMessage = Self.message(for: error)
                await self.stop()
            }
        }

        do {
            try await analyzer.start(inputSequence: stream)
            try configureAudioSession()
            try startEngine(target: analyzerFormat, continuation: continuation)
        } catch {
            errorMessage = "Falha ao iniciar o áudio: \(error.localizedDescription)"
            status = "Erro ao iniciar"
            await stop()
            return
        }

        registerNotifications()
        isStreaming = true
        status = "Ouvindo — fale…"
        log.info("apple speech streaming iniciado")
    }

    func stop() async {
        guard isStreaming || analyzer != nil else { return }
        isStreaming = false
        status = "Encerrando…"

        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        // Fecha a entrada e deixa o analisador emitir o último resultado final —
        // é isso que garante que o fim da fala não se perde.
        inputContinuation?.finish()
        inputContinuation = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil

        resultsTask?.cancel()
        resultsTask = nil

        unregisterNotifications()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        audioLevel = 0
        status = "Pronto"
        log.info("apple speech streaming parado")
    }

    // MARK: - Resultados

    private func handle(_ result: SpeechTranscriber.Result) {
        let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if result.isFinal {
            // Dedupe leve, mesmo critério do Deepgram.
            if !finalText.hasSuffix(text) {
                finalText += (finalText.isEmpty ? "" : " ") + text
            }
            interimText = ""
        } else {
            interimText = text   // volátil: será substituído até virar final
        }
    }

    // MARK: - Áudio

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // MESMA configuração do Deepgram — pra que o teste mude UMA variável
        // (o reconhecedor), não duas.
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startEngine(
        target: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) throws {
        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        guard let conv = AVAudioConverter(from: inputFormat, to: target) else {
            throw AppleSpeechError.noCompatibleFormat
        }
        converter = conv

        // O tap roda no thread de áudio (nonisolated) e não pode tocar em
        // propriedades @MainActor — captura só referências locais.
        let levelSink: @Sendable (Float) -> Void = { [weak self] lvl in
            Task { @MainActor in self?.audioLevel = lvl }
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
            Self.processAndYield(
                buffer, inputFormat: inputFormat, converter: conv, target: target,
                continuation: continuation, levelSink: levelSink
            )
        }
        engine.prepare()
        try engine.start()
    }

    /// Converte o buffer do mic pro formato do analisador e entrega no stream.
    private nonisolated static func processAndYield(
        _ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat,
        converter: AVAudioConverter, target: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        levelSink: @Sendable (Float) -> Void
    ) {
        // Nível RMS a partir do buffer CRU do mic (float32) — pra waveform.
        if let ch = buffer.floatChannelData, buffer.frameLength > 0 {
            let frames = Int(buffer.frameLength)
            var sumSquares: Double = 0
            for i in 0..<frames {
                let s = Double(ch[0][i])
                sumSquares += s * s
            }
            let rms = (sumSquares / Double(frames)).squareRoot()
            levelSink(Float(min(1.0, rms * 3.2)))
        }

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
        guard convError == nil, outBuffer.frameLength > 0 else { return }

        continuation.yield(AnalyzerInput(buffer: outBuffer))
    }

    // MARK: - Permissões

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                cont.resume(returning: authStatus == .authorized)
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
        if reason == .oldDeviceUnavailable {
            Task { @MainActor in
                self.status = "Fonte de áudio mudou"
                await self.stop()
            }
        }
    }

    // MARK: - Erros

    private static func message(for error: Error) -> String {
        if let e = error as? AppleSpeechError { return e.localizedDescription }
        return "Falha no reconhecimento no aparelho: \(error.localizedDescription)"
    }
}

enum AppleSpeechError: LocalizedError {
    case unavailable
    case localeUnsupported(String)
    case noCompatibleFormat

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Reconhecimento no aparelho indisponível neste iPhone."
        case .localeUnsupported(let id):
            return "O idioma \(id) não está disponível para reconhecimento no aparelho."
        case .noCompatibleFormat:
            return "Formato de áudio incompatível com o reconhecedor do sistema."
        }
    }
}
