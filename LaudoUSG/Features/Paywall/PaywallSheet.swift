import SwiftUI

@MainActor
struct PaywallSheet: View {
    let onSuccess: () -> Void
    let onDismiss: () -> Void

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
            .navigationTitle("Acesso restrito")
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

            Text("Acesso restrito")
                .font(TextStyle.h2)
                .foregroundStyle(AppSurface.textPrimary)

            Text("Este recurso requer uma conta com acesso ativo.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            featureRow("Se você já tem acesso, atualize sua conta para liberar o recurso.")
            featureRow("Caso o acesso ainda não apareça, tente novamente em alguns instantes.")
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
                onSuccess()
            } label: {
                Text("Já tenho acesso — atualizar")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .fill(BrandColor.primary)
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
