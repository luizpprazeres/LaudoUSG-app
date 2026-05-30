import SwiftUI

@MainActor
struct HadlockCalculatorSheet: View {
    @Environment(AppState.self) private var app

    let onInsert: (String) -> Void
    let onDismiss: () -> Void
    var sexHint: Sex = .unisex

    @State private var dbpText: String = ""
    @State private var ccText: String = ""
    @State private var caText: String = ""
    @State private var cfText: String = ""
    @State private var igWeeks: Int = 30
    @State private var igDays: Int = 0

    private var result: BiometryResult? {
        guard let dbp = decimal(dbpText),
              let cc = decimal(ccText),
              let ca = decimal(caText),
              let cf = decimal(cfText) else { return nil }
        return HadlockCalculator.calculate(.init(
            dbp: dbp, cc: cc, ca: ca, cf: cf,
            igWeeks: igWeeks, igDays: igDays, sex: sexHint
        ), weightFormula: app.preferences.weightFormula,
           percentileSource: app.preferences.percentileSource)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                description
                measureInputs
                igPicker
                if let result {
                    resultCard(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Peso fetal (Hadlock)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Estimativa de peso fetal por biometria (Hadlock 4, 1985).")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            Text("Aceita medidas em mm ou cm — converte automático.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
    }

    private var measureInputs: some View {
        VStack(spacing: Spacing.sm) {
            measureField(label: "DBP (Diâmetro biparietal)", text: $dbpText, placeholder: "ex: 72 mm ou 7,2 cm")
            measureField(label: "CC (Circunferência da cabeça)", text: $ccText, placeholder: "ex: 280 mm")
            measureField(label: "CA (Circunferência abdominal)", text: $caText, placeholder: "ex: 260 mm")
            measureField(label: "CF (Comprimento do fêmur)", text: $cfText, placeholder: "ex: 56 mm")
        }
    }

    private func measureField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
            TextField(placeholder, text: text)
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
    }

    private var igPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Idade gestacional")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
            HStack(spacing: Spacing.sm) {
                Picker("Semanas", selection: $igWeeks) {
                    ForEach(20...41, id: \.self) { Text("\($0) sem").tag($0) }
                }
                Picker("Dias", selection: $igDays) {
                    ForEach(0...6, id: \.self) { Text("\($0) d").tag($0) }
                }
            }
        }
    }

    private func resultCard(_ r: BiometryResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(r.weightGrams) g")
                    .font(TextStyle.h2)
                    .foregroundStyle(BrandColor.primaryDeep)
                Text("±\(r.weightVariation) g")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
            }
            Text(r.percentileLabel)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(r.isSGA || r.isLGA ? SemanticColor.warningText : AppSurface.textPrimary)
            Text("Cálculo via \(r.percentileSourceUsed.displayName)")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
            if r.isSGA {
                Text("⚠️ Peso abaixo do esperado (PIG) — considerar Doppler obstétrico em 1-2 semanas.")
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText)
            } else if r.isLGA {
                Text("⚠️ Peso acima do esperado (GIG) — considerar avaliação de macrossomia.")
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppSurface.card)
        )
    }

    private func insertButton(_ r: BiometryResult) -> some View {
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
