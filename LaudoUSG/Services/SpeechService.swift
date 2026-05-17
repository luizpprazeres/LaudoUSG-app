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
    private(set) var currentTranscript: String = ""
    private(set) var lastError: SpeechServiceError?
    private(set) var elapsed: TimeInterval = 0

    private let log = Logger(subsystem: "com.laudousg.LaudoUSG", category: "Speech")
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var startedAt: Date?

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
            recorder.isMeteringEnabled = false
            guard recorder.prepareToRecord() else {
                throw SpeechServiceError.recorderFailed("prepareToRecord retornou false")
            }
            guard recorder.record() else {
                throw SpeechServiceError.recorderFailed("record() retornou false")
            }
            self.recorder = recorder
            self.fileURL = tmpURL
            self.startedAt = Date()
            self.elapsed = 0
            self.currentTranscript = ""
            self.lastError = nil
            self.isRecording = true
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
        defer { isTranscribing = false }

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
        currentTranscript = ""
        cleanupSession()
    }

    func tick() {
        guard isRecording, let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)
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
