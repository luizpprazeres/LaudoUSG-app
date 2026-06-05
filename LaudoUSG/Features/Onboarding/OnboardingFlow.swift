import SwiftUI

enum OnboardingFlowStep: Int, CaseIterable {
    case welcome
    case micPermission
    case firstRecording
    case processing
    case firstLaudo
    case completion
}

enum OnboardingGenerationStage: Int, CaseIterable {
    case transcribed
    case structured
    case rules
    case writing
    case saved
}

struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Namespace private var laudoNamespace

    let onCompleted: () -> Void

    @State private var step: OnboardingFlowStep = .welcome
    @State private var isCompleting = false
    @State private var completionError: String?
    @State private var permissionDenied = false
    @State private var isRequestingPermission = false
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var isGenerating = false
    @State private var transcript = ""
    @State private var streamedLaudo = ""
    @State private var finalLaudo = ""
    @State private var reportId: String?
    @State private var warningMessage: String?
    @State private var generationError: String?
    @State private var generationStages: Set<OnboardingGenerationStage> = []
    @State private var completionCelebration = 0
    @State private var recordingTask: Task<Void, Never>?
    @State private var generationTask: Task<Void, Never>?
    @State private var speech = SpeechService()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppSurface.background.ignoresSafeArea()

            currentStep
                .id(step)
                .transition(.scale(scale: 0.98).combined(with: .opacity))
                .animation(.spring(duration: 0.42, bounce: 0.18), value: step)

            skipButton
        }
        .interactiveDismissDisabled(true)
        .sensoryFeedback(.success, trigger: completionCelebration)
        .onDisappear {
            recordingTask?.cancel()
            generationTask?.cancel()
            speech.cancel()
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case .welcome:
            WelcomeStep(
                doctorName: app.profile?.displayName ?? "doutor",
                onStart: goToMicPermission
            )
        case .micPermission:
            MicPermissionStep(
                isRequesting: isRequestingPermission,
                permissionDenied: permissionDenied,
                onRequestPermission: requestMicPermission,
                onClose: completeAndDismiss
            )
        case .firstRecording:
            FirstRecordingStep(
                speech: speech,
                transcript: transcript,
                isRecording: isRecording,
                isTranscribing: isTranscribing,
                errorMessage: speech.lastError?.errorDescription,
                onToggleRecording: toggleRecording,
                onGenerate: beginGeneration
            )
        case .processing:
            ProcessingStep(
                transcript: transcript,
                streamedLaudo: streamedLaudo,
                warningMessage: warningMessage,
                errorMessage: generationError,
                completedStages: generationStages,
                namespace: laudoNamespace,
                onRetry: beginGeneration,
                onSkip: completeAndDismiss
            )
        case .firstLaudo:
            FirstLaudoStep(
                laudoText: finalLaudo.isEmpty ? streamedLaudo : finalLaudo,
                reportId: reportId,
                namespace: laudoNamespace,
                onContinue: goToCompletion
            )
        case .completion:
            CompletionStep(
                isCompleting: isCompleting,
                errorMessage: completionError,
                celebrationTrigger: completionCelebration,
                onFinish: completeAndDismiss
            )
        }
    }

    private var skipButton: some View {
        Button {
            completeAndDismiss()
        } label: {
            Text("Pular")
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textMuted)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, Spacing.lg)
        .padding(.trailing, Spacing.lg)
        .disabled(isCompleting)
    }

    private func goToMicPermission() {
        Haptics.tap()
        withAnimation(.spring(duration: 0.38, bounce: 0.16)) {
            step = .micPermission
        }
    }

    private func requestMicPermission() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        permissionDenied = false
        Haptics.tap()
        Task { @MainActor in
            let granted = await speech.requestPermissions()
            isRequestingPermission = false
            if granted {
                Haptics.success()
                withAnimation(.spring(duration: 0.38, bounce: 0.18)) {
                    step = .firstRecording
                }
            } else {
                Haptics.error()
                permissionDenied = true
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard !isRecording, !isTranscribing else { return }
        transcript = ""
        generationError = nil
        Haptics.tap()
        recordingTask?.cancel()
        recordingTask = Task { @MainActor in
            let granted = await speech.requestPermissions()
            guard granted else {
                permissionDenied = true
                Haptics.error()
                withAnimation(.spring(duration: 0.38, bounce: 0.18)) {
                    step = .micPermission
                }
                return
            }
            do {
                try await speech.start()
                isRecording = true
                while !Task.isCancelled && speech.elapsed < 5 {
                    speech.tick()
                    try? await Task.sleep(for: .milliseconds(80))
                }
                guard !Task.isCancelled else { return }
                stopRecordingAndTranscribe()
            } catch {
                Haptics.error()
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        guard isRecording else { return }
        recordingTask?.cancel()
        isRecording = false
        isTranscribing = true
        Task { @MainActor in
            let text = await speech.stop().trimmingCharacters(in: .whitespacesAndNewlines)
            transcript = text
            isTranscribing = false
            if text.isEmpty {
                Haptics.error()
            } else {
                Haptics.success()
            }
        }
    }

    private func beginGeneration() {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Haptics.tap()
        streamedLaudo = ""
        finalLaudo = ""
        reportId = nil
        warningMessage = nil
        generationError = nil
        generationStages = [.transcribed]
        isGenerating = true
        withAnimation(.spring(duration: 0.38, bounce: 0.16)) {
            step = .processing
        }
        generationTask?.cancel()
        generationTask = Task { @MainActor in
            do {
                let request = GenerateRequest(
                    rawInput: transcript,
                    categoryHint: .abdomenTotal,
                    writingStyleId: app.defaultWritingStyleId
                )
                let stream = try await ReportService.generateStream(request: request)
                for try await event in stream {
                    handle(event: event)
                }
            } catch let error as APIError {
                generationError = error.errorDescription
                isGenerating = false
                Haptics.error()
            } catch {
                generationError = error.localizedDescription
                isGenerating = false
                Haptics.error()
            }
        }
    }

    private func handle(event: GenerateSSEEvent) {
        switch event {
        case .open(let payload):
            reportId = payload.reportId
        case .heartbeat:
            break
        case .structured:
            generationStages.insert(.structured)
        case .validator(let payload):
            if payload.ok {
                generationStages.insert(.rules)
            }
        case .clarify(let payload):
            generationError = payload.questions.first?.text ?? "Preciso de mais um detalhe antes de gerar o laudo."
            isGenerating = false
        case .rag:
            generationStages.insert(.rules)
        case .warning(let payload):
            warningMessage = payload.message
        case .token(let payload):
            generationStages.insert(.writing)
            streamedLaudo += payload.delta
        case .sanity:
            generationStages.insert(.rules)
        case .done(let payload):
            generationStages = Set(OnboardingGenerationStage.allCases)
            streamedLaudo = payload.finalText
            finalLaudo = payload.finalText
            reportId = payload.reportId
            isGenerating = false
            Haptics.success()
            withAnimation(.spring(duration: 0.46, bounce: 0.18)) {
                step = .firstLaudo
            }
        case .blocked(let payload):
            generationError = payload.reason
            isGenerating = false
            Haptics.error()
        case .error(let payload):
            generationError = payload.message
            isGenerating = false
            Haptics.error()
        }
    }

    private func goToCompletion() {
        Haptics.tap()
        completionCelebration += 1
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
            step = .completion
        }
    }

    private func completeAndDismiss() {
        guard !isCompleting else { return }
        isCompleting = true
        completionError = nil
        recordingTask?.cancel()
        generationTask?.cancel()
        speech.cancel()
        Task { @MainActor in
            do {
                let completedAt = try await ProfileService.markOnboardingComplete()
                app.markOnboardingComplete(at: completedAt)
                Haptics.success()
                completionCelebration += 1
                dismiss()
                onCompleted()
            } catch {
                Haptics.error()
                completionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isCompleting = false
        }
    }
}

#Preview {
    OnboardingFlow(onCompleted: {})
        .environment(AppState())
}
