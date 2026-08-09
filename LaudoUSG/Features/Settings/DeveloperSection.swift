import SwiftUI

/// Seção escondida de Ajustes, destravada por 7 toques na versão (Sobre o app).
///
/// Nada aqui é para usuário final. Fica no app, e não atrás de uma build
/// separada, para dar para comparar modelo em aparelho real sem recompilar.
struct DeveloperSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if AppExperiments.developerToolsUnlocked {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Desenvolvedor")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                    .textCase(.uppercase)

                VStack(spacing: 0) {
                    Toggle(isOn: experimentalModelBinding) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Modelo experimental")
                                .font(TextStyle.bodyLargeMedium)
                                .foregroundStyle(AppSurface.textPrimary)
                            Text("Gera com o provider alternativo, em qualquer categoria. Restrito no servidor.")
                                .font(TextStyle.caption)
                                .foregroundStyle(AppSurface.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(BrandColor.advanced)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }
                .background(
                    RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                        .fill(AppSurface.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                        .stroke(AppSurface.border, lineWidth: 1)
                )

                // O laudo gerado aqui NÃO é comparável ao de produção. Sem este
                // aviso é fácil ligar, esquecer, e depois estranhar o resultado.
                if app.preferences.experimentalModel {
                    Label(
                        "Ligado. Os laudos saem de outro modelo até você desligar.",
                        systemImage: "flask"
                    )
                    .font(TextStyle.caption)
                    .foregroundStyle(BrandColor.advanced)
                    .padding(.horizontal, Spacing.xs)
                }
            }
        }
    }

    private var experimentalModelBinding: Binding<Bool> {
        Binding(
            get: { app.preferences.experimentalModel },
            set: { newValue in
                Haptics.tap()
                var preferences = app.preferences
                preferences.experimentalModel = newValue
                app.updatePreferences(preferences)
            }
        )
    }
}
