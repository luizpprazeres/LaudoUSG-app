import SwiftUI

struct PreferencesSection: View {
    @Environment(AppState.self) private var app

    /// Explicação aberta pelo ⓘ. `nil` = nenhuma folha na tela.
    @State private var info: PreferenceInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            transcriptionGroup
            percentileGroup
        }
        .sheet(item: $info) { PreferenceInfoSheet(info: $0) }
    }

    // MARK: - Ditado

    private var transcriptionGroup: some View {
        group("Ditado", items: TranscriptionEngine.allCases) { engine in
            optionRow(
                title: engine.displayName,
                // Indisponível troca o subtítulo pelo motivo — é a informação
                // que importa naquele momento.
                subtitle: engine.unavailableReason ?? engine.subtitle,
                // Compara com `effective`: se a preferência salva for um motor que
                // este aparelho não tem, marca o que REALMENTE vai ser usado.
                selected: app.preferences.transcriptionEngine.effective == engine,
                enabled: engine.isAvailableOnThisDevice,
                info: engine.info
            ) {
                var preferences = app.preferences
                preferences.transcriptionEngine = engine
                app.updatePreferences(preferences)
            }
        }
    }

    // MARK: - Percentil

    private var percentileGroup: some View {
        group("Percentil obstétrico", items: PercentileSource.allCases) { source in
            optionRow(
                title: source.displayName,
                subtitle: subtitle(for: source),
                selected: app.preferences.percentileSource == source,
                enabled: true,
                info: source.info
            ) {
                var preferences = app.preferences
                preferences.percentileSource = source
                app.updatePreferences(preferences)
            }
        }
    }

    private func subtitle(for source: PercentileSource) -> String {
        switch source {
        case .intergrowth21st: "Referência da OMS. É o padrão do app."
        case .hadlock1991: "A curva clássica, usada na maioria dos aparelhos."
        case .whoMulticentre2017: "Ajusta o percentil ao sexo do bebê, quando já é conhecido."
        }
    }

    // MARK: - Blocos reutilizáveis

    private func group<T: Hashable>(
        _ title: String,
        items: [T],
        @ViewBuilder row: @escaping (T) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    row(item)
                    if index < items.count - 1 {
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

    /// Linha de escolha com o ⓘ ao lado.
    ///
    /// O ⓘ fica FORA do botão de seleção de propósito: `Button` dentro de `Button`
    /// não funciona no SwiftUI — o toque interno é engolido pelo externo. Aqui são
    /// dois botões irmãos, então tocar no ⓘ abre a explicação sem trocar a opção.
    private func optionRow(
        title: String,
        subtitle: String,
        selected: Bool,
        enabled: Bool,
        info rowInfo: PreferenceInfo,
        select: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button {
                Haptics.tap()
                select()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selected ? BrandColor.primary : AppSurface.textMuted)
                        .opacity(enabled ? 1 : 0.4)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(title)
                            .font(TextStyle.bodyLargeMedium)
                            .foregroundStyle(enabled ? AppSurface.textPrimary : AppSurface.textMuted)
                        Text(subtitle)
                            .font(TextStyle.caption)
                            .foregroundStyle(AppSurface.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: Spacing.xs)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!enabled)

            // Continua tocável mesmo com a opção indisponível: é justamente aí
            // que o usuário quer saber o que é e o que precisa para liberar.
            Button {
                Haptics.tap()
                info = rowInfo
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(AppSurface.textMuted)
                    // Alvo de toque de 44pt (mínimo da Apple) sem inflar o visual.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sobre \(title)")
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.xxs)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 58)
    }
}

#Preview {
    PreferencesSection()
        .environment(AppState())
        .padding()
        .background(AppSurface.background)
}
