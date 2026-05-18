import SwiftUI

struct MedicalDisclaimerFooter: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SemanticColor.warningText)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Laudo elaborado com apoio de inteligência artificial.")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(SemanticColor.warningText)
                Text("O texto gerado é minuta automatizada e pode conter erros. Revise integralmente, valide clinicamente e edite antes de assinar. Você, médico, mantém responsabilidade profissional pelo laudo final.")
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText)
                Text("Em conformidade com a Resolução CFM 2.314/2022.")
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText.opacity(0.85))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(SemanticColor.warningBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(SemanticColor.warningBorder, lineWidth: 1)
        )
    }
}

#Preview {
    MedicalDisclaimerFooter()
        .padding()
        .background(AppSurface.background)
        .environment(AppState())
}
