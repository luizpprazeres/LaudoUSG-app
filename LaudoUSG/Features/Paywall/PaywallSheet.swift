import SwiftUI

@MainActor
struct PaywallSheet: View {
    let onSuccess: () -> Void
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    private var pricingURL: URL {
        AppConfig.webBaseURL.appending(path: "precos")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurface.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    infoCard
                    actions
                    Spacer(minLength: Spacing.md)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
            }
            .navigationTitle("Plano gratuito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Agora não", action: onDismiss)
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "lock.open.display")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(BrandColor.primary)
                .padding(.bottom, Spacing.xs)

            Text("Sua conta está no plano gratuito.")
                .font(TextStyle.h2)
                .foregroundStyle(AppSurface.textPrimary)

            Text("As assinaturas são gerenciadas no site.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            featureRow("Acesse laudousg.com para gerenciar sua assinatura.")
            featureRow("Depois de concluir no site, volte ao app e atualize sua conta.")
            featureRow("O app libera o acesso assim que seu plano estiver ativo no perfil.")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                Haptics.tap()
                openURL(pricingURL)
            } label: {
                Text("Gerenciar em laudousg.com")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .fill(BrandColor.primary)
                    )
            }

            Button {
                Haptics.tap()
                onSuccess()
            } label: {
                Text("Já assinei — atualizar")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(BrandColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .fill(AppSurface.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .stroke(AppSurface.border, lineWidth: 1)
                    )
            }

            Button("Agora não", action: onDismiss)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xs)
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BrandColor.primary)
                .frame(width: 20, height: 20)
            Text(text)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
    }
}
