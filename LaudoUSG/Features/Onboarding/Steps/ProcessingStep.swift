import SwiftUI

struct ProcessingStep: View {
    let transcript: String
    let streamedLaudo: String
    let warningMessage: String?
    let errorMessage: String?
    let completedStages: Set<OnboardingGenerationStage>
    let namespace: Namespace.ID
    let onRetry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingStepContainer {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Gerando seu laudo")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(BrandColor.primaryDeep)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(BrandColor.primaryTint, in: Capsule())

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    processRow(.transcribed, title: "Áudio transcrito")
                    processRow(.structured, title: "Achados estruturados")
                    processRow(.rules, title: "Regras clínicas conferidas")
                    processRow(.writing, title: "Laudo nascendo na tela")
                    processRow(.saved, title: "Salvo no histórico")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let warningMessage {
                Label(warningMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(SemanticColor.warningBg, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }

            if let errorMessage {
                errorPanel(errorMessage)
            } else {
                laudoPreview
            }
        }
    }

    private var laudoPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Transcrição")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textMuted)
                Text(transcript)
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)

                Divider()

                Text(streamedLaudo.isEmpty ? "Escrevendo o laudo..." : streamedLaudo)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(AppSurface.textPrimary)
                    .lineSpacing(4)
                BlinkingCursor()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
        .background(AppSurface.card, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
        .matchedGeometryEffect(id: "first-laudo-card", in: namespace)
    }

    private func processRow(_ stage: OnboardingGenerationStage, title: String) -> some View {
        let done = completedStages.contains(stage)
        let active = !done && stage.rawValue == nextStageRawValue

        return HStack(spacing: Spacing.sm) {
            Image(systemName: done ? "checkmark" : active ? "arrow.triangle.2.circlepath" : "circle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(done || active ? .white : AppSurface.textMuted)
                .frame(width: 22, height: 22)
                .background(Circle().fill(done ? BrandColor.primary : active ? SemanticColor.info : AppSurface.border))
                .symbolEffect(.bounce, value: done)
                .rotationEffect(active ? .degrees(360) : .zero)
                .animation(active ? .linear(duration: 1.1).repeatForever(autoreverses: false) : .default, value: active)

            Text(title)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(done || active ? AppSurface.textPrimary : AppSurface.textMuted)
            Spacer(minLength: 0)
        }
    }

    private var nextStageRawValue: Int {
        let done = completedStages.map(\.rawValue)
        return (done.max() ?? -1) + 1
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Algo deu errado", systemImage: "exclamationmark.triangle.fill")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(SemanticColor.errorText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            PrimaryButton(title: "Tentar de novo", icon: "arrow.clockwise") {
                onRetry()
            }
            SecondaryButton(title: "Pular por enquanto", icon: "xmark") {
                onSkip()
            }
        }
        .padding(Spacing.md)
        .background(AppSurface.card, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(SemanticColor.errorBorder, lineWidth: 1)
        )
    }
}

struct BlinkingCursor: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.4)) { timeline in
            Rectangle()
                .fill(BrandColor.primary)
                .frame(width: 2, height: 16)
                .opacity(Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProcessingStepPreview: View {
    @Namespace private var namespace

    var body: some View {
        ProcessingStep(
            transcript: "Fígado normal, vesícula sem cálculos, rins normais.",
            streamedLaudo: "ULTRASSONOGRAFIA DO ABDOME TOTAL\n\nFígado de dimensões normais...",
            warningMessage: nil,
            errorMessage: nil,
            completedStages: [.transcribed, .structured, .rules, .writing],
            namespace: namespace,
            onRetry: {},
            onSkip: {}
        )
        .background(AppSurface.background)
    }
}

#Preview {
    ProcessingStepPreview()
}
