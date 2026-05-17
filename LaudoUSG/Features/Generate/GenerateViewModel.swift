import SwiftUI
import Observation

@Observable
@MainActor
final class GenerateViewModel {
    var category: ReportCategory = .abdomenTotal
    var writingStyle: WritingStyle = .tradicional
    var inputText: String = ""
    var streamedOutput: String = ""
    var liveTranscript: String = ""

    var phase: GenerationPhase = .idle
    var lastError: String?
    var lastWarning: String?

    var isCategorySheetPresented = false
    var isMenuSheetPresented = false
    var isPlusSheetPresented = false
    var isCalculatorsSheetPresented = false
    var isRecordingOverlayPresented = false

    let speech = SpeechService()
    private var transcriptObserver: Task<Void, Never>?

    var canGenerate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phase.isBusy
    }

    var phaseLabel: String {
        switch phase {
        case .recording: return "Gravando…"
        case .transcribing: return "Transcrevendo…"
        case .generating: return "Gerando…"
        default: return "Gerar laudo"
        }
    }

    func insertSnippet(_ snippet: String) {
        if inputText.isEmpty {
            inputText = snippet
        } else {
            let separator = inputText.hasSuffix("\n") ? "" : "\n"
            inputText += separator + snippet
        }
        isPlusSheetPresented = false
    }

    func startRecording() {
        guard !phase.isBusy else { return }
        Task { @MainActor in
            let granted = await speech.requestPermissions()
            guard granted else {
                lastError = speech.lastError?.errorDescription ?? "Sem permissão para gravar."
                return
            }
            do {
                liveTranscript = ""
                try await speech.start()
                phase = .recording
                isRecordingOverlayPresented = true
            } catch {
                lastError = (error as? SpeechServiceError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func cancelRecording() {
        speech.cancel()
        liveTranscript = ""
        isRecordingOverlayPresented = false
        phase = inputText.isEmpty ? .idle : .ready
    }

    func finishRecording() {
        isRecordingOverlayPresented = false
        phase = .transcribing
        Task { @MainActor in
            let transcript = await speech.stop()
            if !transcript.isEmpty {
                if inputText.isEmpty {
                    inputText = transcript
                } else {
                    let separator = inputText.hasSuffix("\n") ? "" : "\n"
                    inputText += separator + transcript
                }
            } else if let err = speech.lastError {
                lastError = err.errorDescription
            }
            liveTranscript = ""
            phase = inputText.isEmpty ? .idle : .ready
        }
    }

    var lastReportId: String?
    var sanityIssues: [LocalSanityIssue] = []

    func generate(writingStyleId: String) {
        guard canGenerate else { return }
        streamedOutput = ""
        lastError = nil
        lastWarning = nil
        sanityIssues = []
        phase = .generating

        let req = GenerateRequest(
            rawInput: inputText,
            categoryHint: category,
            writingStyleId: writingStyleId
        )

        Task { @MainActor in
            do {
                let stream = try await ReportService.generateStream(request: req)
                for try await event in stream {
                    handle(event: event)
                }
            } catch let error as APIError {
                if case .unauthorized = error {
                    lastError = "Sessão expirada. Faça login novamente."
                } else {
                    lastError = error.errorDescription
                }
                phase = .error(message: lastError ?? "Erro")
            } catch {
                lastError = error.localizedDescription
                phase = .error(message: lastError ?? "Erro")
            }
        }
    }

    private func handle(event: GenerateSSEEvent) {
        switch event {
        case .open(let payload):
            lastReportId = payload.reportId
        case .heartbeat:
            break
        case .structured:
            break
        case .validator(let payload):
            if !payload.ok && payload.issuesCount > 0 {
                // Sprint 4: tratar clarify questions
            }
        case .clarify(let payload):
            phase = .clarifying(question: payload.questions.first?.text ?? "Esclarecimento necessário")
        case .rag:
            break
        case .warning(let payload):
            lastWarning = payload.message
        case .token(let payload):
            streamedOutput += payload.delta
        case .sanity:
            break
        case .done(let payload):
            streamedOutput = payload.finalText
            lastReportId = payload.reportId
            sanityIssues = SanityChecker.check(text: payload.finalText, category: category)
            phase = .done(reportId: payload.reportId)
        case .blocked(let payload):
            lastError = payload.reason
            phase = .error(message: payload.reason)
        case .error(let payload):
            lastError = payload.message
            phase = .error(message: payload.message)
        }
    }

    func reset() {
        inputText = ""
        streamedOutput = ""
        liveTranscript = ""
        phase = .idle
        lastError = nil
    }
}
