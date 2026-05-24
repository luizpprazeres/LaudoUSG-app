import SwiftUI

@MainActor
struct VolumeResidualCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var width: String = ""
    @State private var height: String = ""
    @State private var length: String = ""

    private var result: VolumeResidualCalculator.VRResult? {
        guard let w = decimal(width), let h = decimal(height), let l = decimal(length) else { return nil }
        return VolumeResidualCalculator.calculate(.init(widthCm: w, heightCm: h, lengthCm: l))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Volume residual pós-miccional. Medir a bexiga imediatamente após esvaziamento.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                HStack(spacing: Spacing.sm) {
                    field("Transverso (cm)", text: $width)
                    field("AP (cm)", text: $height)
                    field("Longitudinal (cm)", text: $length)
                }
                if let result {
                    card(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Resíduo pós-miccional")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func card(_ r: VolumeResidualCalculator.VRResult) -> some View {
        let abnormal = r.classification != .ausente
        let volFmt = String(format: "%.0f", r.volumeMl)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(volFmt) mL")
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

    private func insertButton(_ r: VolumeResidualCalculator.VRResult) -> some View {
        Button {
            Haptics.success()
            onInsert("\n" + r.insertBloco + "\n")
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

    private func decimal(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }
}
