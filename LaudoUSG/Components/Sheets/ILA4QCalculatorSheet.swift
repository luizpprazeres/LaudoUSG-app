import SwiftUI

@MainActor
struct ILA4QCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var q1: String = ""
    @State private var q2: String = ""
    @State private var q3: String = ""
    @State private var q4: String = ""

    private var result: ILA4QCalculator.ILAResult? {
        guard let v1 = decimal(q1), let v2 = decimal(q2),
              let v3 = decimal(q3), let v4 = decimal(q4) else { return nil }
        return ILA4QCalculator.calculate(.init(q1: v1, q2: v2, q3: v3, q4: v4))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Soma das medidas verticais dos maiores bolsões nos 4 quadrantes (técnica de Phelan, 1987).")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                quadrantInputs
                if let result {
                    resultCard(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("ILA 4 quadrantes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var quadrantInputs: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                quadrantField("Quadrante superior direito (Q1)", text: $q1)
                quadrantField("Quadrante superior esquerdo (Q2)", text: $q2)
            }
            HStack(spacing: Spacing.sm) {
                quadrantField("Quadrante inferior direito (Q3)", text: $q3)
                quadrantField("Quadrante inferior esquerdo (Q4)", text: $q4)
            }
        }
    }

    private func quadrantField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 32, alignment: .topLeading)
            TextField("cm", text: text)
                .keyboardType(.decimalPad)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(AppSurface.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(AppSurface.border, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func resultCard(_ r: ILA4QCalculator.ILAResult) -> some View {
        let isAbnormal = r.classification != .normal
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(format: "%.1f cm", r.total).replacingOccurrences(of: ".", with: ","))
                .font(TextStyle.h2)
                .foregroundStyle(BrandColor.primaryDeep)
            Text(r.classification.label)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(isAbnormal ? SemanticColor.warningText : AppSurface.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppSurface.card)
        )
    }

    private func insertButton(_ r: ILA4QCalculator.ILAResult) -> some View {
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
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(BrandColor.primary)
                )
        }
    }

    private func decimal(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }
}
