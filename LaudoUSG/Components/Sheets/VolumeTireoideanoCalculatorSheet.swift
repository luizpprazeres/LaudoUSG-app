import SwiftUI

@MainActor
struct VolumeTireoideanoCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var sex: VolumeTireoideanoCalculator.Sex = .feminino
    @State private var dW: String = ""
    @State private var dH: String = ""
    @State private var dL: String = ""
    @State private var eW: String = ""
    @State private var eH: String = ""
    @State private var eL: String = ""

    private var result: VolumeTireoideanoCalculator.VTResult? {
        let direito = VolumeTireoideanoCalculator.LobeInput(
            widthCm: decimal(dW) ?? 0,
            heightCm: decimal(dH) ?? 0,
            lengthCm: decimal(dL) ?? 0
        )
        let esquerdo = VolumeTireoideanoCalculator.LobeInput(
            widthCm: decimal(eW) ?? 0,
            heightCm: decimal(eH) ?? 0,
            lengthCm: decimal(eL) ?? 0
        )
        return VolumeTireoideanoCalculator.calculate(.init(
            sex: sex, direito: direito, esquerdo: esquerdo
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Volume tireoideano pela soma dos lobos (fórmula do elipsoide). Istmo geralmente não é incluído.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                sexPicker
                lobeGroup("Lobo direito", w: $dW, h: $dH, l: $dL)
                lobeGroup("Lobo esquerdo", w: $eW, h: $eH, l: $eL)
                if let result {
                    card(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Volume tireoideano")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sexPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Sexo").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            Picker("Sexo", selection: $sex) {
                ForEach(VolumeTireoideanoCalculator.Sex.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func lobeGroup(_ title: String, w: Binding<String>, h: Binding<String>, l: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary).textCase(.uppercase)
            HStack(spacing: Spacing.sm) {
                field("Largura (cm)", text: w)
                field("AP (cm)", text: h)
                field("Comprimento (cm)", text: l)
            }
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

    private func card(_ r: VolumeTireoideanoCalculator.VTResult) -> some View {
        let abnormal = r.classification != .normal
        let totalFmt = String(format: "%.1f", r.volumeTotal).replacingOccurrences(of: ".", with: ",")
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(totalFmt) mL")
                .font(TextStyle.h2)
                .foregroundStyle(BrandColor.primaryDeep)
            Text(r.classification.label)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(abnormal ? SemanticColor.warningText : AppSurface.textPrimary)
            Text("Direito: \(fmt(r.volumeDireito)) mL · Esquerdo: \(fmt(r.volumeEsquerdo)) mL")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }

    private func insertButton(_ r: VolumeTireoideanoCalculator.VTResult) -> some View {
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

    private func fmt(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}
