import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LoginView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "light"
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var isSignUpPresented: Bool = false
    @State private var isResendingConfirmation: Bool = false
    @State private var errorMessage: String?
    @State private var loginNeedsEmailConfirmation: Bool = false
    @State private var isPrivacyPresented: Bool = false
    @State private var presentedLegalDoc: LegalDocKind?
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var focused: Field?

    enum Field { case email, password }

    private func legalFooterButton(_ doc: LegalDocKind, icon: String) -> some View {
        Button {
            Haptics.tap()
            presentedLegalDoc = doc
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(doc.title)
            }
            .font(TextStyle.footnote)
            .foregroundStyle(AppSurface.textSecondary)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurface.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        themeToggle
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)

                    Spacer()

                    VStack(spacing: Spacing.xl) {
                        header

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
                                placeholder: ""
                            )

                            HStack {
                                Spacer()
                                NavigationLink {
                                    ForgotPasswordView()
                                } label: {
                                    Text("Esqueci a senha")
                                        .font(TextStyle.bodyMedium)
                                        .foregroundStyle(BrandColor.primary)
                                }
                            }

                            if let errorMessage {
                                errorBanner(errorMessage)
                                    .offset(x: shakeOffset)
                            }

                            PrimaryButton(
                                title: "Entrar",
                                icon: nil,
                                isLoading: isLoading,
                                isDisabled: !isValid
                            ) {
                                performLogin()
                            }

                            SecondaryButton(title: "Criar conta nova", icon: nil) {
                                Haptics.tap()
                                isSignUpPresented = true
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)

                    Spacer()

                    HStack(spacing: Spacing.md) {
                        legalFooterButton(.termsOfUse, icon: "doc.text")
                        legalFooterButton(.privacyPolicy, icon: "lock.shield")
                        legalFooterButton(.medicalDisclaimer, icon: "stethoscope")
                    }
                    .padding(.bottom, Spacing.md)
                }
            }
            .sheet(isPresented: $isSignUpPresented) {
                NavigationStack {
                    SignUpView()
                }
            }
            .sheet(item: $presentedLegalDoc) { doc in
                NavigationStack {
                    MarkdownDocumentView(title: doc.title, resourceName: doc.bundleResourceName)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Fechar") { presentedLegalDoc = nil }
                            }
                        }
                }
            }
            .onChange(of: errorMessage) { _, newValue in
                if newValue != nil { triggerShake() }
            }
        }
    }

    private var themeToggle: some View {
        Button {
            Haptics.tap()
            preferredColorScheme = preferredColorScheme == "dark" ? "light" : "dark"
        } label: {
            Image(systemName: preferredColorScheme == "dark" ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppSurface.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(AppSurface.card)
                )
                .overlay(
                    Circle().stroke(AppSurface.border, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(preferredColorScheme == "dark" ? "Mudar para modo claro" : "Mudar para modo escuro")
    }

    private var header: some View {
        Image("LaudoUSGLogoFont")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 340)
            .accessibilityLabel("LaudoUSG")
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
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)

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
                    .stroke(focused == field ? BrandColor.primary : AppSurface.border, lineWidth: 1.5)
            )
            .shadow(
                color: focused == field ? BrandColor.primary.opacity(0.16) : .clear,
                radius: 8, x: 0, y: 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: focused)
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
                        errorMessage = "Confirme seu email pra entrar."
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

    private func triggerShake() {
        guard !reduceMotion else { return }
        let pattern: [CGFloat] = [6, -6, 5, -5, 3, -3, 0]
        for (index, value) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.linear(duration: 0.05)) {
                    shakeOffset = value
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
