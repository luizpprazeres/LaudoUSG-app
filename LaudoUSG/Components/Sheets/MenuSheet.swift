import SwiftUI

struct MenuSheet: View {
    @Environment(AppState.self) private var app

    let onTapHistorico: () -> Void
    let onTapAnalytics: () -> Void
    let onTapBiblioteca: () -> Void
    let onTapPreferencias: () -> Void
    let onTapSeguranca: () -> Void
    let onLogout: () -> Void

    private var items: [MenuSheetItem] {
        [
            MenuSheetItem(label: "Histórico", systemImage: "clock", action: onTapHistorico),
            MenuSheetItem(label: "Analytics", systemImage: "chart.bar", action: onTapAnalytics),
            MenuSheetItem(label: "Biblioteca", systemImage: "books.vertical", action: onTapBiblioteca),
            MenuSheetItem(label: "Preferências", systemImage: "slider.horizontal.3", action: onTapPreferencias),
            MenuSheetItem(label: "Segurança", systemImage: "lock.shield", action: onTapSeguranca),
            MenuSheetItem(
                label: "Sair",
                systemImage: "rectangle.portrait.and.arrow.right",
                tint: SemanticColor.errorAccent,
                action: onLogout
            )
        ]
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            header
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)

            VStack(spacing: Spacing.zero) {
                ForEach(items) { item in
                    menuRow(item)

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
            .padding(.horizontal, Spacing.md)

            Spacer()
        }
        .background(AppSurface.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Text(app.profile?.planLabel ?? "Gratuito")
                .font(TextStyle.captionMedium)
                .foregroundStyle(BrandColor.primaryDeep)
                .padding(.horizontal, Spacing.sm)
                .frame(minWidth: 76, minHeight: 36)
                .background(Capsule().fill(BrandColor.primarySoft))
                .overlay(Capsule().stroke(BrandColor.primaryBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(displayName)
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(AppSurface.textPrimary)

                Text(app.profile?.email ?? "—")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
            }

            Spacer()
        }
    }

    private var displayName: String {
        let name = app.profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty && !name.contains("@") { return name }
        if let email = app.profile?.email, let localPart = email.split(separator: "@").first {
            return String(localPart)
        }
        return "Usuário"
    }

    private func menuRow(_ item: MenuSheetItem) -> some View {
        Button(action: item.action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(item.tint)
                    .frame(width: 32, height: 32)

                Text(item.label)
                    .font(TextStyle.bodyLargeMedium)
                    .foregroundStyle(item.tint)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSurface.textMuted)
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 56)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(item.label)
    }
}

private struct MenuSheetItem: Identifiable {
    var id: String { label }
    let label: String
    let systemImage: String
    var tint: Color = AppSurface.textPrimary
    let action: () -> Void
}

    #Preview {
        MenuSheet(
            onTapHistorico: {},
        onTapAnalytics: {},
        onTapBiblioteca: {},
        onTapPreferencias: {},
            onTapSeguranca: {},
            onLogout: {}
        )
        .environment(AppState())
    }
