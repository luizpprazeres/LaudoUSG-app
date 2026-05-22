import SwiftUI

@MainActor
struct DopplerCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void
    var prefillFrom: String? = nil

    @State private var weeks = 28
    @State private var days = 0
    @State private var ipUmbilical = ""
    @State private var ipMCA = ""
    @State private var ipUterinaDireita = ""
    @State private var ipUterinaEsquerda = ""
    @State private var result: DopplerCalculator.DopplerResult?
    @State private var errorMessage: String?
    @State private var didPrefill = false

    private var igResult: GestationalAgeCalculator.IGResult {
        let label = "\(weeks) semana\(weeks == 1 ? "" : "s")\(days > 0 ? " e \(days) dia\(days == 1 ? "" : "s")" : "")"
        return GestationalAgeCalculator.IGResult(
            weeks: weeks,
            days: days,
            dpp: Date(),
            method: .usg,
            label: label,
            insertBloco: ""
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputCard

                if let errorMessage {
                    feedbackBanner("Erro: \(errorMessage)")
                }

                if let result {
                    resultCard(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Doppler obstétrico")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prefillIfNeeded)
    }

    private func prefillIfNeeded() {
        guard !didPrefill, let source = prefillFrom, !source.isEmpty else { return }
        didPrefill = true
        let findings = DopplerParser.parse(achados: source)
        if let ig = findings.ig {
            weeks = ig.weeks
            days = ig.days
        }
        if let v = findings.umbilicalIP { ipUmbilical = formatPrefill(v) }
        if let v = findings.cerebralMediaIP { ipMCA = formatPrefill(v) }
        if let v = findings.uterinaDireitaIP { ipUterinaDireita = formatPrefill(v) }
        if let v = findings.uterinaEsquerdaIP { ipUterinaEsquerda = formatPrefill(v) }
    }

    private func formatPrefill(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    private var inputCard: some View {
        calculatorCard {
            Text("Idade gestacional")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(AppSurface.textPrimary)

            Stepper("Semanas: \(weeks)", value: $weeks, in: 20...42)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)

            Stepper("Dias: \(days)", value: $days, in: 0...6)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)

            Text("Índices de pulsatilidade")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(AppSurface.textPrimary)
                .padding(.top, Spacing.xs)

            decimalField("IP umbilical", text: $ipUmbilical)
            decimalField("IP cerebral média", text: $ipMCA)
            decimalField("IP uterina direita", text: $ipUterinaDireita)
            decimalField("IP uterina esquerda", text: $ipUterinaEsquerda)

            PrimaryButton(title: "Calcular") {
                calculate()
            }
        }
    }

    private func resultCard(_ result: DopplerCalculator.DopplerResult) -> some View {
        calculatorCard {
            vesselRow(title: "Artéria umbilical", result: result.arteriaUmbilical)
            vesselRow(title: "Artéria cerebral média", result: result.arteriaCerebralMedia)
            uterineRow(result.arteriasUterinas)
            vesselRow(title: "Ratio cerebroplacentário", result: result.ratioCerebroplacentario)

            PrimaryButton(title: "Inserir no laudo", icon: "plus.circle.fill") {
                onInsert(DopplerCalculator.insertBloco(from: result, ig: igResult))
            }
            .padding(.top, Spacing.xs)
        }
    }

    private func vesselRow(title: String, result: DopplerCalculator.VesselResult) -> some View {
        resultRow(
            title: title,
            value: "IP \(DopplerCalculator.fmt(result.ip))",
            detail: "p\(DopplerCalculator.pct(result.percentile)) · z \(DopplerCalculator.fmt(result.zscore))",
            pathological: result.pathological
        )
    }

    private func uterineRow(_ result: DopplerCalculator.UterineVesselResult) -> some View {
        resultRow(
            title: "Artérias uterinas",
            value: "IP médio \(DopplerCalculator.fmt(result.ipMedio))",
            detail: "p\(DopplerCalculator.pct(result.percentile)) · z \(DopplerCalculator.fmt(result.zscore))",
            pathological: result.pathological
        )
    }

    private func resultRow(
        title: String,
        value: String,
        detail: String,
        pathological: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textPrimary)

                Text("\(value) · \(detail)")
                    .font(TextStyle.footnote)
                    .foregroundStyle(AppSurface.textSecondary)
            }

            Spacer()

            Text(pathological ? "ALTERADO" : "OK")
                .font(TextStyle.captionMedium)
                .foregroundStyle(pathological ? SemanticColor.errorText : SemanticColor.successText)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(
                    Capsule()
                        .fill(pathological ? SemanticColor.errorBg : SemanticColor.successBg)
                )
        }
        .padding(.vertical, Spacing.xs)
    }

    private func calculate() {
        errorMessage = nil

        guard
            let ua = decimal(ipUmbilical),
            let mca = decimal(ipMCA),
            let utd = decimal(ipUterinaDireita),
            let ute = decimal(ipUterinaEsquerda),
            ua > 0,
            mca > 0,
            utd > 0,
            ute > 0
        else {
            result = nil
            errorMessage = "preencha todos os IPs com valores positivos"
            return
        }

        result = DopplerCalculator.calculate(
            DopplerCalculator.DopplerInput(
                weeks: weeks,
                days: days,
                ipUmbilical: ua,
                ipMCA: mca,
                ipUterinaDireita: utd,
                ipUterinaEsquerda: ute
            )
        )
    }

    private func decimal(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func decimalField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(TextStyle.bodyLarge)
            .keyboardType(.decimalPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(errorMessage == nil ? AppSurface.border : SemanticColor.errorBorder, lineWidth: 1)
            )
    }

    private func calculatorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md, content: content)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
    }

    private func feedbackBanner(_ text: String) -> some View {
        Text(text)
            .font(TextStyle.bodyMedium)
            .foregroundStyle(SemanticColor.warningText)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(SemanticColor.warningBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(SemanticColor.warningBorder, lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        DopplerCalculatorSheet(onInsert: { _ in }, onDismiss: {})
    }
}
