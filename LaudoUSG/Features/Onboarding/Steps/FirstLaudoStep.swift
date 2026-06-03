import SwiftUI

struct FirstLaudoStep: View {
    let laudoText: String
    let reportId: String?
    let namespace: Namespace.ID
    let onContinue: () -> Void

    @State private var revealCount = 0

    var body: some View {
        OnboardingStepContainer {
            Label("Salvo no histórico", systemImage: "checkmark.circle.fill")
                .font(TextStyle.captionMedium)
                .foregroundStyle(SemanticColor.successText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Ultrassonografia do Abdome Total")
                        .font(TextStyle.bodySemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(visibleLaudo)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(AppSurface.textPrimary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
            }
            .background(AppSurface.card, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
            .matchedGeometryEffect(id: "first-laudo-card", in: namespace)
            .onAppear {
                revealCount = 0
                withAnimation(.linear(duration: min(2.4, Double(laudoText.count) / 90))) {
                    revealCount = laudoText.count
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Foi você que fez.")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(BrandColor.primaryDeep)
                Text("Você ditou. A IA gerou. Já está salvo no seu histórico.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(BrandColor.primaryTint, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))

            PrimaryButton(title: "Concluir", icon: "checkmark") {
                onContinue()
            }
        }
    }

    private var visibleLaudo: String {
        guard revealCount < laudoText.count else { return laudoText }
        return String(laudoText.prefix(revealCount))
    }
}

private struct FirstLaudoStepPreview: View {
    @Namespace private var namespace

    var body: some View {
        FirstLaudoStep(
            laudoText: "ULTRASSONOGRAFIA DO ABDOME TOTAL\n\nCOMENTÁRIOS:\nExame realizado com transdutor convexo.\n\nCONCLUSÃO:\n1. Órgãos abdominais sem alterações ecográficas.",
            reportId: "preview",
            namespace: namespace,
            onContinue: {}
        )
        .background(AppSurface.background)
    }
}

#Preview {
    FirstLaudoStepPreview()
}
