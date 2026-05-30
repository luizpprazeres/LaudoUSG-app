import SwiftUI

struct PreferencesSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Percentil obstétrico")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            VStack(spacing: 0) {
                ForEach(PercentileSource.allCases, id: \.self) { source in
                    Button {
                        Haptics.tap()
                        var preferences = app.preferences
                        preferences.percentileSource = source
                        app.updatePreferences(preferences)
                    } label: {
                        percentileRow(source)
                    }
                    .buttonStyle(PressableButtonStyle())
                    if source != PercentileSource.allCases.last {
                        Divider().padding(.leading, Spacing.md)
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
        }
    }

    private func percentileRow(_ source: PercentileSource) -> some View {
        let selected = app.preferences.percentileSource == source
        return HStack(spacing: Spacing.sm) {
            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selected ? BrandColor.primary : AppSurface.textMuted)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(source.displayName)
                    .font(TextStyle.bodyLargeMedium)
                    .foregroundStyle(AppSurface.textPrimary)
                Text(subtitle(for: source))
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 58)
    }

    private func subtitle(for source: PercentileSource) -> String {
        switch source {
        case .intergrowth21st:
            "Padrão OMS, curva universal Intergrowth-21st"
        case .hadlock1991:
            "Curva Hadlock legacy"
        case .whoMulticentre2017:
            "Sex-specific quando disponível, em curadoria"
        }
    }
}

#Preview {
    PreferencesSection()
        .environment(AppState())
        .padding()
        .background(AppSurface.background)
}
