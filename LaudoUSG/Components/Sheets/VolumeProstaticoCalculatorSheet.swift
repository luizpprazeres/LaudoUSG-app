import SwiftUI

@MainActor
struct VolumeProstaticoCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var width: String = ""
    @State private var height: String = ""
    @State private var length: String = ""
    @State private var psa: String = ""

    private var result: VolumeProstaticoCalculator.VPResult? {
        guard let w = decimal(width), let h = decimal(height), let l = decimal(length) else { return nil }
        return VolumeProstaticoCalculator.calculate(.init(
            widthCm: w, heightCm: h, lengthCm: l,
            psaNgPerMl: decimal(psa)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Volume prostático pela fórmula do elipsoide (W × H × L × 0,523). PSA opcional para cálculo da densidade.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                dimensionsGroup
                psaField
                if let result {
                    card(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Volume prostático")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dimensionsGroup: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                field("Transverso (cm)", text: $width)
                field("AP (cm)", text: $height)
                field("Crânio-caudal (cm)", text: $length)
            }
        }
    }

    private var psaField: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("PSA (ng/mL) — opcional").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            TextField("ex: 2,5", text: $psa)
                .keyboardType(.decimalPad)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
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

    private func card(_ r: VolumeProstaticoCalculator.VPResult) -> some View {
        let abnormal = r.classification != .normal
        let volFmt = String(format: "%.1f", r.volumeCc).replacingOccurrences(of: ".", with: ",")
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(volFmt) cm³")
                .font(TextStyle.h2)
                .foregroundStyle(BrandColor.primaryDeep)
            Text(r.classification.label)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(abnormal ? SemanticColor.warningText : AppSurface.textPrimary)
            if let d = r.psaDensity {
                let dFmt = String(format: "%.2f", d).replacingOccurrences(of: ".", with: ",")
                Text("PSA density: \(dFmt) ng/mL/cc")
                    .font(TextStyle.caption)
                    .foregroundStyle(r.psaDensityElevated ? SemanticColor.warningText : AppSurface.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }

    private func insertButton(_ r: VolumeProstaticoCalculator.VPResult) -> some View {
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
