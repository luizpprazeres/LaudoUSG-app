import SwiftUI

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Privacidade & Segurança")
                    .font(TextStyle.h3)
                    .foregroundStyle(AppSurface.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppSurface.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppSurface.muted))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                bullet("Seus laudos são privados. Só você acessa.")
                bullet("Dados de paciente nunca vão pro servidor.")
                bullet("Revise antes de assinar.")
            }

            Link(destination: URL(string: "https://laudousg.com/privacy")!) {
                HStack(spacing: Spacing.xs) {
                    Text("Política de Privacidade")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(TextStyle.bodyMedium)
                .foregroundStyle(BrandColor.primary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurface.background.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(BrandColor.primary)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            Text(text)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)
        }
    }
}

#Preview {
    Text("Open Sheet")
        .sheet(isPresented: .constant(true)) {
            PrivacySheet()
        }
}
