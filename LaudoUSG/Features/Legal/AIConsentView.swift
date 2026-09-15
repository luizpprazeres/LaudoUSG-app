import SwiftUI

struct AIConsentView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(BrandColor.primary)
                Text("Privacidade e IA")
                    .font(TextStyle.h2)
                Text("Com sua permissão, o LaudoUSG envia os dados dos recursos de IA aos seguintes prestadores:")
                Text("OpenAI: achados e conteúdo de laudos para elaboração e revisão; imagens selecionadas para extração de medidas; áudio quando usada a transcrição de gravações.")
                Text("Deepgram: áudio do microfone para transcrição ao vivo.")
                Text("Os laudos e dados extraídos são associados à sua conta. Evite identificadores de pacientes nos dados enviados à IA. Revise integralmente as medidas e o texto antes de usar o resultado.")
                Text("Você pode recusar ou retirar esta permissão. Histórico, calculadoras e recursos sem IA continuam disponíveis.")
                    .foregroundStyle(AppSurface.textSecondary)
                Link("Política de privacidade", destination: URL(string: "https://laudousg.com/privacy")!)
                PrimaryButton(title: "Permitir processamento por IA") {
                    app.setAIConsent(true)
                    dismiss()
                }
                SecondaryButton(title: app.aiConsentDecision == true ? "Retirar permissão" : "Agora não") {
                    app.setAIConsent(false)
                    dismiss()
                }
            }
            .font(TextStyle.bodyLarge)
            .foregroundStyle(AppSurface.textPrimary)
            .padding(Spacing.lg)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .interactiveDismissDisabled(app.aiConsentDecision == nil)
    }
}
