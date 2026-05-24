import SwiftUI

@MainActor
struct BIRADSCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var category: BIRADSCalculator.Category = .um
    @State private var lateralidade: String = ""

    private var result: BIRADSCalculator.BIRADSResult {
        BIRADSCalculator.calculate(category: category, lateralidade: lateralidade)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Categoria BI-RADS (ACR 5th Ed.) com recomendação clínica de conduta.")
                    .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
                categoriaPicker
                lateralidadeInput
                card(result)
                insertButton(result)
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("BI-RADS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoriaPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Categoria").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            Picker("BI-RADS", selection: $category) {
                ForEach(BIRADSCalculator.Category.allCases) { c in
                    Text(c.label).tag(c)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var lateralidadeInput: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Lateralidade (opcional)").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            TextField("ex: mama direita", text: $lateralidade)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
    }

    private func card(_ r: BIRADSCalculator.BIRADSResult) -> some View {
        let isSerious = ["4A","4B","4C","5","6"].contains(r.category.rawValue)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(r.category.label)
                .font(TextStyle.h2)
                .foregroundStyle(BrandColor.primaryDeep)
            Text(r.category.descricao)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(isSerious ? SemanticColor.warningText : AppSurface.textPrimary)
            Text("Probabilidade de malignidade: \(r.category.probMalignidade)")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }

    private func insertButton(_ r: BIRADSCalculator.BIRADSResult) -> some View {
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
}
