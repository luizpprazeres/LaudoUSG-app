import Foundation
import AVFoundation
import os

enum SpeechServiceError: Error, LocalizedError {
    case permissionDenied
    case recorderFailed(String)
    case audioTooShort
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permissão de microfone negada. Habilite em Ajustes."
        case .recorderFailed(let msg):
            return "Falha ao iniciar gravação: \(msg)"
        case .audioTooShort:
            return "Gravação muito curta. Fale por pelo menos 1 segundo."
        case .transcriptionFailed(let msg):
            return "Falha ao transcrever áudio: \(msg)"
        }
    }
}

@Observable
@MainActor
final class SpeechService {
    private(set) var isRecording: Bool = false
    private(set) var isTranscribing: Bool = false
    /// Sub-estágio do isTranscribing — pra UX mostrar "Enviando áudio..." vs "Aguardando IA...".
    private(set) var transcribingStage: TranscribingStage = .idle
    private(set) var currentTranscript: String = ""
    private(set) var lastError: SpeechServiceError?
    private(set) var elapsed: TimeInterval = 0
    /// Amplitude normalizada (0.0–1.0) do último tick. UI usa isso pra waveform.
    private(set) var currentLevel: Float = 0
    /// Palavras estimadas por tempo de fala ativa (~0.35s por palavra acima de threshold).
    private(set) var estimatedWordCount: Int = 0

    enum TranscribingStage {
        case idle
        case uploading      // áudio sendo enviado pro backend
        case processing     // IA transcrevendo
    }

    private let log = Logger(subsystem: "com.laudousg.LaudoUSG", category: "Speech")
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var startedAt: Date?
    private var activeSpeechSeconds: Double = 0
    private var lastTickAt: Date?

    func requestPermissions() async -> Bool {
        let granted: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        log.info("Mic permission granted: \(granted, privacy: .public)")
        if !granted { lastError = .permissionDenied }
        return granted
    }

    func start() async throws {
        guard !isRecording, !isTranscribing else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("AudioSession setCategory/setActive failed: \(error.localizedDescription, privacy: .public)")
            throw SpeechServiceError.recorderFailed(error.localizedDescription)
        }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("laudousg-rec-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 32000,
        ]

        do {
            let recorder = try AVAudioRecorder(url: tmpURL, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord() else {
                throw SpeechServiceError.recorderFailed("prepareToRecord retornou false")
            }
            guard recorder.record() else {
                throw SpeechServiceError.recorderFailed("record() retornou false")
            }
            self.recorder = recorder
            self.fileURL = tmpURL
            self.startedAt = Date()
            self.lastTickAt = Date()
            self.elapsed = 0
            self.currentLevel = 0
            self.activeSpeechSeconds = 0
            self.estimatedWordCount = 0
            self.currentTranscript = ""
            self.lastError = nil
            self.isRecording = true
            self.transcribingStage = .idle
            log.info("Recording started -> \(tmpURL.lastPathComponent, privacy: .public)")
        } catch let error as SpeechServiceError {
            lastError = error
            throw error
        } catch {
            let serviceError = SpeechServiceError.recorderFailed(error.localizedDescription)
            lastError = serviceError
            throw serviceError
        }
    }

    @discardableResult
    func stop() async -> String {
        guard let recorder, let fileURL else {
            cleanupSession()
            return ""
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        isRecording = false
        log.info("Recording stopped. duration=\(duration, privacy: .public)s")

        guard duration >= 0.6 else {
            lastError = .audioTooShort
            removeFile(at: fileURL)
            self.fileURL = nil
            cleanupSession()
            return ""
        }

        isTranscribing = true
        transcribingStage = .uploading
        defer {
            isTranscribing = false
            transcribingStage = .idle
        }

        do {
            let transcript = try await uploadAndTranscribe(fileURL: fileURL)
            currentTranscript = transcript
            log.info("Transcript received. chars=\(transcript.count, privacy: .public)")
            removeFile(at: fileURL)
            self.fileURL = nil
            cleanupSession()
            return transcript
        } catch {
            log.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            lastError = .transcriptionFailed(error.localizedDescription)
            removeFile(at: fileURL)
            self.fileURL = nil
            cleanupSession()
            return ""
        }
    }

    func cancel() {
        if let recorder { recorder.stop() }
        if let fileURL { removeFile(at: fileURL) }
        self.recorder = nil
        self.fileURL = nil
        isRecording = false
        isTranscribing = false
        transcribingStage = .idle
        currentTranscript = ""
        currentLevel = 0
        estimatedWordCount = 0
        activeSpeechSeconds = 0
        cleanupSession()
    }

    /// Chamado pela UI a cada ~80ms. Atualiza elapsed, amplitude do mic e contador de palavras estimado.
    func tick() {
        guard isRecording, let startedAt, let recorder else { return }
        elapsed = Date().timeIntervalSince(startedAt)

        recorder.updateMeters()
        // averagePower retorna dB de -160 (silêncio) a 0 (saturado). Normalizamos pra 0–1.
        let db = recorder.averagePower(forChannel: 0)
        let normalized = Self.normalizeLevel(db: db)
        currentLevel = normalized

        // Estima palavras: tempo "acima de threshold" / 0.35s ≈ 1 palavra
        let now = Date()
        let delta = lastTickAt.map { now.timeIntervalSince($0) } ?? 0
        lastTickAt = now
        if normalized > 0.18 {
            activeSpeechSeconds += delta
        }
        estimatedWordCount = max(0, Int((activeSpeechSeconds / 0.35).rounded()))
    }

    /// Mapeia dB do AVAudioRecorder pra 0–1 com curva agradável de visualização.
    private static func normalizeLevel(db: Float) -> Float {
        let minDb: Float = -50   // tudo abaixo disso é "silêncio" visual
        let maxDb: Float = -8    // ponto onde a barra fica cheia
        if db < minDb { return 0 }
        if db > maxDb { return 1 }
        let linear = (db - minDb) / (maxDb - minDb)
        // Aplica curva pra deixar o meio mais expressivo
        return pow(linear, 0.7)
    }

    private func cleanupSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func removeFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func uploadAndTranscribe(fileURL: URL) async throws -> String {
        struct Response: Decodable { let transcript: String }
        let result = try await APIClient.shared.postMultipart(
            "/api/transcribe",
            fileURL: fileURL,
            fileName: "recording.m4a",
            fieldName: "audio",
            mimeType: "audio/m4a",
            as: Response.self
        )
        return result.transcript
    }
}
