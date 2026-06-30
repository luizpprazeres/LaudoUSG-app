import SwiftUI

struct WelcomeStep: View {
    let doctorName: String
    let onStart: () -> Void

    var body: some View {
        OnboardingPhotoBackdrop(imageName: "OnboardingWelcome") {
            Text(greeting)
                .font(TextStyle.h1)
                .foregroundStyle(.white)

            Text("Vamos fazer seu primeiro laudo agora. Em 60 segundos você entende o fluxo inteiro.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)

            PrimaryButton(title: "Vamos lá", icon: "arrow.right") {
                onStart()
            }
            .padding(.top, Spacing.xs)
        }
    }

    /// Saudação com o primeiro nome; neutra quando não há nome real (só e-mail).
    private var greeting: String {
        let cleaned = doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Bem-vindo,\ndoutor(a)." }
        let first = cleaned.split(separator: " ").first.map(String.init) ?? cleaned
        return "Bem-vindo,\n\(first)."
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
