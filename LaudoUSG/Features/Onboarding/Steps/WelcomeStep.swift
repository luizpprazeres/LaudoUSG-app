import SwiftUI

struct WelcomeStep: View {
    let doctorName: String
    let onStart: () -> Void

    var body: some View {
        OnboardingStepContainer {
            Spacer(minLength: Spacing.xl)

            PhaseAnimator([0, 1, 2], trigger: doctorName) { phase in
                Image("LaudoUSGLogoFont")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .opacity(phase == 0 ? 0 : 1)
                    .scaleEffect(phase == 0 ? 0.82 : 1)
                    .offset(y: phase == 0 ? 12 : 0)
            } animation: { _ in
                .spring(duration: 0.55, bounce: 0.22)
            }
            .accessibilityLabel("LaudoUSG")

            VStack(spacing: Spacing.sm) {
                Text("Bem-vindo,\n\(shortName).")
                    .font(TextStyle.h1)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Vamos fazer seu primeiro laudo agora. Em 60 segundos você entende o fluxo inteiro.")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("O que vai acontecer")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(BrandColor.primaryDeep)
                    .textCase(.uppercase)
                Text("Você dita 5 segundos. A IA estrutura os achados, gera o laudo completo e salva no histórico.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .lineSpacing(2)
            }
            .padding(Spacing.md)
            .background(BrandColor.primaryTint, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))

            Spacer()

            PrimaryButton(title: "Vamos lá", icon: "arrow.right") {
                onStart()
            }
        }
    }

    private var shortName: String {
        let cleaned = doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "doutor" }
        return cleaned.split(separator: " ").first.map(String.init) ?? cleaned
    }
}

struct OnboardingStepContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: Spacing.lg) {
            content
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xxxl)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: 560, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WelcomeStep(doctorName: "Luiz Prazeres", onStart: {})
        .background(AppSurface.background)
}
