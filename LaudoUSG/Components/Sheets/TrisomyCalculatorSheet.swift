import SwiftUI

/// Preenchimento e resultado da calculadora. Vive no modelo da tela de geração para que o usuário
/// possa fechar a sheet, gerar o laudo e voltar para inserir sem perder o que digitou.
@MainActor
@Observable
final class TrisomyCalculatorState {
    enum OssoNasal: String, CaseIterable {
        case naoAvaliado = "Não avaliado"
        case presente = "Presente"
        case ausente = "Ausente"

        var valor: Bool? {
            switch self {
            case .naoAvaliado: nil
            case .presente: false
            case .ausente: true
            }
        }
    }

    enum Tricuspide: String, CaseIterable {
        case naoAvaliada = "Não avaliada"
        case normal = "Normal"
        case regurgitacao = "Regurgitação"

        var valor: Bool? {
            switch self {
            case .naoAvaliada: nil
            case .normal: false
            case .regurgitacao: true
            }
        }
    }

    var dataNascimento: Date = {
        Calendar(identifier: .gregorian).date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }()
    var exameEmOutraData = false
    var dataExame = Date()

    var ccn = ""
    var tn = ""
    var fcf = ""
    var usarIGDatada = false
    var semanasDatada = 12
    var diasDatada = 0

    var etnia = TrisomyCalculator.Etnia.branca
    var peso = ""
    var fumante = false
    var previaT21 = false
    var previaT18 = false
    var previaT13 = false

    var ossoNasal = OssoNasal.naoAvaliado
    var tricuspide = Tricuspide.naoAvaliada
    var dvPI = ""

    var pappa = ""
    var freeBeta = ""
    var momCorrigido = false

    var resultado: TrisomyCalculator.Resultado?
    var erro: String?

    init() {}
}

@MainActor
struct TrisomyCalculatorSheet: View {
    @Bindable var state: TrisomyCalculatorState
    /// Só é possível inserir depois que existe um laudo gerado (o texto vai para a aba Laudo).
    var canInsert: Bool = true
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    private typealias OssoNasal = TrisomyCalculatorState.OssoNasal
    private typealias Tricuspide = TrisomyCalculatorState.Tricuspide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                introducao
                dadosMaternos
                biometria
                marcadoresUltrassom
                bioquimica
                calcularButton

                if let erro = state.erro {
                    erroCard(erro)
                }
                if let resultado = state.resultado {
                    resultadoCard(resultado)
                    detalhesCard(resultado)
                    insertButton(resultado)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Trissomias (1T)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: fingerprint) { _, _ in
            state.resultado = nil
            state.erro = nil
        }
    }

    private var introducao: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Rastreio combinado FMF", systemImage: "staroflife")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(BrandColor.primaryDeep)
            Text("Feto único, CCN de 45 a 84 mm. Idade materna e TN são obrigatórias; FCF, osso nasal, tricúspide, ducto venoso e bioquímica refinam o risco.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .cardStyle()
    }

    private var dadosMaternos: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Dados maternos")
            dataNascimentoField

            riskToggle("Exame em outra data", isOn: $state.exameEmOutraData)
            if state.exameEmOutraData {
                dateField("Data do exame", selection: $state.dataExame, in: Self.faixaExame)
            }

            Picker("Etnia", selection: $state.etnia) {
                ForEach(TrisomyCalculator.Etnia.allCases, id: \.self) {
                    Text($0.label).tag($0)
                }
            }
            .pickerStyle(.menu)

            numberField("Peso", placeholder: "69", text: $state.peso, keyboard: .decimalPad, suffix: "kg")
            Text("Opcional; obrigatório se a tricúspide for avaliada.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)

            riskToggle("Tabagismo", isOn: $state.fumante)
            riskToggle("Gestação prévia com trissomia 21", isOn: $state.previaT21)
            riskToggle("Gestação prévia com trissomia 18", isOn: $state.previaT18)
            riskToggle("Gestação prévia com trissomia 13", isOn: $state.previaT13)
        }
        .cardStyle()
    }

    private var biometria: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Biometria fetal")
            HStack(spacing: Spacing.sm) {
                numberField("CCN", placeholder: "60", text: $state.ccn, keyboard: .decimalPad, suffix: "mm")
                numberField("TN", placeholder: "1,8", text: $state.tn, keyboard: .decimalPad, suffix: "mm")
            }
            if let gaCCN {
                Text("IG pelo CCN: \(formatarIG(gaCCN))")
                    .font(TextStyle.footnote)
                    .foregroundStyle(BrandColor.primaryDeep)
            }
            numberField("FCF", placeholder: "160", text: $state.fcf, keyboard: .numberPad, suffix: "bpm")

            riskToggle("Usar IG datada (DUM / datação prévia)", isOn: $state.usarIGDatada)
            if state.usarIGDatada {
                HStack(spacing: Spacing.sm) {
                    Picker("Semanas", selection: $state.semanasDatada) {
                        ForEach(10...14, id: \.self) { Text("\($0) sem").tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("Dias", selection: $state.diasDatada) {
                        ForEach(0...6, id: \.self) { Text("\($0) d").tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Text("A IG datada é usada na FCF esperada e na bioquímica; risco basal e TN seguem o CCN.")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
            }
        }
        .cardStyle()
    }

    private var marcadoresUltrassom: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Marcadores adicionais")
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Osso nasal").font(TextStyle.body)
                Picker("Osso nasal", selection: $state.ossoNasal) {
                    ForEach(OssoNasal.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Fluxo tricúspide").font(TextStyle.body)
                Picker("Fluxo tricúspide", selection: $state.tricuspide) {
                    ForEach(Tricuspide.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if state.tricuspide != .naoAvaliada, decimal(state.peso) == nil {
                    Text("Informe o state.peso materno para usar o marcador tricúspide.")
                        .font(TextStyle.caption)
                        .foregroundStyle(SemanticColor.warningText)
                }
            }
            numberField("IP do ducto venoso", placeholder: "1,05", text: $state.dvPI, keyboard: .decimalPad)
        }
        .cardStyle()
    }

    private var bioquimica: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Bioquímica")
            HStack(spacing: Spacing.sm) {
                numberField("PAPP-A", placeholder: "1,00", text: $state.pappa, keyboard: .decimalPad, suffix: "MoM")
                numberField("Free β-hCG", placeholder: "1,00", text: $state.freeBeta, keyboard: .decimalPad, suffix: "MoM")
            }
            riskToggle("MoM corrigido pelo laboratório", isOn: $state.momCorrigido)
            Text("Informe os MoM já corrigidos (state.peso, state.etnia, tabagismo, método). Obrigatório confirmar para usar a bioquímica.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
        .cardStyle()
    }

    private var dataNascimentoField: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            dateField("Data de nascimento", selection: $state.dataNascimento, in: Self.faixaNascimento)
            Text("\(formatar(idadeNaDataDoExame, casas: 1)) anos na data do exame")
                .font(TextStyle.footnote)
                .foregroundStyle(BrandColor.primaryDeep)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateField(_ titulo: String, selection: Binding<Date>, in faixa: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(titulo)
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
            DatePicker(titulo, selection: selection, in: faixa, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.muted))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(AppSurface.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calcularButton: some View {
        PrimaryButton(title: "Calcular risco", icon: "function") {
            calcular()
        }
    }

    private func resultadoCard(_ resultado: TrisomyCalculator.Resultado) -> some View {
        let categoria = resultado.t21.category
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("TRISSOMIA 21")
                        .font(TextStyle.captionMedium)
                        .foregroundStyle(AppSurface.textSecondary)
                    Text(resultado.t21.texto)
                        .font(TextStyle.h1)
                        .foregroundStyle(corTexto(categoria))
                    Text(formatarPercentual(resultado.t21.probability))
                        .font(TextStyle.footnote)
                        .foregroundStyle(AppSurface.textSecondary)
                }
                Spacer()
                Label(categoria.label, systemImage: icone(categoria))
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(corTexto(categoria))
            }

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("TRISSOMIAS 13/18")
                        .font(TextStyle.captionMedium)
                        .foregroundStyle(AppSurface.textSecondary)
                    Text(resultado.t18t13.texto)
                        .font(TextStyle.h2)
                        .foregroundStyle(corTexto(resultado.t18t13.category))
                    Text(formatarPercentual(resultado.t18t13.probability))
                        .font(TextStyle.footnote)
                        .foregroundStyle(AppSurface.textSecondary)
                }
                Spacer()
                Label(resultado.t18t13.category.label, systemImage: icone(resultado.t18t13.category))
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(corTexto(resultado.t18t13.category))
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(corFundo(categoria))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(corBorda(categoria), lineWidth: 1)
        )
    }

    private func detalhesCard(_ resultado: TrisomyCalculator.Resultado) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Risco basal (idade + IG)")
            HStack {
                riscoSecundario("T21", texto: resultado.basal.t21.texto)
                Spacer()
                riscoSecundario("T18", texto: resultado.basal.t18.texto)
                Spacer()
                riscoSecundario("T13", texto: resultado.basal.t13.texto)
            }

            Divider()

            sectionTitle("Marcadores usados")
            Text(resultado.markersUsed.joined(separator: " · "))
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)
            if !resultado.markersMissing.isEmpty {
                Text("Não informados: \(resultado.markersMissing.joined(separator: ", "))")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
            }

            if !resultado.warnings.isEmpty {
                Divider()
                sectionTitle("Avisos")
                ForEach(resultado.warnings, id: \.self) { aviso in
                    Label(aviso, systemImage: "exclamationmark.triangle")
                        .font(TextStyle.footnote)
                        .foregroundStyle(SemanticColor.warningText)
                }
            }

            Text("IG pelo CCN: \(resultado.gaWeeks) sem + \(resultado.gaDaysRemainder) d · \(resultado.versaoParametros)")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
        .cardStyle()
    }

    private func insertButton(_ resultado: TrisomyCalculator.Resultado) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            PrimaryButton(title: "Inserir no laudo", icon: "plus.circle.fill") {
                Haptics.success()
                onInsert("\n" + resultado.insertBloco + "\n")
                onDismiss()
            }
            .disabled(!canInsert)
            .opacity(canInsert ? 1 : 0.5)
            if !canInsert {
                Text("Gere o laudo primeiro. O preenchimento fica guardado: volte aqui depois e toque em Inserir para levar o resultado à aba Laudo.")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
            }
        }
    }

    private func erroCard(_ mensagem: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "xmark.octagon.fill")
            Text(mensagem).font(TextStyle.body)
            Spacer(minLength: 0)
            Button {
                state.erro = nil
            } label: {
                Image(systemName: "xmark")
            }
        }
        .foregroundStyle(SemanticColor.errorText)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(SemanticColor.errorBg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(SemanticColor.errorBorder, lineWidth: 1))
    }

    private func calcular() {
        do {
            let entrada = try montarEntrada()
            state.resultado = try TrisomyCalculator.calcular(entrada)
            state.erro = nil
            Haptics.success()
        } catch let dominio as TrisomyErroDeDominio {
            state.resultado = nil
            state.erro = dominio.mensagem
            Haptics.warning()
        } catch {
            state.resultado = nil
            state.erro = "Não foi possível calcular. Revise os campos preenchidos."
            Haptics.warning()
        }
    }

    private func montarEntrada() throws -> TrisomyCalculator.Entrada {
        guard let crl = decimal(state.ccn) else {
            throw TrisomyErroDeDominio("preencha o CCN em milímetros")
        }
        guard let nt = decimal(state.tn) else {
            throw TrisomyErroDeDominio("preencha a translucência nucal em milímetros")
        }

        let pappaValor = decimal(state.pappa)
        let freeBetaValor = decimal(state.freeBeta)
        if (pappaValor != nil || freeBetaValor != nil), !state.momCorrigido {
            throw TrisomyErroDeDominio("A bioquímica deve ser informada como MoM já corrigido pelo laboratório.")
        }

        return TrisomyCalculator.Entrada(
            maternalAge: idadeNaDataDoExame,
            crl: crl,
            nt: nt,
            fhr: decimal(state.fcf),
            gaDaysDated: state.usarIGDatada ? Double(state.semanasDatada * 7 + state.diasDatada) : nil,
            freeBetaHcgMoM: freeBetaValor,
            pappaMoM: pappaValor,
            isMoMCorrected: state.momCorrigido,
            dvPI: decimal(state.dvPI),
            tricuspidRegurgitation: state.tricuspide.valor,
            nasalBoneAbsent: state.ossoNasal.valor,
            smoking: state.fumante,
            ethnicity: state.etnia,
            weight: decimal(state.peso),
            previousT21: state.previaT21,
            previousT18: state.previaT18,
            previousT13: state.previaT13
        )
    }

    private var dataExameEfetiva: Date {
        state.exameEmOutraData ? state.dataExame : Date()
    }

    private var idadeNaDataDoExame: Double {
        dataExameEfetiva.timeIntervalSince(state.dataNascimento) / 86_400 / 365.25
    }

    private var gaCCN: Double? {
        guard let crl = decimal(state.ccn), TrisomyCalculator.faixaCrl.contains(crl) else { return nil }
        return TrisomyCalculator.crlParaGaDias(crl)
    }

    private static var faixaNascimento: ClosedRange<Date> {
        let hoje = Date()
        let calendar = Calendar(identifier: .gregorian)
        let minima = calendar.date(byAdding: .year, value: -70, to: hoje) ?? hoje
        let maxima = calendar.date(byAdding: .year, value: -8, to: hoje) ?? hoje
        return minima...maxima
    }

    private static var faixaExame: ClosedRange<Date> {
        let hoje = Date()
        let calendar = Calendar(identifier: .gregorian)
        let minima = calendar.date(byAdding: .year, value: -1, to: hoje) ?? hoje
        return minima...hoje
    }

    private func corTexto(_ categoria: TrisomyCalculator.Categoria) -> Color {
        switch categoria {
        case .alto: SemanticColor.errorText
        case .intermediario: SemanticColor.warningText
        case .baixo: SemanticColor.successText
        }
    }

    private func corFundo(_ categoria: TrisomyCalculator.Categoria) -> Color {
        switch categoria {
        case .alto: SemanticColor.errorBg
        case .intermediario: SemanticColor.warningBg
        case .baixo: SemanticColor.successBg
        }
    }

    private func corBorda(_ categoria: TrisomyCalculator.Categoria) -> Color {
        switch categoria {
        case .alto: SemanticColor.errorBorder
        case .intermediario: SemanticColor.warningBorder
        case .baixo: SemanticColor.successBorder
        }
    }

    private func icone(_ categoria: TrisomyCalculator.Categoria) -> String {
        switch categoria {
        case .alto: "exclamationmark.triangle.fill"
        case .intermediario: "exclamationmark.circle.fill"
        case .baixo: "checkmark.circle.fill"
        }
    }

    private func numberField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
            HStack(spacing: Spacing.xs) {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                if let suffix {
                    Text(suffix)
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                }
            }
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.muted))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(AppSurface.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func riskToggle(_ titulo: String, isOn: Binding<Bool>) -> some View {
        Toggle(titulo, isOn: isOn)
            .font(TextStyle.body)
            .tint(BrandColor.primary)
    }

    private func sectionTitle(_ titulo: String) -> some View {
        Text(titulo.uppercased())
            .font(TextStyle.captionMedium)
            .foregroundStyle(AppSurface.textSecondary)
    }

    private func riscoSecundario(_ titulo: String, texto: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(titulo).font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            Text(texto).font(TextStyle.bodyLargeSemibold).foregroundStyle(AppSurface.textPrimary)
        }
    }

    private func decimal(_ texto: String) -> Double? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return nil }
        return Double(limpo.replacingOccurrences(of: ",", with: "."))
    }

    private func formatar(_ valor: Double, casas: Int) -> String {
        String(format: "%.*f", locale: Locale(identifier: "pt_BR"), casas, valor)
    }

    private func formatarIG(_ gaDias: Double) -> String {
        let arredondado = floor(gaDias + 0.5)
        let semanas = Int(floor(arredondado / 7))
        let dias = Int(arredondado.truncatingRemainder(dividingBy: 7))
        return "\(semanas) sem + \(dias) d"
    }

    private func formatarPercentual(_ valor: Double) -> String {
        (valor * 100).formatted(
            .number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(2))
        ) + "%"
    }

    private var fingerprint: String {
        [
            String(state.dataNascimento.timeIntervalSince1970), String(state.exameEmOutraData),
            String(state.dataExame.timeIntervalSince1970),
            state.ccn, state.tn, state.fcf, String(state.usarIGDatada), String(state.semanasDatada), String(state.diasDatada),
            state.etnia.rawValue, state.peso, String(state.fumante), String(state.previaT21), String(state.previaT18), String(state.previaT13),
            state.ossoNasal.rawValue, state.tricuspide.rawValue, state.dvPI,
            state.pappa, state.freeBeta, String(state.momCorrigido),
        ].joined(separator: "§")
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        TrisomyCalculatorSheet(state: TrisomyCalculatorState(), canInsert: false, onInsert: { _ in }, onDismiss: {})
    }
}
