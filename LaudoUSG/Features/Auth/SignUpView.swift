import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = SignUpDraft()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var pendingEmail: PendingEmail?
    @FocusState private var focused: Field?

    enum Field {
        case name
        case crm
        case uf
        case email
        case password
        case passwordConfirm
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    field(
                        label: "Nome completo",
                        text: $draft.name,
                        isValid: draft.nameValid,
                        field: .name,
                        content: .name,
                        placeholder: "Dr. João Silva"
                    )
                    field(
                        label: "CRM",
                        text: $draft.crm,
                        isValid: draft.crmValid,
                        field: .crm,
                        keyboard: .numberPad,
                        placeholder: "12345"
                    )
                    field(
                        label: "UF",
                        text: $draft.uf,
                        isValid: draft.ufValid,
                        field: .uf,
                        placeholder: "SP"
                    )
                    field(
                        label: "Email",
                        text: $draft.email,
                        isValid: draft.emailValid,
                        field: .email,
                        keyboard: .emailAddress,
                        content: .username,
                        placeholder: "medico@clinica.com"
                    )
                    field(
                        label: "Senha",
                        text: $draft.password,
                        isValid: draft.passwordValid,
                        field: .password,
                        isSecure: true,
                        content: .newPassword,
                        placeholder: "Sua senha"
                    )
                    Text("Mínimo 8 caracteres, com letra e número.")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                    field(
                        label: "Confirmar senha",
                        text: $draft.passwordConfirm,
                        isValid: draft.passwordsMatch,
                        field: .passwordConfirm,
                        isSecure: true,
                        content: .newPassword,
                        placeholder: "Repita a senha"
                    )
                    if !draft.passwordConfirm.isEmpty && !draft.passwordsMatch {
                        Text("As senhas não coincidem.")
                            .font(TextStyle.caption)
                            .foregroundStyle(SemanticColor.errorText)
                    }
                    termsToggle
                }

                if let errorMessage {
                    errorBanner(errorMessage)
                        .transition(.opacity)
                }

                PrimaryButton(
                    title: "Criar conta",
                    icon: nil,
                    isLoading: isSubmitting,
                    isDisabled: !draft.isValid || isSubmitting
                ) {
                    submit()
                }

                HStack(spacing: Spacing.xxs) {
                    Text("Já tem conta?")
                        .foregroundStyle(AppSurface.textSecondary)
                    Button("Entrar") {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(BrandColor.primary)
                }
                .font(TextStyle.body)
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.lg)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Criar conta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancelar") {
                    Haptics.tap()
                    dismiss()
                }
                .foregroundStyle(BrandColor.primary)
            }
        }
        .navigationDestination(item: $pendingEmail) { pending in
            ConfirmEmailView(
                email: pending.email,
                onCloseToLogin: { dismiss() }
            )
        }
        .animation(.easeOut(duration: 0.2), value: errorMessage)
        .onChange(of: draft.crm) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue { draft.crm = filtered }
        }
        .onChange(of: draft.uf) { _, newValue in
            let normalized = String(newValue.filter { $0.isLetter }.prefix(2)).uppercased()
            if normalized != newValue { draft.uf = normalized }
        }
        .onChange(of: draft.email) { _, newValue in
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized != newValue { draft.email = normalized }
        }
    }

    private var termsToggle: some View {
        Toggle(isOn: $draft.termsAccepted) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Li e aceito")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textPrimary)
                HStack(spacing: Spacing.xxs) {
                    Link("Termos de Uso", destination: URL(string: "https://laudousg.com/terms")!)
                    Text("e")
                        .foregroundStyle(AppSurface.textSecondary)
                    Link("Política de Privacidade", destination: URL(string: "https://laudousg.com/privacy")!)
                }
                .font(TextStyle.bodyMedium)
                .foregroundStyle(BrandColor.primary)
            }
        }
        .tint(BrandColor.primary)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private func field(
        label: String,
        text: Binding<String>,
        isValid: Bool,
        field: Field,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false,
        content: UITextContentType? = nil,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(label)
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isValid ? SemanticColor.successText : AppSurface.textMuted)
            }

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
            .textInputAutocapitalization(textCapitalization(for: field))
            .autocorrectionDisabled(true)
            .focused($focused, equals: field)
            .submitLabel(submitLabel(for: field))
            .onSubmit { moveFocus(after: field) }
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

    private func textCapitalization(for field: Field) -> TextInputAutocapitalization? {
        switch field {
        case .uf:
            return .characters
        case .email, .password, .passwordConfirm:
            return .never
        default:
            return .words
        }
    }

    private func submitLabel(for field: Field) -> SubmitLabel {
        field == .passwordConfirm ? .go : .next
    }

    private func moveFocus(after field: Field) {
        switch field {
        case .name:
            focused = .crm
        case .crm:
            focused = .uf
        case .uf:
            focused = .email
        case .email:
            focused = .password
        case .password:
            focused = .passwordConfirm
        case .passwordConfirm:
            submit()
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

    private func submit() {
        guard draft.isValid, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        focused = nil
        Task { @MainActor in
            do {
                let result = try await AuthService.shared.signUp(draft: draft)
                switch result {
                case .needsEmailConfirmation(let email):
                    Haptics.success()
                    pendingEmail = PendingEmail(email: email)
                case .signedIn:
                    Haptics.success()
                    dismiss()
                }
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

private struct PendingEmail: Identifiable, Hashable {
    let email: String
    var id: String { email }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
