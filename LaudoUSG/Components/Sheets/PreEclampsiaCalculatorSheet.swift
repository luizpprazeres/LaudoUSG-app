import SwiftUI

@MainActor
struct PreEclampsiaCalculatorSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    private enum ModoIG: String, CaseIterable {
        case semanas = "Semanas + dias"
        case ccn = "Pelo CCN"
    }

    private enum ModoPressao: String, CaseIterable {
        case unica = "1 aferição"
        case protocolo = "4 aferições"
    }

    private enum ModoUterinas: String, CaseIterable {
        case media = "IP médio"
        case bilateral = "Direita + esquerda"
    }

    @State private var idade = ""
    @State private var peso = ""
    @State private var altura = ""
    @State private var modoIG = ModoIG.semanas
    @State private var semanas = 12
    @State private var dias = 0
    @State private var ccn = ""

    @State private var etnia = PreEclampsiaCalculator.Etnia.branca
    @State private var paridade = PreEclampsiaCalculator.Paridade.nulipara
    @State private var intervaloAnos = ""
    @State private var igPartoAnterior = ""
    @State private var zEscorePesoAnterior = ""

    @State private var historiaFamiliarPE = false
    @State private var fiv = false
    @State private var hipertensaoCronica = false
    @State private var diabetes = false
    @State private var lesSaf = false
    @State private var fumante = false

    @State private var modoPressao = ModoPressao.unica
    @State private var sistolicas = ["", "", "", ""]
    @State private var diastolicas = ["", "", "", ""]

    @State private var modoUterinas = ModoUterinas.media
    @State private var utaPiMedio = ""
    @State private var utaPiDireita = ""
    @State private var utaPiEsquerda = ""

    @State private var resultado: PreEclampsiaCalculator.Resultado?
    @State private var erro: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                introducao
                dadosMaternos
                historiaObstetrica
                pressaoArterial
                dopplerUterinas
                comorbidades
                momAoVivo
                calcularButton

                if let erro {
                    erroCard(erro)
                }
                if let resultado {
                    resultadoCard(resultado)
                    insertButton(resultado)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Pré-eclâmpsia (1T)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: fingerprint) { _, _ in
            resultado = nil
            erro = nil
        }
    }

    private var introducao: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Risco competitivo FMF", systemImage: "waveform.path.ecg")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(BrandColor.primaryDeep)
            Text("Feto único, de 11+0 a 13+6 semanas. Preencha história materna, pressão e Doppler; o resultado sai em 1 em N.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .cardStyle()
    }

    private var dadosMaternos: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Dados maternos")
            HStack(spacing: Spacing.sm) {
                numberField("Idade na DPP", placeholder: "30", text: $idade, keyboard: .decimalPad, suffix: "anos")
                numberField("Peso", placeholder: "69", text: $peso, keyboard: .decimalPad, suffix: "kg")
            }
            numberField("Altura", placeholder: "164", text: $altura, keyboard: .decimalPad, suffix: "cm")

            Picker("Etnia", selection: $etnia) {
                ForEach(PreEclampsiaCalculator.Etnia.allCases, id: \.self) {
                    Text($0.label).tag($0)
                }
            }
            .pickerStyle(.menu)

            Picker("Idade gestacional", selection: $modoIG) {
                ForEach(ModoIG.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if modoIG == .semanas {
                HStack(spacing: Spacing.sm) {
                    Picker("Semanas", selection: $semanas) {
                        ForEach(11...13, id: \.self) { Text("\($0) sem").tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("Dias", selection: $dias) {
                        ForEach(0...6, id: \.self) { Text("\($0) d").tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            } else {
                numberField("CCN", placeholder: "55", text: $ccn, keyboard: .decimalPad, suffix: "mm")
                if let gaCCN {
                    Text("IG calculada: \(formatarIG(gaCCN))")
                        .font(TextStyle.footnote)
                        .foregroundStyle(BrandColor.primaryDeep)
                }
            }
        }
        .cardStyle()
    }

    private var historiaObstetrica: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("História obstétrica")
            Picker("Paridade", selection: $paridade) {
                ForEach(PreEclampsiaCalculator.Paridade.allCases, id: \.self) {
                    Text($0.label).tag($0)
                }
            }
            .pickerStyle(.menu)

            if paridade != .nulipara {
                HStack(spacing: Spacing.sm) {
                    numberField(
                        "Intervalo",
                        placeholder: "3",
                        text: $intervaloAnos,
                        keyboard: .decimalPad,
                        suffix: "anos"
                    )
                    numberField(
                        "IG parto anterior",
                        placeholder: "39",
                        text: $igPartoAnterior,
                        keyboard: .decimalPad,
                        suffix: "sem"
                    )
                }
            }
            if paridade == .multiparaComPE {
                numberField(
                    "Z-score do peso ao nascer anterior",
                    placeholder: "0,0",
                    text: $zEscorePesoAnterior,
                    keyboard: .numbersAndPunctuation
                )
            }
        }
        .cardStyle()
    }

    private var pressaoArterial: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Pressão arterial")
            Picker("Aferições", selection: $modoPressao) {
                ForEach(ModoPressao.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            let quantidade = modoPressao == .unica ? 1 : 4
            ForEach(0..<quantidade, id: \.self) { indice in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if quantidade > 1 {
                        Text(rotuloAfericao(indice))
                            .font(TextStyle.captionMedium)
                            .foregroundStyle(AppSurface.textSecondary)
                    }
                    HStack(spacing: Spacing.sm) {
                        numberField("Sistólica", placeholder: "117", text: $sistolicas[indice], keyboard: .numberPad)
                        numberField("Diastólica", placeholder: "84", text: $diastolicas[indice], keyboard: .numberPad)
                    }
                }
            }

            if let pamAtual {
                HStack {
                    Text("PAM calculada")
                        .font(TextStyle.bodyMedium)
                        .foregroundStyle(AppSurface.textSecondary)
                    Spacer()
                    Text("\(formatar(pamAtual.pamMmHg, casas: 1)) mmHg")
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                }
            }
        }
        .cardStyle()
    }

    private var dopplerUterinas: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Artérias uterinas")
            Picker("Entrada", selection: $modoUterinas) {
                ForEach(ModoUterinas.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if modoUterinas == .media {
                numberField("IP médio", placeholder: "1,73", text: $utaPiMedio, keyboard: .decimalPad)
            } else {
                HStack(spacing: Spacing.sm) {
                    numberField("IP direita", placeholder: "1,73", text: $utaPiDireita, keyboard: .decimalPad)
                    numberField("IP esquerda", placeholder: "1,73", text: $utaPiEsquerda, keyboard: .decimalPad)
                }
                if let media = utaAtual {
                    Text("IP médio: \(formatar(media, casas: 2))")
                        .font(TextStyle.footnote)
                        .foregroundStyle(BrandColor.primaryDeep)
                }
            }
            Text("Média direita + esquerda, técnica transabdominal.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
        .cardStyle()
    }

    private var comorbidades: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionTitle("Condições maternas")
            riskToggle("Mãe teve pré-eclâmpsia", isOn: $historiaFamiliarPE)
            riskToggle("Concepção por FIV", isOn: $fiv)
            riskToggle("Hipertensão crônica", isOn: $hipertensaoCronica)
            riskToggle("Diabetes tipo 1 ou 2", isOn: $diabetes)
            riskToggle("LES ou SAF", isOn: $lesSaf)
            riskToggle("Tabagismo", isOn: $fumante)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var momAoVivo: some View {
        if let entrada = try? montarEntrada() {
            let momPam = PreEclampsiaCalculator.mapMoM(entrada.pam.pamMmHg, entrada.gestante)
            let momUta = PreEclampsiaCalculator.utaPiMoM(entrada.utaPi, entrada.gestante)
            HStack(spacing: Spacing.sm) {
                momChip("PAM", valor: momPam)
                momChip("Uterinas", valor: momUta)
            }
        }
    }

    private var calcularButton: some View {
        PrimaryButton(title: "Calcular risco", icon: "function") {
            calcular()
        }
    }

    private func resultadoCard(_ resultado: PreEclampsiaCalculator.Resultado) -> some View {
        let risco37 = resultado.riscos[37] ?? 0
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("RISCO ANTES DE 37 SEMANAS")
                        .font(TextStyle.captionMedium)
                        .foregroundStyle(AppSurface.textSecondary)
                    Text("1 em \(formatarInteiro(resultado.umEmN))")
                        .font(TextStyle.h1)
                        .foregroundStyle(resultado.altoRisco ? SemanticColor.warningText : SemanticColor.successText)
                    Text(formatarPercentual(risco37))
                        .font(TextStyle.footnote)
                        .foregroundStyle(AppSurface.textSecondary)
                }
                Spacer()
                Label(
                    resultado.altoRisco ? "Atingiu 1:100" : "Abaixo de 1:100",
                    systemImage: resultado.altoRisco ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                )
                .font(TextStyle.captionMedium)
                .foregroundStyle(resultado.altoRisco ? SemanticColor.warningText : SemanticColor.successText)
            }

            Divider()

            HStack {
                riscoSecundario("< 34 sem", valor: resultado.riscos[34] ?? 0)
                Spacer()
                riscoSecundario("< 32 sem", valor: resultado.riscos[32] ?? 0)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(resultado.altoRisco ? SemanticColor.warningBg : SemanticColor.successBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(resultado.altoRisco ? SemanticColor.warningBorder : SemanticColor.successBorder, lineWidth: 1)
        )
    }

    private func insertButton(_ resultado: PreEclampsiaCalculator.Resultado) -> some View {
        PrimaryButton(title: "Inserir no laudo", icon: "plus.circle.fill") {
            Haptics.success()
            onInsert("\n" + resultado.insertBloco + "\n")
            onDismiss()
        }
    }

    private func erroCard(_ mensagem: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "xmark.octagon.fill")
            Text(mensagem).font(TextStyle.body)
            Spacer(minLength: 0)
            Button {
                erro = nil
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
            resultado = try PreEclampsiaCalculator.calcular(
                entrada.gestante,
                medidas: .init(
                    pamMmHg: entrada.pam.pamMmHg,
                    utaPiMedio: entrada.utaPi,
                    afericoesPam: entrada.pam.afericoes
                )
            )
            erro = nil
            Haptics.success()
        } catch let dominio as PeErroDeDominio {
            resultado = nil
            erro = dominio.mensagem
            Haptics.warning()
        } catch {
            resultado = nil
            erro = "Não foi possível calcular. Revise os campos preenchidos."
            Haptics.warning()
        }
    }

    private struct EntradaMontada {
        let gestante: PreEclampsiaCalculator.Gestante
        let pam: PreEclampsiaCalculator.Pam
        let utaPi: Double
    }

    private func montarEntrada() throws -> EntradaMontada {
        guard let idade = decimal(idade), let peso = decimal(peso), let altura = decimal(altura) else {
            throw PeErroDeDominio("preencha idade, peso e altura")
        }

        let gaDias: Double
        if modoIG == .ccn {
            guard let valorCCN = decimal(ccn) else {
                throw PeErroDeDominio("preencha o CCN em milímetros")
            }
            gaDias = try PreEclampsiaCalculator.gaDiasPorCCN(valorCCN)
        } else {
            gaDias = Double(semanas * 7 + dias)
        }

        let intervalo = decimal(intervaloAnos)
        let igAnterior = decimal(igPartoAnterior)
        let zScore = decimal(zEscorePesoAnterior)
        if paridade != .nulipara {
            guard intervalo != nil else {
                throw PeErroDeDominio("multípara exige o intervalo entre gestações em anos")
            }
            guard igAnterior != nil else {
                throw PeErroDeDominio("multípara exige a IG do parto anterior")
            }
        }
        if paridade == .multiparaComPE, zScore == nil {
            throw PeErroDeDominio("multípara com PE anterior exige o Z-score do peso ao nascer anterior")
        }

        let quantidade = modoPressao == .unica ? 1 : 4
        var afericoes: [PreEclampsiaCalculator.Afericao] = []
        for indice in 0..<quantidade {
            guard let sistolica = decimal(sistolicas[indice]),
                  let diastolica = decimal(diastolicas[indice]) else {
                throw PeErroDeDominio(
                    quantidade == 1
                        ? "preencha a pressão sistólica e diastólica"
                        : "preencha as quatro aferições de pressão"
                )
            }
            afericoes.append(.init(sistolica: sistolica, diastolica: diastolica))
        }
        let pam = try PreEclampsiaCalculator.pamDeAfericoes(afericoes)

        guard let utaPi = utaAtual else {
            throw PeErroDeDominio(
                modoUterinas == .media
                    ? "preencha o IP médio das artérias uterinas"
                    : "preencha os IPs das artérias uterinas direita e esquerda"
            )
        }

        let gestante = PreEclampsiaCalculator.Gestante(
            idade: idade,
            peso: peso,
            altura: altura,
            gaDias: gaDias,
            etnia: etnia,
            paridade: paridade,
            intervaloAnos: intervalo,
            igPartoAnterior: igAnterior,
            zEscorePesoAnterior: zScore,
            histFamiliarPE: historiaFamiliarPE,
            fiv: fiv,
            hipertensaoCronica: hipertensaoCronica,
            diabetes: diabetes,
            lesSaf: lesSaf,
            fumante: fumante
        )
        return EntradaMontada(gestante: gestante, pam: pam, utaPi: utaPi)
    }

    private var pamAtual: PreEclampsiaCalculator.Pam? {
        let quantidade = modoPressao == .unica ? 1 : 4
        let afericoes = (0..<quantidade).compactMap { indice -> PreEclampsiaCalculator.Afericao? in
            guard let sistolica = decimal(sistolicas[indice]),
                  let diastolica = decimal(diastolicas[indice]) else { return nil }
            return .init(sistolica: sistolica, diastolica: diastolica)
        }
        guard afericoes.count == quantidade else { return nil }
        return try? PreEclampsiaCalculator.pamDeAfericoes(afericoes)
    }

    private var utaAtual: Double? {
        if modoUterinas == .media {
            return decimal(utaPiMedio)
        }
        guard let direita = decimal(utaPiDireita), let esquerda = decimal(utaPiEsquerda) else {
            return nil
        }
        return (direita + esquerda) / 2
    }

    private var gaCCN: Double? {
        guard let ccn = decimal(ccn) else { return nil }
        return try? PreEclampsiaCalculator.gaDiasPorCCN(ccn)
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

    private func momChip(_ titulo: String, valor: Double) -> some View {
        HStack {
            Text(titulo).font(TextStyle.bodyMedium)
            Spacer()
            Text("\(formatar(valor, casas: 2)) MoM")
                .font(TextStyle.bodyLargeSemibold)
        }
        .foregroundStyle(AppSurface.textPrimary)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Radius.xl).fill(BrandColor.primaryTint))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(BrandColor.primaryBorder, lineWidth: 1))
    }

    private func riscoSecundario(_ titulo: String, valor: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(titulo).font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            Text(formatarPercentual(valor)).font(TextStyle.bodyLargeSemibold).foregroundStyle(AppSurface.textPrimary)
        }
    }

    private func rotuloAfericao(_ indice: Int) -> String {
        ["Direita · 1ª", "Esquerda · 1ª", "Direita · 2ª", "Esquerda · 2ª"][indice]
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
        let semanas = Int(floor(gaDias / 7))
        let dias = gaDias.truncatingRemainder(dividingBy: 7)
        return "\(semanas) sem + \(formatar(dias, casas: 1)) d"
    }

    private func formatarInteiro(_ valor: Double) -> String {
        valor.formatted(.number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(0)))
    }

    private func formatarPercentual(_ valor: Double) -> String {
        (valor * 100).formatted(
            .number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(2))
        ) + "%"
    }

    private var fingerprint: String {
        [
            idade, peso, altura, modoIG.rawValue, String(semanas), String(dias), ccn,
            etnia.rawValue, paridade.rawValue, intervaloAnos, igPartoAnterior,
            zEscorePesoAnterior, String(historiaFamiliarPE), String(fiv),
            String(hipertensaoCronica), String(diabetes), String(lesSaf), String(fumante),
            modoPressao.rawValue, sistolicas.joined(separator: "|"), diastolicas.joined(separator: "|"),
            modoUterinas.rawValue, utaPiMedio, utaPiDireita, utaPiEsquerda,
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
