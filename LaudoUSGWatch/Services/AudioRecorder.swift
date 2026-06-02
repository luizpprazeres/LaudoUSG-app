import AVFoundation
import Foundation
import os

@Observable
@MainActor
final class AudioRecorder {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var reachedLimit = false
    var hasPendingAudio: Bool { fileURL != nil }

    private let log = Logger(subsystem: "com.laudousg.LaudoUSG.watch", category: "Audio")
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var startedAt: Date?
    private var timerTask: Task<Void, Never>?

    func start() async throws {
        guard !isRecording, fileURL == nil else { return }
        let allowed = await requestPermission()
        guard allowed else { throw AudioRecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            log.error("AVAudioSession setup falhou: \(error.localizedDescription, privacy: .public)")
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            throw AudioRecorderError.startFailed
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("laudousg-watch-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 32000,
        ]
        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            log.error("AVAudioRecorder init falhou: \(error.localizedDescription, privacy: .public)")
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            try? FileManager.default.removeItem(at: url)
            throw AudioRecorderError.startFailed
        }
        guard recorder.prepareToRecord(), recorder.record() else {
            log.error("AVAudioRecorder prepare/record retornou false")
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            try? FileManager.default.removeItem(at: url)
            throw AudioRecorderError.startFailed
        }
        self.recorder = recorder
        self.fileURL = url
        startedAt = Date()
        elapsed = 0
        reachedLimit = false
        isRecording = true
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                self?.tick()
            }
        }
        log.info("Recording started")
    }

    func stop() throws -> URL {
        guard let fileURL else { throw AudioRecorderError.missingRecording }
        finishRecording()
        self.fileURL = nil
        guard elapsed >= 0.6 else {
            try? FileManager.default.removeItem(at: fileURL)
            throw AudioRecorderError.tooShort
        }
        log.info("Recording stopped after \(self.elapsed, privacy: .public)s")
        return fileURL
    }

    func cancel() {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        timerTask?.cancel()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        recorder = nil
        fileURL = nil
        timerTask = nil
        startedAt = nil
        isRecording = false
        elapsed = 0
        reachedLimit = false
    }

    private func tick() {
        guard let startedAt else { return }
        elapsed = Date().timeIntervalSince(startedAt)
        if elapsed >= APIConfig.maxRecordingSeconds {
            reachedLimit = true
            finishAutomatic()
        }
    }

    private func finishAutomatic() {
        finishRecording()
        log.info("Recording reached automatic limit")
    }

    private func finishRecording() {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        timerTask?.cancel()
        timerTask = nil
        startedAt = nil
        recorder = nil
        isRecording = false
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case startFailed
    case missingRecording
    case tooShort

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Permita o microfone para gravar."
        case .startFailed: return "Não foi possível iniciar a gravação."
        case .missingRecording: return "Gravação não encontrada."
        case .tooShort: return "Gravação muito curta."
        }
    }
}
