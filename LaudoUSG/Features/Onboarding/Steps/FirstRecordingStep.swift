import SwiftUI

struct FirstRecordingStep: View {
    let speech: SpeechService
    let transcript: String
    let isRecording: Bool
    let isTranscribing: Bool
    let errorMessage: String?
    let onToggleRecording: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        OnboardingStepContainer {
            categoryPill

            VStack(spacing: Spacing.xs) {
                Text(transcript.isEmpty ? "Toque o mic e dite por 5 segundos." : "Transcrição pronta.")
                    .font(TextStyle.h2)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Pode dizer: “fígado normal, vesícula sem cálculos, rins normais”.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                onToggleRecording()
            } label: {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 108, height: 108)
                    .background(Circle().fill(isRecording ? SemanticColor.errorAccent : BrandColor.primary))
                    .shadow(color: BrandColor.primary.opacity(isRecording ? 0.3 : 0.18), radius: 22, y: 10)
                    .overlay(
                        Circle()
                            .stroke(BrandColor.primary.opacity(isRecording ? 0.22 : 0), lineWidth: 18)
                            .scaleEffect(isRecording ? 1.12 : 1)
                    )
                    .symbolEffect(.pulse, options: .repeating, isActive: isRecording)
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.94))
            .disabled(isTranscribing)

            WaveformView(level: speech.currentLevel, isActive: isRecording)
                .frame(height: 54)
                .padding(.horizontal, Spacing.lg)

            Text(timerText)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppSurface.textSecondary)

            if isTranscribing {
                statusCard(icon: "waveform.badge.magnifyingglass", text: "Transcrevendo áudio...")
            } else if !transcript.isEmpty {
                transcriptCard
            } else if let errorMessage {
                statusCard(icon: "exclamationmark.triangle.fill", text: errorMessage, isError: true)
            } else {
                statusCard(icon: "hand.tap.fill", text: "A gravação para sozinha em 5 segundos.")
            }

            Spacer(minLength: 0)

            PrimaryButton(
                title: "Gerar meu primeiro laudo",
                icon: "sparkles",
                isDisabled: transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRecording || isTranscribing
            ) {
                onGenerate()
            }
        }
    }

    private var categoryPill: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color(hex: "2563EB"))
                .frame(width: 9, height: 9)
                .symbolEffect(.pulse, options: .repeating, isActive: true)
            Text("Abdome Total")
                .font(TextStyle.bodySemibold)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(AppSurface.card, in: Capsule())
        .overlay(Capsule().stroke(AppSurface.border, lineWidth: 1))
    }

    private var timerText: String {
        let elapsed = min(5, max(0, Int(speech.elapsed.rounded(.down))))
        return "00:0\(elapsed) / 00:05"
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Você ditou", systemImage: "text.quote")
                .font(TextStyle.captionMedium)
                .foregroundStyle(BrandColor.primaryDeep)
            Text(transcript)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(AppSurface.card, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
        .fluidEntrance(trigger: transcript)
    }

    private func statusCard(icon: String, text: String, isError: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(isError ? SemanticColor.errorText : BrandColor.primary)
            Text(text)
                .font(TextStyle.body)
                .foregroundStyle(isError ? SemanticColor.errorText : AppSurface.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(isError ? SemanticColor.errorBg : BrandColor.primaryTint)
        )
    }
}

struct WaveformView: View {
    let level: Float
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { timeline in
            Canvas { context, size in
                let count = 22
                let spacing: CGFloat = 4
                let barWidth = max(2, (size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
                let now = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<count {
                    let wave = (sin(now * 5 + Double(index) * 0.55) + 1) / 2
                    let liveLevel = isActive ? max(0.12, CGFloat(level)) : 0.08
                    let height = max(5, size.height * (0.12 + liveLevel * CGFloat(0.25 + wave * 0.75)))
                    let x = CGFloat(index) * (barWidth + spacing)
                    let y = (size.height - height) / 2
                    let rect = CGRect(x: x, y: y, width: barWidth, height: height)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(BrandColor.primary.opacity(isActive ? 0.95 : 0.28))
                    )
                }
            }
        }
    }
}

#Preview("Recording") {
    FirstRecordingStep(
        speech: SpeechService(),
        transcript: "",
        isRecording: true,
        isTranscribing: false,
        errorMessage: nil,
        onToggleRecording: {},
        onGenerate: {}
    )
    .background(AppSurface.background)
}

#Preview("Transcript") {
    FirstRecordingStep(
        speech: SpeechService(),
        transcript: "Fígado normal, vesícula sem cálculos, rins normais.",
        isRecording: false,
        isTranscribing: false,
        errorMessage: nil,
        onToggleRecording: {},
        onGenerate: {}
    )
    .background(AppSurface.background)
}
