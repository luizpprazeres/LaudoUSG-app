import SwiftUI

struct DeleteAccountView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @FocusState private var isConfirmFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if step == 1 {
                    firstStep
                } else {
                    secondStep
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Excluir conta")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: confirmText) { _, newValue in
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if normalized != newValue { confirmText = normalized }
        }
    }

    private var firstStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            destructiveCard

            Text("Ao excluir sua conta, serão apagados:")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                bullet("Seu perfil")
                bullet("Todos os laudos gerados")
                bullet("Frases salvas")
                bullet("Sessões da sala do auxiliar")
            }

            DestructiveButton(
                title: "Continuar com exclusão",
                isLoading: false,
                isDisabled: false
            ) {
                Haptics.warning()
                step = 2
            }

            SecondaryButton(title: "Cancelar") {
                Haptics.tap()
                dismiss()
            }
        }
    }

    private var secondStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Pra confirmar, digite EXCLUIR abaixo:")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)

            labeledField("Digite EXCLUIR", text: $confirmText)

            if let errorMessage {
                errorBanner(errorMessage)
            }

            DestructiveButton(
                title: "Excluir minha conta",
                isLoading: isDeleting,
                isDisabled: confirmText.trimmingCharacters(in: .whitespacesAndNewlines) != "EXCLUIR" || isDeleting
            ) {
                deleteAccount()
            }

            SecondaryButton(title: "Voltar") {
                Haptics.tap()
                step = 1
            }
        }
    }

    private var destructiveCard: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(SemanticColor.errorAccent)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Esta ação é definitiva")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(SemanticColor.errorText)
                Text("Sem volta.")
                    .font(TextStyle.body)
                    .foregroundStyle(SemanticColor.errorText)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(SemanticColor.errorBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(SemanticColor.errorBorder, lineWidth: 1)
        )
    }

    private func bullet(_ item: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Text("•")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            Text(item)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            TextField("EXCLUIR", text: text)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .focused($isConfirmFocused)
                .submitLabel(.go)
                .onSubmit { deleteAccount() }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(AppSurface.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(isConfirmFocused ? SemanticColor.errorAccent : AppSurface.border, lineWidth: 1)
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

    private func deleteAccount() {
        guard confirmText.trimmingCharacters(in: .whitespacesAndNewlines) == "EXCLUIR", !isDeleting else { return }
        Haptics.error()
        isDeleting = true
        errorMessage = nil
        isConfirmFocused = false
        Task { @MainActor in
            do {
                try await AuthService.shared.deleteAccount()
                app.signOut()
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isDeleting = false
            }
        }
    }
}

private struct DestructiveButton: View {
    let title: String
    var isLoading: Bool
    var isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(SemanticColor.errorText)
                }
                Text(title)
                    .font(TextStyle.bodySemibold)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(SemanticColor.errorText)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(isDisabled ? SemanticColor.errorBg.opacity(0.5) : SemanticColor.errorBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(SemanticColor.errorBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isDisabled || isLoading)
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
    }
    .environment(AppState())
}
