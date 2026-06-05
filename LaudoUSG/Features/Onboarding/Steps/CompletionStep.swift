import SwiftUI

struct CompletionStep: View {
    let isCompleting: Bool
    let errorMessage: String?
    let celebrationTrigger: Int
    let onFinish: () -> Void

    @State private var phaseTrigger = 0

    var body: some View {
        ZStack {
            ConfettiCanvas(trigger: celebrationTrigger)
                .allowsHitTesting(false)

            OnboardingStepContainer {
                Spacer(minLength: Spacing.xl)

                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 108, height: 108)
                    .background(Circle().fill(BrandColor.primary))
                    .shadow(color: BrandColor.primary.opacity(0.24), radius: 24, y: 10)
                    .scaleEffect(phaseTrigger == 0 ? 0.82 : 1)
                    .animation(.spring(duration: 0.6, bounce: 0.4), value: phaseTrigger)
                    .symbolEffect(.bounce, value: phaseTrigger)

                PhaseAnimator([0, 1], trigger: phaseTrigger) { phase in
                    VStack(spacing: Spacing.sm) {
                        Text("Foi assim.\nAgora é com você.")
                            .font(TextStyle.h1)
                            .foregroundStyle(AppSurface.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Pra fazer o próximo laudo, é só tocar no botão verde da tela inicial.")
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(AppSurface.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .opacity(phase == 0 ? 0 : 1)
                    .offset(y: phase == 0 ? 14 : 0)
                } animation: { _ in
                    .spring(duration: 0.48, bounce: 0.16)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Dica")
                        .font(TextStyle.captionMedium)
                        .foregroundStyle(AppSurface.textMuted)
                        .textCase(.uppercase)
                    Text("Você pode trocar categoria, escolher o estilo de escrita e editar qualquer parte do laudo.")
                        .font(TextStyle.body)
                        .foregroundStyle(AppSurface.textSecondary)
                        .lineSpacing(2)
                }
                .padding(Spacing.md)
                .background(AppSurface.card, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(AppSurface.border, lineWidth: 1)
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(TextStyle.body)
                        .foregroundStyle(SemanticColor.errorText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.sm)
                        .background(SemanticColor.errorBg, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }

                Spacer()

                PrimaryButton(
                    title: "Entrar no app",
                    icon: "arrow.right",
                    isLoading: isCompleting,
                    isDisabled: isCompleting
                ) {
                    onFinish()
                }
            }
        }
        .onAppear {
            phaseTrigger += 1
        }
    }
}

struct ConfettiCanvas: View {
    let trigger: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<42 {
                    let seed = Double(index * 37 + trigger * 19)
                    let progress = CGFloat((elapsed + seed.truncatingRemainder(dividingBy: 1.7)).truncatingRemainder(dividingBy: 1.7) / 1.7)
                    let x = CGFloat((sin(seed) + 1) / 2) * size.width
                    let y = -20 + progress * (size.height + 80)
                    let side = CGFloat(5 + (index % 4))
                    let rect = CGRect(x: x, y: y, width: side, height: side * 1.8)
                    let color: Color = index % 3 == 0 ? BrandColor.primary : index % 3 == 1 ? SemanticColor.info : Color(hex: "F59E0B")
                    context.opacity = max(0, 1 - progress * 0.65)
                    context.rotate(by: .degrees(seed + Double(progress * 180)))
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                }
            }
        }
    }
}

#Preview {
    CompletionStep(isCompleting: false, errorMessage: nil, celebrationTrigger: 1, onFinish: {})
        .background(AppSurface.background)
}
