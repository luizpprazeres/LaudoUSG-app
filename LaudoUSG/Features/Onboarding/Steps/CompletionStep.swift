import SwiftUI

struct CompletionStep: View {
    let isCompleting: Bool
    let errorMessage: String?
    let celebrationTrigger: Int
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            OnboardingPhotoBackdrop(imageName: "OnboardingDone") {
                Text("Foi assim.\nAgora é com você.")
                    .font(TextStyle.h1)
                    .foregroundStyle(.white)

                Text("Pra fazer o próximo laudo, é só tocar no botão verde da tela inicial.")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(3)

                if let errorMessage {
                    Text(errorMessage)
                        .font(TextStyle.body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.sm)
                        .background(SemanticColor.errorText.opacity(0.85), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }

                PrimaryButton(
                    title: "Entrar no app",
                    icon: "arrow.right",
                    isLoading: isCompleting,
                    isDisabled: isCompleting
                ) {
                    onFinish()
                }
                .padding(.top, Spacing.xs)
            }

            ConfettiCanvas(trigger: celebrationTrigger)
                .allowsHitTesting(false)
                .ignoresSafeArea()
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
