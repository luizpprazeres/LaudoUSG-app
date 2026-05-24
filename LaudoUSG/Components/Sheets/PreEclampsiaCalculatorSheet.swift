import SwiftUI

@MainActor
struct PreEclampsiaCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var idade: String = ""
    @State private var imc: String = ""
    @State private var map: String = ""
    @State private var uterinaPi: String = ""
    @State private var igWeeks: Int = 12
    @State private var primigesta: Bool = false
    @State private var antecedentePE: Bool = false
    @State private var hasOrSLE: Bool = false

    private var result: PreEclampsiaCalculator.PEResult? {
        guard let i = Int(idade),
              let bm = decimal(imc),
              let m = decimal(map),
              let pi = decimal(uterinaPi) else { return nil }
        return PreEclampsiaCalculator.calculate(.init(
            idadeMaterna: i, imc: bm, mapMmHg: m, uterinaPiMedio: pi,
            igWeeks: igWeeks, primigesta: primigesta,
            antecedentePE: antecedentePE, hasOrSLE: hasOrSLE
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Triagem simplificada de risco de pré-eclâmpsia no 1º trimestre. Versão MVP (FMF simplificado — sem PAPP-A/PlGF).")
                    .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
                inputsGroup
                fatoresGroup
                if let result {
                    card(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Pré-eclâmpsia (1T)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputsGroup: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                numField("Idade (anos)", text: $idade, kb: .numberPad)
                numField("IMC (kg/m²)", text: $imc, kb: .decimalPad)
            }
            HStack(spacing: Spacing.sm) {
                numField("MAP (mmHg)", text: $map, kb: .decimalPad)
                numField("IP médio uterinas", text: $uterinaPi, kb: .decimalPad)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Idade gestacional").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
                Picker("IG", selection: $igWeeks) {
                    ForEach(11...24, id: \.self) { Text("\($0) sem").tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var fatoresGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Fatores de risco materno").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary).textCase(.uppercase)
            Toggle("Primigesta", isOn: $primigesta).tint(BrandColor.primary)
            Toggle("Antecedente de pré-eclâmpsia", isOn: $antecedentePE).tint(BrandColor.primary)
            Toggle("HAS / DM / LES / SAF", isOn: $hasOrSLE).tint(BrandColor.primary)
        }
    }

    private func numField(_ label: String, text: Binding<String>, kb: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            TextField("", text: text)
                .keyboardType(kb)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func card(_ r: PreEclampsiaCalculator.PEResult) -> some View {
        let isAlto = r.risk == .alto
        let isIntermed = r.risk == .intermediario
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(r.risk.label)
                .font(TextStyle.h2)
                .foregroundStyle(isAlto ? SemanticColor.warningText : (isIntermed ? BrandColor.primaryDeep : AppSurface.textPrimary))
            Text("Pontuação: \(r.pontos)")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
            Text(r.risk.recomendacao)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }

    private func insertButton(_ r: PreEclampsiaCalculator.PEResult) -> some View {
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
