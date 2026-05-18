import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let onCompleted: () -> Void

    @State private var page = 0
    @State private var isCompleting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            TabView(selection: $page) {
                onboardingPage(
                    imageName: nil,
                    systemImage: nil,
                    title: "Bem-vindo ao LaudoUSG",
                    body: "Ditado e geração de laudos de ultrassonografia com inteligência artificial.",
                    emphasis: nil
                )
                .tag(0)

                onboardingPage(
                    imageName: nil,
                    systemImage: "sparkles",
                    title: "Como funciona",
                    body: "Dite os achados do exame. A IA estrutura uma minuta de laudo. Você revisa, edita e assina.",
                    emphasis: "Você é o responsável final pela acurácia do laudo."
                )
                .tag(1)

                onboardingPage(
                    imageName: nil,
                    systemImage: "lock.shield.fill",
                    title: "Privacidade primeiro",
                    body: "Não armazenamos dados de pacientes nem imagens. Você é o controlador dos dados de seus pacientes.",
                    emphasis: nil
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if let errorMessage {
                errorBanner(errorMessage)
                    .padding(.horizontal, Spacing.lg)
            }

            PrimaryButton(
                title: page == 2 ? "Começar" : "Próximo",
                icon: nil,
                isLoading: isCompleting,
                isDisabled: isCompleting
            ) {
                advance()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .interactiveDismissDisabled(true)
    }

    private func onboardingPage(
        imageName: String?,
        systemImage: String?,
        title: String,
        body: String,
        emphasis: String?
    ) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)
                    .frame(width: 96, height: 96)
                    .background(
                        Circle().fill(BrandColor.primaryTint)
                    )
            } else {
                Image("LaudoUSGLogoFont")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .accessibilityLabel("LaudoUSG")
            }

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(TextStyle.h2)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
                if let emphasis {
                    Text(emphasis)
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.lg)
            Spacer()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.errorText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(SemanticColor.errorText)
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(SemanticColor.errorBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(SemanticColor.errorBorder, lineWidth: 1)
        )
    }

    private func advance() {
        if page < 2 {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.2)) {
                page += 1
            }
            return
        }
        complete()
    }

    private func complete() {
        guard !isCompleting else { return }
        isCompleting = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let completedAt = try await ProfileService.markOnboardingComplete()
                app.markOnboardingComplete(at: completedAt)
                Haptics.success()
                dismiss()
                onCompleted()
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isCompleting = false
        }
    }
}

#Preview {
    OnboardingView(onCompleted: {})
        .environment(AppState())
}
