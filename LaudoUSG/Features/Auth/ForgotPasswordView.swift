import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkSent = false
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image("LaudoUSGLogoFont")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .accessibilityLabel("LaudoUSG")

                Text("Digite seu email. Vamos enviar um link pra criar nova senha.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)

                labeledField("Email", text: $email)

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                if linkSent {
                    successCard
                }

                PrimaryButton(
                    title: "Enviar link",
                    icon: nil,
                    isLoading: isLoading,
                    isDisabled: !email.contains("@") || isLoading || linkSent
                ) {
                    sendLink()
                }

                SecondaryButton(title: "Voltar pro login") {
                    Haptics.tap()
                    dismiss()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Esqueci minha senha")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: email) { _, newValue in
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized != newValue { email = normalized }
        }
    }

    private var successCard: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SemanticColor.successText)
            Text("Link enviado. Verifique seu email.")
                .font(TextStyle.body)
                .foregroundStyle(SemanticColor.successText)
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(SemanticColor.successBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(SemanticColor.successBorder, lineWidth: 1)
        )
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            TextField("voce@clinica.com", text: text)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textPrimary)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isEmailFocused)
                .submitLabel(.go)
                .onSubmit { sendLink() }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(AppSurface.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(isEmailFocused ? BrandColor.primary : AppSurface.border, lineWidth: 1)
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

    private func sendLink() {
        guard email.contains("@"), !isLoading, !linkSent else { return }
        isLoading = true
        errorMessage = nil
        isEmailFocused = false
        Task { @MainActor in
            do {
                try await AuthService.shared.requestPasswordReset(email: email)
                Haptics.success()
                linkSent = true
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
    .environment(AppState())
}
