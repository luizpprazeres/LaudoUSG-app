import SwiftUI

@MainActor
struct VolumeUterinoCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var width: String = ""
    @State private var height: String = ""
    @State private var length: String = ""
    @State private var status: VolumeUterinoCalculator.HormonalStatus = .nulipara

    private var result: VolumeUterinoCalculator.VUResult? {
        guard let w = decimal(width), let h = decimal(height), let l = decimal(length) else { return nil }
        return VolumeUterinoCalculator.calculate(.init(
            widthCm: w, heightCm: h, lengthCm: l, status: status
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Volume uterino pela fórmula do elipsoide. Referências de normalidade variam por status hormonal e paridade.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                statusPicker
                dimsGroup
                if let result {
                    card(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Volume uterino")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Status hormonal").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            Picker("Status", selection: $status) {
                ForEach(VolumeUterinoCalculator.HormonalStatus.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var dimsGroup: some View {
        HStack(spacing: Spacing.sm) {
            field("Comprimento (cm)", text: $length)
            field("AP (cm)", text: $height)
            field("Largura (cm)", text: $width)
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

    private func card(_ r: VolumeUterinoCalculator.VUResult) -> some View {
        let abnormal = r.classification != .normal
        let volFmt = String(format: "%.1f", r.volumeCc).replacingOccurrences(of: ".", with: ",")
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(volFmt) mL")
                .font(TextStyle.h2)
                .foregroundStyle(BrandColor.primaryDeep)
            Text(r.conclusao)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(abnormal ? SemanticColor.warningText : AppSurface.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }

    private func insertButton(_ r: VolumeUterinoCalculator.VUResult) -> some View {
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
}
