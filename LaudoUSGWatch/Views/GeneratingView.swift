import SwiftUI

struct GeneratingView: View {
    @Environment(WatchAppState.self) private var app
    let category: CategoryWatch

    var body: some View {
        VStack(spacing: WatchTheme.s4) {
            if app.success {
                Circle()
                    .fill(WatchTheme.brand.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(WatchTheme.brand)
                            .symbolEffect(.bounce.up, value: app.success)
                    )
                Text("Enviado à sala")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(WatchTheme.textPrimary)
            } else {
                ArcProgressView()
                    .frame(width: 72, height: 72)

                Text(app.generationPhase ?? "Gerando")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(WatchTheme.textPrimary)
                    .contentTransition(.opacity)

                Text(category.label.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(WatchTheme.textMuted)
            }
        }
        .sensoryFeedback(.success, trigger: app.success)
    }
}

#Preview {
    GeneratingView(category: .tireoide)
        .environment(WatchAppState())
}
