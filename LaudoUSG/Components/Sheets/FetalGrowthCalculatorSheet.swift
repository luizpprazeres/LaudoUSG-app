import SwiftUI

@MainActor
struct FetalGrowthCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var percentileText = ""
    @State private var source = "Intergrowth-21st"
    @State private var weeks = 30
    @State private var days = 0
    @State private var dopplerCompleteNormal = false
    @State private var cprBelowP5 = false
    @State private var cprConfirmed = false
    @State private var mcaBelowP5 = false
    @State private var mcaConfirmed = false
    @State private var uterinesAboveP95 = false
    @State private var uaFlow: FetalGrowthCalculator.EndDiastolicFlow = .present
    @State private var uaMajorityBothArteries = false
    @State private var uaConfirmed = false
    @State private var dvState: DvState = .normal
    @State private var dvConfirmed = false
    @State private var pathologicalCtg = false

    private enum DvState: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case piAboveP95 = "IP > p95"
        case absent = "Diástole ausente"
        case reversed = "Diástole reversa"
        case dicrotic = "Pulsações dicróticas"
        var id: String { rawValue }
    }

    private var result: FetalGrowthCalculator.Result? {
        guard let percentile = Double(percentileText.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        var input = FetalGrowthCalculator.Input(
            efwPercentile: percentile,
            efwPercentileSource: source,
            gestationalWeeks: weeks,
            gestationalDays: days
        )
        input.dopplerAssessmentCompleteAndNormal = dopplerCompleteNormal
        input.cprBelowP5 = .init(present: cprBelowP5, confirmed: cprConfirmed)
        input.mcaPiBelowP5 = .init(present: mcaBelowP5, confirmed: mcaConfirmed)
        input.meanUterinePiAboveP95 = uterinesAboveP95
        input.umbilicalArteryEndDiastolicFlow = uaFlow
        input.umbilicalFlowAbnormalInMajorityBothArteries = uaMajorityBothArteries
        input.umbilicalFlowConfirmedInRequiredInterval = uaConfirmed
        input.ductusVenosus = .init(
            piAboveP95: dvState == .piAboveP95,
            diastolicFlow: dvState == .absent ? .absent : dvState == .reversed ? .reversed : .present,
            persistentDicroticVenousPulsations: dvState == .dicrotic,
            confirmedAfter6To12Hours: dvConfirmed
        )
        input.pathologicalCtg = pathologicalCtg
        return FetalGrowthCalculator.calculate(input)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Distingue PIG de RCF e aplica os estágios de Gratacós sem fechar critérios que ainda exigem uma segunda medida.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)

                HStack(spacing: Spacing.sm) {
                    field("Percentil do peso", text: $percentileText, placeholder: "ex: 6")
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Idade gestacional")
                            .font(TextStyle.captionMedium)
                            .foregroundStyle(AppSurface.textSecondary)
                        HStack(spacing: 0) {
                            Picker("Semanas", selection: $weeks) {
                                ForEach(11...44, id: \.self) { Text("\($0)s").tag($0) }
                            }
                            Picker("Dias", selection: $days) {
                                ForEach(0...6, id: \.self) { Text("\($0)d").tag($0) }
                            }
                        }
                    }
                }
                field("Curva do percentil", text: $source, placeholder: "Intergrowth-21st", keyboard: .default)

                sectionTitle("Avaliação Doppler")
                toggle("UA, ACM, RCP e uterinas completos e normais", isOn: $dopplerCompleteNormal)
                toggle("RCP abaixo do percentil 5", isOn: $cprBelowP5)
                if cprBelowP5 { confirmation("Confirmada em duas medidas >12 h", isOn: $cprConfirmed) }
                toggle("IP da ACM abaixo do percentil 5", isOn: $mcaBelowP5)
                if mcaBelowP5 { confirmation("Confirmada em duas medidas >12 h", isOn: $mcaConfirmed) }
                toggle("IP médio das uterinas acima do percentil 95", isOn: $uterinesAboveP95)

                pickerRow("Fluxo diastólico da umbilical", selection: $uaFlow) {
                    Text("Presente").tag(FetalGrowthCalculator.EndDiastolicFlow.present)
                    Text("Ausente").tag(FetalGrowthCalculator.EndDiastolicFlow.absent)
                    Text("Reverso").tag(FetalGrowthCalculator.EndDiastolicFlow.reversed)
                }
                if uaFlow == .absent || uaFlow == .reversed {
                    confirmation(">50% dos ciclos, nas duas artérias", isOn: $uaMajorityBothArteries)
                    confirmation("Confirmado no intervalo exigido", isOn: $uaConfirmed)
                }

                pickerRow("Ducto venoso", selection: $dvState) {
                    ForEach(DvState.allCases) { state in Text(state.rawValue).tag(state) }
                }
                if dvState != .normal {
                    confirmation("Confirmado em duas medidas >6–12 h", isOn: $dvConfirmed)
                }
                toggle("CTG patológico", isOn: $pathologicalCtg)

                if let result {
                    resultCard(result)
                    Button {
                        Haptics.success()
                        onInsert("\n" + FetalGrowthCalculator.insertBlock(from: result) + "\n")
                        onDismiss()
                    } label: {
                        Text("Inserir no laudo")
                            .font(TextStyle.bodyLargeSemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(BrandColor.primary))
                    }
                } else {
                    Text("Informe um percentil entre 0 e 100.")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Crescimento fetal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .decimalPad
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(TextStyle.captionMedium)
            .foregroundStyle(AppSurface.textSecondary)
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(TextStyle.body)
            .tint(BrandColor.primary)
    }

    private func confirmation(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(TextStyle.caption)
            .foregroundStyle(SemanticColor.warningText)
            .tint(BrandColor.primary)
            .padding(.leading, Spacing.sm)
    }

    private func pickerRow<Selection: Hashable, Content: View>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            Picker(title, selection: selection, content: content)
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xs)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
        }
    }

    private func resultCard(_ result: FetalGrowthCalculator.Result) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(result.conclusion)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(AppSurface.textPrimary)
            ForEach(result.pendingCriteria, id: \.code) { item in
                Text("\(item.label): confirmação pendente.")
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText)
            }
            ForEach(result.warnings, id: \.self) { warning in
                Text(warning).font(TextStyle.caption).foregroundStyle(SemanticColor.warningText)
            }
            Text(result.reportReference)
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }
}
