import SwiftUI
import Combine

struct ConfirmEmailView: View {
    let email: String
    let onCloseToLogin: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cooldown = 60
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(BrandColor.primary)

            VStack(spacing: Spacing.sm) {
                Text("Confirme seu email")
                    .font(TextStyle.h2)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Enviamos um link de ativação para \(email). Toque no link recebido para ativar sua conta e fazer login.")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.sm) {
                SecondaryButton(
                    title: cooldown > 0 ? "Aguarde \(cooldown)s..." : "Reenviar email",
                    icon: "arrow.clockwise"
                ) {
                    resend()
                }
                .disabled(cooldown > 0 || isSending)
                .opacity(cooldown > 0 || isSending ? 0.55 : 1)

                Button("Trocar email") {
                    Haptics.tap()
                    dismiss()
                }
                .font(TextStyle.bodyMedium)
                .foregroundStyle(BrandColor.primary)

                Button("Já confirmei, fazer login") {
                    Haptics.tap()
                    onCloseToLogin()
                }
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textSecondary)
            }

            if let successMessage {
                messageBanner(successMessage, isError: false)
            }
            if let errorMessage {
                messageBanner(errorMessage, isError: true)
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppSurface.background.ignoresSafeArea())
        .onReceive(timer) { _ in
            guard cooldown > 0 else { return }
            cooldown -= 1
        }
    }

    private func resend() {
        guard cooldown == 0, !isSending else { return }
        isSending = true
        errorMessage = nil
        successMessage = nil
        Task { @MainActor in
            do {
                try await AuthService.shared.resendConfirmation(email: email)
                Haptics.success()
                successMessage = "Email reenviado."
                cooldown = 60
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSending = false
        }
    }

    private func messageBanner(_ message: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? SemanticColor.errorText : SemanticColor.successText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(isError ? SemanticColor.errorText : SemanticColor.successText)
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(isError ? SemanticColor.errorBg : SemanticColor.successBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(isError ? SemanticColor.errorBorder : SemanticColor.successBorder, lineWidth: 1)
        )
    }
}

#Preview {
    ConfirmEmailView(email: "medico@clinica.com", onCloseToLogin: {})
}
