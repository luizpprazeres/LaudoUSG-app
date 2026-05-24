import SwiftUI

@MainActor
struct AFCCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var direito: String = ""
    @State private var esquerdo: String = ""

    private var result: AFCCalculator.AFCResult? {
        guard let d = Int(direito), let e = Int(esquerdo) else { return nil }
        return AFCCalculator.calculate(.init(direito: d, esquerdo: e))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Contagem de folículos antrais (2-10 mm) em cada ovário. Marcador de reserva ovariana.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                HStack(spacing: Spacing.sm) {
                    field("Ovário direito", text: $direito)
                    field("Ovário esquerdo", text: $esquerdo)
                }
                if let result {
                    card(result)
                    Button {
                        Haptics.success()
                        onInsert("\n" + result.insertBloco + "\n")
                        onDismiss()
                    } label: {
                        Text("Inserir no laudo")
                            .font(TextStyle.bodyLargeSemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(BrandColor.primary))
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Folículos antrais (AFC)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func card(_ r: AFCCalculator.AFCResult) -> some View {
        let abnormal = r.classification != .normal
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Total: \(r.total) folículos")
                .font(TextStyle.h2)
                .foregroundStyle(BrandColor.primaryDeep)
            Text(r.classification.label)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(abnormal ? SemanticColor.warningText : AppSurface.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }
}
