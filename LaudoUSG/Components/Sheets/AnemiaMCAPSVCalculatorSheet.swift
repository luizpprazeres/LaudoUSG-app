import SwiftUI

@MainActor
struct AnemiaMCAPSVCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var igWeeks: Int = 28
    @State private var igDays: Int = 0
    @State private var psvText: String = ""

    private var result: AnemiaMCAPSVCalculator.AnemiaResult? {
        guard let psv = decimal(psvText) else { return nil }
        return AnemiaMCAPSVCalculator.calculate(.init(
            igWeeks: igWeeks, igDays: igDays, psvCmSec: psv
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                description
                igPicker
                psvInput
                if let result {
                    resultCard(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Anemia fetal (MCA-PSV)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Risco de anemia fetal pela velocidade de pico sistólico da artéria cerebral média (Mari, 2000).")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            Text("Validado pra IG entre 18 e 40 semanas.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
    }

    private var igPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Idade gestacional")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
            HStack(spacing: Spacing.sm) {
                Picker("Semanas", selection: $igWeeks) {
                    ForEach(18...40, id: \.self) { Text("\($0) sem").tag($0) }
                }
                Picker("Dias", selection: $igDays) {
                    ForEach(0...6, id: \.self) { Text("\($0) d").tag($0) }
                }
            }
        }
    }

    private var psvInput: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("MCA-PSV (pico sistólico)")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
            TextField("ex: 55 cm/s", text: $psvText)
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

    private func resultCard(_ r: AnemiaMCAPSVCalculator.AnemiaResult) -> some View {
        let isAbnormal = r.severity != .normal
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.2f MoM", r.mom).replacingOccurrences(of: ".", with: ","))
                    .font(TextStyle.h2)
                    .foregroundStyle(BrandColor.primaryDeep)
                Text("PSV \(String(format: "%.1f", r.psv).replacingOccurrences(of: ".", with: ",")) cm/s")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
            }
            Text("Mediana esperada: \(String(format: "%.1f", r.medianExpected).replacingOccurrences(of: ".", with: ",")) cm/s")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
            Text(r.severity.label)
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

    private func insertButton(_ r: AnemiaMCAPSVCalculator.AnemiaResult) -> some View {
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
