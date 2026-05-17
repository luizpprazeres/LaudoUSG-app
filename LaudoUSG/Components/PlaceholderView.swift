import SwiftUI

struct PlaceholderView: View {
    let title: String
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(BrandColor.primarySoft)
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(BrandColor.primary)
            }
            Text(title)
                .font(TextStyle.h3)
                .foregroundStyle(AppSurface.textPrimary)
            Text(message)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppSurface.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PlaceholderView(
            title: "Em construção",
            icon: "hammer.fill",
            message: "Essa tela entra em sprints futuros."
        )
    }
}
