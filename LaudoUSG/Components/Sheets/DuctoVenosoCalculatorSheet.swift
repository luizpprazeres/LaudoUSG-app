import SwiftUI

@MainActor
struct DuctoVenosoCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var igWeeks: Int = 28
    @State private var piText: String = ""
    @State private var ondaA: DuctoVenosoCalculator.OndaA = .positiva

    private var result: DuctoVenosoCalculator.DVResult? {
        guard let pi = decimal(piText) else { return nil }
        return DuctoVenosoCalculator.calculate(.init(igWeeks: igWeeks, pi: pi, ondaA: ondaA))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Z-score do IP do ducto venoso fetal (Hecher 2001). Marcador de função cardíaca direita.")
                    .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
                igPicker
                piInput
                ondaAPicker
                if let result {
                    card(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Ducto venoso (Z-score)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var igPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Idade gestacional").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            Picker("Semanas", selection: $igWeeks) {
                ForEach(20...40, id: \.self) { Text("\($0) sem").tag($0) }
            }
            .pickerStyle(.menu)
        }
    }

    private var piInput: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("IP do ducto venoso").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            TextField("ex: 0,82", text: $piText)
                .keyboardType(.decimalPad)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
    }

    private var ondaAPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Padrão da onda A").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            Picker("Onda A", selection: $ondaA) {
                Text("Positiva").tag(DuctoVenosoCalculator.OndaA.positiva)
                Text("Ausente").tag(DuctoVenosoCalculator.OndaA.ausente)
                Text("Reversa").tag(DuctoVenosoCalculator.OndaA.reversa)
            }
            .pickerStyle(.segmented)
        }
    }

    private func card(_ r: DuctoVenosoCalculator.DVResult) -> some View {
        let abnormal = r.classification != .normal
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Z " + String(format: "%+.2f", r.zScore).replacingOccurrences(of: ".", with: ","))
                    .font(TextStyle.h2)
                    .foregroundStyle(BrandColor.primaryDeep)
                Text("p\(r.percentile)")
                    .font(TextStyle.bodyLargeMedium)
                    .foregroundStyle(AppSurface.textSecondary)
            }
            Text(r.classification.label)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(abnormal ? SemanticColor.warningText : AppSurface.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }

    private func insertButton(_ r: DuctoVenosoCalculator.DVResult) -> some View {
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
        Double(s.replacingOccurrences(of: ",", with: "."))
    }
}
