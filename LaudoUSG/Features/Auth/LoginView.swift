import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LoginView: View {
    @Environment(AppState.self) private var app

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            AppSurface.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.sm) {
                        BrandLogo(size: .large)

                        Text("Laudos de ultrassom com IA.")
                            .font(TextStyle.bodyLargeMedium)
                            .foregroundStyle(AppSurface.textSecondary)
                    }
                    .padding(.bottom, Spacing.md)

                    VStack(spacing: Spacing.md) {
                        labeledField(
                            label: "Email",
                            text: $email,
                            field: .email,
                            keyboard: .emailAddress,
                            content: .username,
                            placeholder: "voce@clinica.com"
                        )

                        labeledField(
                            label: "Senha",
                            text: $password,
                            field: .password,
                            isSecure: true,
                            content: .password,
                            placeholder: "Sua senha"
                        )

                        if let errorMessage {
                            errorBanner(errorMessage)
                        }

                        PrimaryButton(
                            title: "Entrar",
                            icon: nil,
                            isLoading: isLoading,
                            isDisabled: !isValid
                        ) {
                            performLogin()
                        }

                        HStack(spacing: Spacing.xxs) {
                            Text("Sem conta?")
                                .font(TextStyle.body)
                                .foregroundStyle(AppSurface.textSecondary)
                            Button("Crie em laudousg.com") {
                                // Sprint 3: rota de signup ou link
                            }
                            .font(TextStyle.bodyMedium)
                            .foregroundStyle(BrandColor.primary)
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()

                Text("Seus laudos são privados. Revise antes de assinar.")
                    .multilineTextAlignment(.center)
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)
            }
        }
    }

    private var isValid: Bool {
        email.contains("@") && password.count >= 6
    }

    private func labeledField(
        label: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false,
        content: UITextContentType? = nil,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(TextStyle.bodyLarge)
            .foregroundStyle(AppSurface.textPrimary)
            .keyboardType(keyboard)
            .textContentType(content)
            .textInputAutocapitalization(field == .email ? .never : nil)
            .autocorrectionDisabled(field == .email)
            .focused($focused, equals: field)
            .submitLabel(field == .email ? .next : .go)
            .onSubmit {
                if field == .email { focused = .password } else { performLogin() }
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(focused == field ? BrandColor.primary : AppSurface.border, lineWidth: 1)
            )
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.xs) {
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

    private func performLogin() {
        guard isValid else { return }
        errorMessage = nil
        isLoading = true
        focused = nil
        Task {
            do {
                let session = try await AuthService.shared.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    app.signIn(email: session.email, name: nil)
                }
            } catch let error as AuthError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
