import SwiftUI

struct ResetPasswordView: View {
    let session: AuthSession

    @Environment(\.dismiss) private var dismiss
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @FocusState private var focused: Field?

    enum Field {
        case newPassword
        case confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Image("LaudoUSGLogoFont")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .accessibilityLabel("LaudoUSG")

                    Text("Crie sua nova senha")
                        .font(TextStyle.h2)
                        .foregroundStyle(AppSurface.textPrimary)

                    labeledField(
                        "Nova senha",
                        text: $newPassword,
                        field: .newPassword,
                        placeholder: "Nova senha"
                    )

                    labeledField(
                        "Confirmar senha",
                        text: $confirmPassword,
                        field: .confirmPassword,
                        placeholder: "Repita a senha"
                    )

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    PrimaryButton(
                        title: "Salvar",
                        icon: nil,
                        isLoading: isLoading,
                        isDisabled: !isValid || isLoading
                    ) {
                        save()
                    }
                }
                .padding(Spacing.lg)
            }
            .background(AppSurface.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(BrandColor.primary)
                }
            }
            .alert("Senha atualizada", isPresented: $didSucceed) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Você já está logado.")
            }
        }
    }

    private var isValid: Bool {
        newPassword == confirmPassword &&
            newPassword.count >= 8 &&
            newPassword.rangeOfCharacter(from: .letters) != nil &&
            newPassword.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private func labeledField(
        _ label: String,
        text: Binding<String>,
        field: Field,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            SecureField(placeholder, text: text)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textPrimary)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focused, equals: field)
                .submitLabel(field == .newPassword ? .next : .go)
                .onSubmit {
                    if field == .newPassword {
                        focused = .confirmPassword
                    } else {
                        save()
                    }
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

    private func save() {
        guard isValid, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        focused = nil
        Task { @MainActor in
            do {
                try await AuthService.shared.updatePassword(newPassword: newPassword)
                Haptics.success()
                didSucceed = true
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ResetPasswordView(
        session: AuthSession(
            accessToken: "preview-token",
            refreshToken: "preview-refresh",
            expiresAt: nil,
            userId: "preview-user",
            email: "medico@clinica.com"
        )
    )
    .environment(AppState())
}
