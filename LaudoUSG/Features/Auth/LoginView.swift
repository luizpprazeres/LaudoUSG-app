import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LoginView: View {
    @Environment(AppState.self) private var app

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var isSignUpPresented: Bool = false
    @State private var isResendingConfirmation: Bool = false
    @State private var errorMessage: String?
    @State private var loginNeedsEmailConfirmation: Bool = false
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurface.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                        VStack(spacing: Spacing.xl) {
                            Image("LaudoUSGLogoFont")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 340)
                                .accessibilityLabel("LaudoUSG")
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

                            HStack {
                                Spacer()
                                NavigationLink {
                                    ForgotPasswordView()
                                } label: {
                                    Text("Esqueci minha senha")
                                        .font(TextStyle.bodyMedium)
                                        .foregroundStyle(BrandColor.primary)
                                }
                            }
                            .padding(.top, Spacing.xs)

                            HStack(spacing: Spacing.xxs) {
                                Text("Não tem conta?")
                                    .font(TextStyle.body)
                                    .foregroundStyle(AppSurface.textSecondary)
                                Button("Cadastre-se") {
                                    Haptics.tap()
                                    isSignUpPresented = true
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
            .sheet(isPresented: $isSignUpPresented) {
                NavigationStack {
                    SignUpView()
                }
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
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.errorText)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(message)
                    .font(TextStyle.body)
                    .foregroundStyle(SemanticColor.errorText)
                if loginNeedsEmailConfirmation {
                    Button(isResendingConfirmation ? "Reenviando…" : "Reenviar email de confirmação") {
                        resendConfirmation()
                    }
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(BrandColor.primary)
                    .disabled(isResendingConfirmation)
                }
            }
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
        loginNeedsEmailConfirmation = false
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
                    let message = error.errorDescription ?? "Erro ao entrar."
                    if isEmailNotConfirmed(message) {
                        loginNeedsEmailConfirmation = true
                        errorMessage = "Email ainda não confirmado."
                    } else {
                        errorMessage = message
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resendConfirmation() {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isResendingConfirmation = true
        Task { @MainActor in
            do {
                try await AuthService.shared.resendConfirmation(email: email)
                Haptics.success()
                errorMessage = "Email de confirmação reenviado."
                loginNeedsEmailConfirmation = false
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isResendingConfirmation = false
        }
    }

    private func isEmailNotConfirmed(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("email_not_confirmed") || lower.contains("email not confirmed")
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
