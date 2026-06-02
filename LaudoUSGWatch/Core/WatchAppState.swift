import Foundation
import os

enum WatchRoute {
    case setup
    case categories
    case recording(CategoryWatch)
    case generating(CategoryWatch)
}

@Observable
@MainActor
final class WatchAppState {
    private(set) var route: WatchRoute = .setup
    private(set) var isBusy = false
    private(set) var success = false
    private(set) var generationPhase: String?
    var errorMessage: String?
    let recorder = AudioRecorder()

    private let runtimeSession = RuntimeSessionController()
    private let log = Logger(subsystem: "com.laudousg.LaudoUSG.watch", category: "AppState")
    private var audioURL: URL?
    private var isGeneratingNow = false
    private var isTogglingRecording = false
    private(set) var transcribeError = false
    var canGenerate: Bool { audioURL != nil || recorder.hasPendingAudio }

    init() {
        let hasPairingCode = KeychainStore.read("sala.pairingCode") != nil
        let hasSession = KeychainStore.read("auth.session") != nil
        route = hasPairingCode && hasSession ? .categories : .setup
    }

    func configure(email: String, password: String, pairingCode: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await WatchAuthService.shared.signIn(email: email, password: password)
            _ = try await SalaService.redeem(pairingCode: pairingCode)
            route = .categories
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ category: CategoryWatch) {
        cleanupAllResources()
        errorMessage = nil
        route = .recording(category)
    }

    func toggleRecording() async {
        guard !isTogglingRecording, !isGeneratingNow else { return }
        isTogglingRecording = true
        defer { isTogglingRecording = false }
        errorMessage = nil
        transcribeError = false
        do {
            if recorder.isRecording || recorder.hasPendingAudio {
                audioURL = try recorder.stop()
                // Mantém runtime session ATIVA até gerar/cancelar — Watch hiberna
                // entre stop e tap "Gerar" se sair daqui.
            } else {
                if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
                audioURL = nil
                // Inicia runtime session ANTES de gravar — sem isso, Watch hiberna
                // ao abaixar o pulso e a gravação é interrompida ou o app some.
                runtimeSession.start()
                try await recorder.start()
            }
        } catch {
            cleanupAllResources()
            errorMessage = error.localizedDescription
        }
    }

    func cancelRecording() {
        cleanupAllResources()
        route = .categories
    }

    func generate(category: CategoryWatch) async {
        guard !isGeneratingNow else { return }
        isGeneratingNow = true
        defer { isGeneratingNow = false }
        if audioURL == nil, recorder.hasPendingAudio {
            audioURL = try? recorder.stop()
        }
        guard let audioURL else {
            errorMessage = "Grave o ditado antes de gerar."
            cleanupAllResources()
            return
        }
        route = .generating(category)
        isBusy = true
        success = false
        errorMessage = nil
        // Runtime session já deveria estar ativa desde toggleRecording, mas
        // chamamos start() idempotente como guard caso o user clique Gerar de
        // uma transição sem passar por toggleRecording.
        runtimeSession.start()
        let phases = [
            "Transcrevendo",
            "Analisando achados",
            "Aplicando regras",
            "Gerando texto",
            "Enviando à sala",
        ]
        let phaseTask = Task { @MainActor [weak self] in
            for phase in phases {
                self?.generationPhase = phase
                try? await Task.sleep(for: .seconds(Double.random(in: 3.5...4.5)))
                if Task.isCancelled { return }
            }
        }
        defer {
            phaseTask.cancel()
            generationPhase = nil
            runtimeSession.stop()
            isBusy = false
        }
        do {
            let transcript: String
            do {
                transcript = try await TranscribeService.transcribe(fileURL: audioURL)
                transcribeError = false
            } catch {
                transcribeError = true
                throw error
            }
            let reportId = try await GenerateService.generate(transcript: transcript, category: category)
            log.info("Watch report generated: \(reportId, privacy: .public)")
            success = true
            try? await Task.sleep(for: .seconds(3))
            try? FileManager.default.removeItem(at: audioURL)
            self.audioURL = nil
            route = .categories
            success = false
        } catch {
            log.error("Watch generation failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.localizedDescription
            route = .recording(category)
        }
    }

    func retryTranscription(category: CategoryWatch) async {
        guard transcribeError, audioURL != nil else { return }
        await generate(category: category)
    }

    func resetSetup() async {
        cleanupAllResources()
        await WatchAuthService.shared.signOut()
        KeychainStore.delete("sala.pairingCode")
        KeychainStore.delete("sala.token")
        route = .setup
    }

    private func cleanupAllResources() {
        recorder.cancel()
        runtimeSession.stop()
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        audioURL = nil
        transcribeError = false
    }
}
