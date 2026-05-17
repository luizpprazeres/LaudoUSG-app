import SwiftUI

@MainActor
struct IGCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var mode: IGMode = .dum
    @State private var dumText = ""
    @State private var usgDateText = ""
    @State private var usgWeeks = 12
    @State private var usgDays = 0
    @State private var result: GestationalAgeCalculator.IGResult?
    @State private var errorMessage: String?

    private var dumResult: GestationalAgeCalculator.IGResult? {
        guard let date = GestationalAgeCalculator.parseDateBR(dumText) else { return nil }
        return GestationalAgeCalculator.calcByDUM(dum: date)
    }

    private var usgResult: GestationalAgeCalculator.IGResult? {
        guard let date = GestationalAgeCalculator.parseDateBR(usgDateText) else { return nil }
        return GestationalAgeCalculator.calcByUSG(usgDate: date, usgWeeks: usgWeeks, usgDays: usgDays)
    }

    private var concordance: GestationalAgeCalculator.ConcordanceResult? {
        guard let dumResult, let usgResult else { return nil }
        return GestationalAgeCalculator.checkConcordance(dum: dumResult, usg: usgResult)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Picker("Modo", selection: $mode) {
                    Text("DUM").tag(IGMode.dum)
                    Text("USG").tag(IGMode.usg)
                }
                .pickerStyle(.segmented)

                if mode == .dum {
                    dumCard
                } else {
                    usgCard
                }

                if let errorMessage {
                    feedbackBanner(text: "Erro: \(errorMessage)", color: SemanticColor.warningText, background: SemanticColor.warningBg, border: SemanticColor.warningBorder)
                }

                if let result {
                    resultCard(result)
                }

                if let concordance {
                    concordanceCard(concordance)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Idade gestacional")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dumCard: some View {
        calculatorCard {
            Text("Data da última menstruação")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(AppSurface.textPrimary)

            inputField("DD/MM/AAAA", text: $dumText, hasError: errorMessage != nil)

            PrimaryButton(title: "Calcular") {
                calculateDUM()
            }
        }
    }

    private var usgCard: some View {
        calculatorCard {
            Text("Primeira ultrassonografia")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(AppSurface.textPrimary)

            inputField("Data do exame", text: $usgDateText, hasError: errorMessage != nil)

            Stepper("Semanas: \(usgWeeks)", value: $usgWeeks, in: 0...42)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)

            Stepper("Dias: \(usgDays)", value: $usgDays, in: 0...6)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)

            PrimaryButton(title: "Calcular") {
                calculateUSG()
            }
        }
    }

    private func resultCard(_ result: GestationalAgeCalculator.IGResult) -> some View {
        calculatorCard {
            Text(result.label)
                .font(TextStyle.h3)
                .foregroundStyle(AppSurface.textPrimary)

            Text("DPP: \(GestationalAgeCalculator.formatDate(result.dpp))")
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textSecondary)

            Text(result.insertBloco)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Inserir no laudo", icon: "plus.circle.fill") {
                onInsert(result.insertBloco)
            }
        }
    }

    private func concordanceCard(_ concordance: GestationalAgeCalculator.ConcordanceResult) -> some View {
        let ok = concordance.concordant
        return feedbackBanner(
            text: ok
                ? "DUM e USG concordantes. Diferença: \(concordance.diff)d."
                : "DUM e USG discordantes. Diferença: \(concordance.diff)d, limite: \(concordance.threshold)d.",
            color: ok ? SemanticColor.successText : SemanticColor.warningText,
            background: ok ? SemanticColor.successBg : SemanticColor.warningBg,
            border: ok ? SemanticColor.successBorder : SemanticColor.warningBorder
        )
    }

    private func calculateDUM() {
        errorMessage = nil
        guard let date = GestationalAgeCalculator.parseDateBR(dumText) else {
            errorMessage = "data inválida"
            result = nil
            return
        }

        guard let next = GestationalAgeCalculator.calcByDUM(dum: date) else {
            errorMessage = "data deve estar no passado"
            result = nil
            return
        }

        result = next
    }

    private func calculateUSG() {
        errorMessage = nil
        guard let date = GestationalAgeCalculator.parseDateBR(usgDateText) else {
            errorMessage = "data inválida"
            result = nil
            return
        }

        guard let next = GestationalAgeCalculator.calcByUSG(usgDate: date, usgWeeks: usgWeeks, usgDays: usgDays) else {
            errorMessage = "dados inválidos"
            result = nil
            return
        }

        result = next
    }

    private func inputField(_ placeholder: String, text: Binding<String>, hasError: Bool) -> some View {
        TextField(placeholder, text: text)
            .font(TextStyle.bodyLarge)
            .keyboardType(.numbersAndPunctuation)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(hasError ? SemanticColor.errorBorder : AppSurface.border, lineWidth: 1)
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

    private func feedbackBanner(text: String, color: Color, background: Color, border: Color) -> some View {
        Text(text)
            .font(TextStyle.bodyMedium)
            .foregroundStyle(color)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}

private enum IGMode: String, CaseIterable {
    case dum
    case usg
}

#Preview {
    NavigationStack {
        IGCalculatorSheet(onInsert: { _ in }, onDismiss: {})
    }
}
