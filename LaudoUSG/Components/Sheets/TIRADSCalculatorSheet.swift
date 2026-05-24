import SwiftUI

@MainActor
struct TIRADSCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var composicao: TIRADSCalculator.Composicao = .solido
    @State private var ecogenicidade: TIRADSCalculator.Ecogenicidade = .hipo
    @State private var forma: TIRADSCalculator.Forma = .maisLarga
    @State private var margem: TIRADSCalculator.Margem = .lisaIndefinida
    @State private var focos: TIRADSCalculator.FocosEcogenicos = .nenhum
    @State private var tamanhoText: String = ""

    private var result: TIRADSCalculator.TIRADSResult? {
        guard let tam = Double(tamanhoText.replacingOccurrences(of: ",", with: ".")), tam > 0 else { return nil }
        return TIRADSCalculator.calculate(.init(
            composicao: composicao,
            ecogenicidade: ecogenicidade,
            forma: forma,
            margem: margem,
            focosEcogenicos: focos,
            maiorEixoCm: tam
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Pontuação ACR TI-RADS por 5 features do nódulo. Determina recomendação de PAAF ou seguimento por tamanho.")
                    .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
                pickerRow("Composição", selection: $composicao, options: TIRADSCalculator.Composicao.allCases, label: { $0.rawValue })
                pickerRow("Ecogenicidade", selection: $ecogenicidade, options: TIRADSCalculator.Ecogenicidade.allCases, label: { $0.rawValue })
                pickerRow("Forma", selection: $forma, options: TIRADSCalculator.Forma.allCases, label: { $0.rawValue })
                pickerRow("Margem", selection: $margem, options: TIRADSCalculator.Margem.allCases, label: { $0.rawValue })
                pickerRow("Focos ecogênicos", selection: $focos, options: TIRADSCalculator.FocosEcogenicos.allCases, label: { $0.rawValue })
                sizeInput
                if let result {
                    card(result)
                    insertButton(result)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("TI-RADS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pickerRow<T: Hashable & Identifiable>(_ titleText: String, selection: Binding<T>, options: [T], label: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(titleText).font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            Picker(titleText, selection: selection) {
                ForEach(options) { opt in
                    Text(label(opt)).tag(opt)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var sizeInput: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Maior eixo do nódulo (cm)").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary)
            TextField("ex: 1,8", text: $tamanhoText)
                .keyboardType(.decimalPad)
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
    }

    private func card(_ r: TIRADSCalculator.TIRADSResult) -> some View {
        let isSerious = r.categoria == .tr4 || r.categoria == .tr5
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(r.categoria.label)
                .font(TextStyle.h2)
                .foregroundStyle(isSerious ? SemanticColor.warningText : BrandColor.primaryDeep)
            Text("\(r.pontos) pontos no total")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
            Text(r.recomendacao)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
    }

    private func insertButton(_ r: TIRADSCalculator.TIRADSResult) -> some View {
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
