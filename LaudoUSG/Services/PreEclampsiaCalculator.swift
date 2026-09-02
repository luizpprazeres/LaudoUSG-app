import Foundation

struct PeErroDeDominio: LocalizedError, Equatable, Sendable {
    let mensagem: String

    init(_ mensagem: String) {
        self.mensagem = mensagem
    }

    var errorDescription: String? { mensagem }
}

enum PreEclampsiaCalculator {
    enum Etnia: String, CaseIterable, Codable, Sendable {
        case branca
        case afro
        case sulAsiatica = "sul-asiatica"
        case lesteAsiatica = "leste-asiatica"

        var label: String {
            switch self {
            case .branca: "Branca"
            case .afro: "Negra / afro-caribenha"
            case .sulAsiatica: "Sul-asiática"
            case .lesteAsiatica: "Leste-asiática"
            }
        }
    }

    enum Paridade: String, CaseIterable, Codable, Sendable {
        case nulipara
        case multiparaSemPE = "multipara-sem-pe"
        case multiparaComPE = "multipara-com-pe"

        var label: String {
            switch self {
            case .nulipara: "Nulípara"
            case .multiparaSemPE: "Multípara, sem PE anterior"
            case .multiparaComPE: "Multípara, com PE anterior"
            }
        }
    }

    struct Gestante: Sendable {
        let idade: Double
        let peso: Double
        let altura: Double
        let gaDias: Double
        let etnia: Etnia
        let paridade: Paridade
        let intervaloAnos: Double?
        let igPartoAnterior: Double?
        let zEscorePesoAnterior: Double?
        let histFamiliarPE: Bool
        let fiv: Bool
        let hipertensaoCronica: Bool
        let diabetes: Bool
        let lesSaf: Bool
        let fumante: Bool
    }

    struct Medidas: Sendable {
        let pamMmHg: Double?
        let utaPiMedio: Double?
        let afericoesPam: Int?

        init(pamMmHg: Double? = nil, utaPiMedio: Double? = nil, afericoesPam: Int? = nil) {
            self.pamMmHg = pamMmHg
            self.utaPiMedio = utaPiMedio
            self.afericoesPam = afericoesPam
        }
    }

    struct Afericao: Sendable {
        let sistolica: Double
        let diastolica: Double
    }

    struct Pam: Sendable {
        let pamMmHg: Double
        let afericoes: Int
        let protocoloCompleto: Bool
    }

    enum NomeMarcador: String, Sendable {
        case map
        case utaPi
    }

    struct Marcador: Sendable {
        let nome: NomeMarcador
        let mom: Double
        let truncado: Bool
    }

    struct Resultado: Sendable {
        let versaoParametros: String
        let priorMean: Double
        let priorSd: Double
        let gCurrent: Double
        let marcadores: [Marcador]
        let riscos: [Int: Double]
        let umEmN: Double
        let altoRisco: Bool
        let insertBloco: String
    }

    static let corteAltoRisco = 1.0 / 100.0
    static let versaoParametros = "FMF/AJOG-2020+cal-2026-08-22"
    static let janelaDias = 77.0...99.0

    private static let sigma = 6.8833
    private static let ln2Pi = Foundation.log(2.0 * Double.pi)
    // Intencional: a paridade validada com o software oficial exige a salvaguarda desligada.
    private static let salvaguardaHAS = false
    // Calibração de paridade com o software oficial, validada em 2026-08-22; não usar o paper aqui.
    private static let calMapHasPeso = -1.8859e-4
    private static let calMapIntercepto = -0.003568
    private static let cortes = [37, 34, 32]

    static func pamDeAfericoes(_ afericoes: [Afericao]) throws -> Pam {
        let validas = afericoes.filter {
            $0.sistolica.isFinite &&
                $0.diastolica.isFinite &&
                $0.sistolica > $0.diastolica &&
                $0.sistolica >= 50 && $0.sistolica <= 300 &&
                $0.diastolica >= 20 && $0.diastolica <= 200
        }
        guard !validas.isEmpty else {
            throw PeErroDeDominio("nenhuma aferição de pressão válida")
        }
        let soma = validas.reduce(0.0) {
            $0 + ($1.sistolica + 2.0 * $1.diastolica) / 3.0
        }
        return Pam(
            pamMmHg: soma / Double(validas.count),
            afericoes: validas.count,
            protocoloCompleto: validas.count >= 4
        )
    }

    static func gaDiasPorCCN(_ ccnMm: Double) throws -> Double {
        guard ccnMm.isFinite, ccnMm > 0 else {
            throw PeErroDeDominio("CCN: valor ausente ou inválido")
        }
        let dias = 23.53 + 8.052 * Foundation.sqrt(1.037 * ccnMm)
        guard janelaDias.contains(dias) else {
            throw PeErroDeDominio(
                "idade gestacional de \(formatar(dias, casas: 1)) dias fora da janela do modelo de 1º trimestre (77–99 dias)"
            )
        }
        return dias
    }

    static func calcular(_ gestante: Gestante, medidas: Medidas = Medidas()) throws -> Resultado {
        try validar(gestante, medidas)

        let priorMean = mediaIgPartoComPE(gestante)
        let gCurrent = max(24.0, gestante.gaDias / 7.0)

        var internos: [MarcadorInterno] = []
        if let pam = medidas.pamMmHg {
            let mom = mapMoM(pam, gestante)
            let bruto = Foundation.log10(mom)
            let x = truncar(bruto, minimo: -0.1224076, maximo: 0.12240759)
            internos.append(MarcadorInterno(nome: .map, mom: mom, x: x, truncado: x != bruto))
        }
        if let utaPi = medidas.utaPiMedio {
            let mom = utaPiMoM(utaPi, gestante)
            let bruto = Foundation.log10(mom)
            let x = truncar(bruto, minimo: -0.4216152, maximo: 0.42161519)
            internos.append(MarcadorInterno(nome: .utaPi, mom: mom, x: x, truncado: x != bruto))
        }

        var riscos = [37: 0.0, 34: 0.0, 32: 0.0]
        if internos.isEmpty {
            let base = pnorm((gCurrent - priorMean) / sigma)
            for corte in cortes {
                riscos[corte] = Double(corte) <= gCurrent
                    ? 0
                    : (pnorm((Double(corte) - priorMean) / sigma) - base) / (1 - base)
            }
        } else {
            riscos = try calcularPosterior(
                marcadores: internos,
                priorMean: priorMean,
                gCurrent: gCurrent
            )
        }

        let marcadores = internos.map {
            Marcador(nome: $0.nome, mom: $0.mom, truncado: $0.truncado)
        }
        let risco37 = riscos[37] ?? 0
        let umEmN = risco37 > 0 ? Foundation.floor(1.0 / risco37 + 0.5) : .infinity
        let altoRisco = risco37 >= corteAltoRisco

        return Resultado(
            versaoParametros: versaoParametros,
            priorMean: priorMean,
            priorSd: sigma,
            gCurrent: gCurrent,
            marcadores: marcadores,
            riscos: riscos,
            umEmN: umEmN,
            altoRisco: altoRisco,
            insertBloco: formatarBloco(
                gestante: gestante,
                medidas: medidas,
                marcadores: marcadores,
                umEmN: umEmN,
                altoRisco: altoRisco
            )
        )
    }

    static func log10MapEsperada(_ gestante: Gestante) -> Double {
        let ga = gestante.gaDias - 77
        let peso = gestante.peso - 69
        let altura = gestante.altura - 164
        let idade = gestante.idade - 35
        let afro = indicador(gestante.etnia == .afro)
        let has = indicador(gestante.hipertensaoCronica)

        return 1.943223919 + calMapIntercepto
            + 0.000209037 * ga
            - 0.000020452 * ga * ga
            + 0.000439271 * idade
            + 0.001193313 * peso
            - 0.000008823 * peso * peso
            - 0.000206306 * altura
            - 0.004523672 * indicador(gestante.fumante)
            - 0.001191227 * afro
            - 0.000050679 * afro * ga
            + 0.051007216 * has
            + calMapHasPeso * has * peso
            + 0.004445020 * indicador(gestante.diabetes)
            + 0.005976240 * indicador(gestante.histFamiliarPE)
            - 0.009402127 * indicador(gestante.paridade == .multiparaSemPE)
            + 0.000744526 * (gestante.paridade == .multiparaSemPE ? gestante.intervaloAnos ?? 0 : 0)
            + 0.006091903 * indicador(gestante.paridade == .multiparaComPE)
    }

    static func log10UtaPiEsperado(_ gestante: Gestante) -> Double {
        let ga = gestante.gaDias - 77
        let peso = gestante.peso - 69
        let idade = gestante.idade - 35
        let comPE = gestante.paridade == .multiparaComPE

        return 0.255731426
            - 0.004407905 * ga
            - 0.000888890 * peso
            + 0.000006006 * peso * peso
            + 0.000008322 * peso * ga
            - 0.001117349 * idade
            + 0.000015061 * idade * ga
            + 0.018069553 * indicador(gestante.etnia == .afro)
            + 0.004971474 * indicador(comPE)
            - 0.006836336 * (comPE ? gestante.zEscorePesoAnterior ?? 0 : 0)
            - 0.005119599 * (comPE ? (gestante.igPartoAnterior ?? 40) - 40 : 0)
    }

    static func mapMoM(_ pam: Double, _ gestante: Gestante) -> Double {
        pam / Foundation.pow(10, log10MapEsperada(gestante))
    }

    static func utaPiMoM(_ utaPi: Double, _ gestante: Gestante) -> Double {
        utaPi / Foundation.pow(10, log10UtaPiEsperado(gestante))
    }

    private struct MarcadorInterno {
        let nome: NomeMarcador
        let mom: Double
        let x: Double
        let truncado: Bool
    }

    private static func validar(_ gestante: Gestante, _ medidas: Medidas) throws {
        for (nome, valor) in [
            ("idade", gestante.idade),
            ("peso", gestante.peso),
            ("altura", gestante.altura),
            ("gaDias", gestante.gaDias),
        ] where !valor.isFinite {
            throw PeErroDeDominio("\(nome): valor ausente ou inválido")
        }

        guard janelaDias.contains(gestante.gaDias) else {
            throw PeErroDeDominio(
                "idade gestacional de \(formatar(gestante.gaDias, casas: 1)) dias fora da janela do modelo de 1º trimestre (77–99 dias)"
            )
        }
        try validarPlausibilidade("idade", gestante.idade, minimo: 8, maximo: 70)
        try validarPlausibilidade("peso", gestante.peso, minimo: 20, maximo: 300)
        try validarPlausibilidade("altura", gestante.altura, minimo: 100, maximo: 230)

        if let pam = medidas.pamMmHg {
            try validarMedida("pamMmHg", pam, minimo: 50, maximo: 180)
        }
        if let utaPi = medidas.utaPiMedio {
            try validarMedida("utaPiMedio", utaPi, minimo: 0.2, maximo: 6)
        }

        if gestante.paridade == .multiparaComPE {
            guard gestante.igPartoAnterior != nil else {
                throw PeErroDeDominio("multípara com PE anterior exige a IG do parto anterior")
            }
            guard gestante.zEscorePesoAnterior != nil else {
                throw PeErroDeDominio("multípara com PE anterior exige o Z-score do peso ao nascer anterior")
            }
        }
        if gestante.paridade == .multiparaSemPE {
            guard gestante.igPartoAnterior != nil else {
                throw PeErroDeDominio("multípara exige a IG do parto anterior")
            }
            guard let intervalo = gestante.intervaloAnos, intervalo > 0 else {
                throw PeErroDeDominio("multípara exige o intervalo entre gestações em anos (> 0)")
            }
        }
    }

    private static func validarPlausibilidade(
        _ nome: String,
        _ valor: Double,
        minimo: Double,
        maximo: Double
    ) throws {
        guard valor >= minimo, valor <= maximo else {
            throw PeErroDeDominio(
                "\(nome)=\(formatar(valor, casas: 1)) implausível (aceito \(formatar(minimo, casas: 0))–\(formatar(maximo, casas: 0)))"
            )
        }
    }

    private static func validarMedida(
        _ nome: String,
        _ valor: Double,
        minimo: Double,
        maximo: Double
    ) throws {
        guard valor.isFinite else {
            throw PeErroDeDominio("\(nome): valor inválido")
        }
        guard valor >= minimo, valor <= maximo else {
            throw PeErroDeDominio(
                "\(nome)=\(formatar(valor, casas: 1)) fora da faixa aceita (\(formatar(minimo, casas: 1))–\(formatar(maximo, casas: 1)))"
            )
        }
    }

    private static func mediaIgPartoComPE(_ gestante: Gestante) -> Double {
        if !gestante.hipertensaoCronica {
            return mediaComRamoHAS(gestante, comHAS: false)
        }
        return salvaguardaHAS
            ? min(mediaComRamoHAS(gestante, comHAS: true), mediaComRamoHAS(gestante, comHAS: false))
            : mediaComRamoHAS(gestante, comHAS: true)
    }

    private static func mediaComRamoHAS(_ gestante: Gestante, comHAS: Bool) -> Double {
        let idade = truncar(gestante.idade, minimo: 12, maximo: 55)
        let peso = truncar(gestante.peso, minimo: 34, maximo: 190)
        let altura = truncar(gestante.altura, minimo: 127, maximo: 198)

        var mu = 54.3637
        mu += -0.206886 * max(0, idade - 35)
        mu += 0.117110 * (altura - 164)

        if gestante.etnia == .afro { mu += -2.6786 }
        if gestante.etnia == .sulAsiatica { mu += -1.1290 }
        if gestante.lesSaf { mu += -3.0519 }
        if gestante.fiv { mu += -1.6327 }

        if comHAS {
            mu += -7.2897
        } else {
            mu += -0.0694096 * (peso - 69)
            if gestante.histFamiliarPE { mu += -1.7154 }
            if gestante.diabetes { mu += -3.3899 }
        }

        if gestante.paridade == .multiparaComPE {
            let igAnterior = truncar(gestante.igPartoAnterior ?? 0, minimo: 24, maximo: 42)
            mu += -8.1667
            mu += 0.0271988 * Foundation.pow(igAnterior - 24, 2)
        } else if gestante.paridade == .multiparaSemPE {
            let igAnterior = truncar(gestante.igPartoAnterior ?? 0, minimo: 24, maximo: 42)
            let intervalo = truncar(gestante.intervaloAnos ?? 0, minimo: 0.25, maximo: 15)
            mu += -4.3350
            mu += -4.15137651 * Foundation.pow(intervalo, -1)
            mu += 9.21473572 * Foundation.pow(intervalo, -0.5)
            mu += 0.01549673 * Foundation.pow(igAnterior - 24, 2)
        }

        return mu
    }

    private static func calcularPosterior(
        marcadores: [MarcadorInterno],
        priorMean: Double,
        gCurrent: Double
    ) throws -> [Int: Double] {
        let primeiro = marcadores[0]
        let segundo = marcadores.count == 2 ? marcadores[1] : nil
        let sAA = covariancia(primeiro.nome, primeiro.nome)
        let sBB = segundo.map { covariancia($0.nome, $0.nome) } ?? 0
        let sAB = segundo.map { covariancia(primeiro.nome, $0.nome) } ?? 0

        let inicio = gCurrent
        let fim = 100.0
        let n = 15_200
        let passo = (fim - inicio) / Double(n)

        var logF = [Double](repeating: 0, count: n + 1)
        var logMax = -Double.infinity
        for indice in 0...n {
            let t = inicio + Double(indice) * passo
            let valor: Double
            if let segundo {
                let likelihood = try logDmvnorm2(
                    primeiro.x,
                    segundo.x,
                    mediaLog10MoM(primeiro.nome, t),
                    mediaLog10MoM(segundo.nome, t),
                    sAA,
                    sAB,
                    sBB
                )
                valor = logDnorm(t, media: priorMean, desvio: sigma) + likelihood
            } else {
                valor = logDnorm(t, media: priorMean, desvio: sigma)
                    + logDmvnorm1(primeiro.x, mediaLog10MoM(primeiro.nome, t), sAA)
            }
            logF[indice] = valor
            if valor > logMax { logMax = valor }
        }
        guard logMax.isFinite else {
            throw PeErroDeDominio("verossimilhança degenerada — medidas incompatíveis com o modelo")
        }

        var f = [Double](repeating: 0, count: n + 1)
        for indice in 0...n {
            f[indice] = Foundation.exp(logF[indice] - logMax)
        }

        var acumulado = [Double](repeating: 0, count: n + 1)
        for indice in stride(from: 2, through: n, by: 2) {
            acumulado[indice] = acumulado[indice - 2]
                + (passo / 3) * (f[indice - 2] + 4 * f[indice - 1] + f[indice])
        }
        for indice in stride(from: 1, through: n - 1, by: 2) {
            acumulado[indice] = (acumulado[indice - 1] + acumulado[indice + 1]) / 2
        }
        let total = acumulado[n]
        guard total > 0, total.isFinite else {
            throw PeErroDeDominio("integral do posterior nula ou não finita")
        }

        func integralAte(_ corte: Double) -> Double {
            if corte <= inicio { return 0 }
            if corte >= fim { return total }
            let u = (corte - inicio) / passo
            let indice = Int(Foundation.floor(u))
            return acumulado[indice]
                + (acumulado[indice + 1] - acumulado[indice]) * (u - Double(indice))
        }

        var riscos: [Int: Double] = [:]
        for corte in cortes {
            let risco = integralAte(Double(corte)) / total
            guard risco.isFinite, risco >= 0, risco <= 1 else {
                throw PeErroDeDominio("risco inválido para o corte de \(corte) semanas")
            }
            riscos[corte] = risco
        }
        return riscos
    }

    private static func pnorm(_ z: Double) -> Double {
        let x = -z / Foundation.sqrt(2)
        let absoluto = abs(x)
        let t = 1 / (1 + 0.5 * absoluto)
        let ans = t * Foundation.exp(
            -absoluto * absoluto - 1.26551223
                + t * (1.00002368
                    + t * (0.37409196
                        + t * (0.09678418
                            + t * (-0.18628806
                                + t * (0.27886807
                                    + t * (-1.13520398
                                        + t * (1.48851587
                                            + t * (-0.82215223 + t * 0.17087277))))))))
        )
        return 0.5 * (x >= 0 ? ans : 2 - ans)
    }

    private static func logDnorm(_ valor: Double, media: Double, desvio: Double) -> Double {
        -0.5 * (Foundation.pow((valor - media) / desvio, 2) + ln2Pi) - Foundation.log(desvio)
    }

    private static func logDmvnorm1(_ x: Double, _ media: Double, _ variancia: Double) -> Double {
        let delta = x - media
        return -0.5 * (delta * delta / variancia + Foundation.log(variancia) + ln2Pi)
    }

    private static func logDmvnorm2(
        _ x0: Double,
        _ x1: Double,
        _ media0: Double,
        _ media1: Double,
        _ s00: Double,
        _ s01: Double,
        _ s11: Double
    ) throws -> Double {
        let determinante = s00 * s11 - s01 * s01
        guard determinante > 0 else {
            throw PeErroDeDominio("matriz de covariância não positiva definida")
        }
        let d0 = x0 - media0
        let d1 = x1 - media1
        let q = (s11 * d0 * d0 - 2 * s01 * d0 * d1 + s00 * d1 * d1) / determinante
        return -0.5 * (q + Foundation.log(determinante) + 2 * ln2Pi)
    }

    private static func mediaLog10MoM(_ marcador: NomeMarcador, _ t: Double) -> Double {
        let parametros: (b0: Double, b1: Double) = marcador == .map
            ? (0.088997, -0.0016711)
            : (0.5861, -0.014233)
        return t < -parametros.b0 / parametros.b1
            ? parametros.b0 + parametros.b1 * t
            : 0
    }

    private static func covariancia(_ primeiro: NomeMarcador, _ segundo: NomeMarcador) -> Double {
        switch (primeiro, segundo) {
        case (.map, .map): 0.00141396
        case (.utaPi, .utaPi): 0.01630906
        default: -0.0002726
        }
    }

    private static func formatarBloco(
        gestante: Gestante,
        medidas: Medidas,
        marcadores: [Marcador],
        umEmN: Double,
        altoRisco: Bool
    ) -> String {
        let semanas = Int(Foundation.floor(gestante.gaDias / 7))
        let dias = gestante.gaDias.truncatingRemainder(dividingBy: 7)
        let diasTexto = abs(dias.rounded() - dias) < 1e-10
            ? String(Int(dias.rounded()))
            : formatar(dias, casas: 1)

        var linhas = [
            "CÁLCULO DE RISCO DE PRÉ-ECLÂMPSIA (1º trimestre)",
            "",
            "Idade gestacional: \(semanas) semanas e \(diasTexto) dias.",
        ]

        if let pam = medidas.pamMmHg {
            let mom = marcadores.first { $0.nome == .map }
            let origem: String
            if let numero = medidas.afericoesPam {
                if numero >= 4 { origem = " (4 aferições)" }
                else if numero == 1 { origem = " (aferição única)" }
                else { origem = " (\(numero) aferições)" }
            } else {
                origem = ""
            }
            linhas.append(
                "Pressão arterial média: \(formatar(pam, casas: 1)) mmHg\(origem)"
                    + (mom.map { " — \(formatar($0.mom, casas: 2)) MoM" } ?? "")
            )
        }

        if let utaPi = medidas.utaPiMedio {
            let mom = marcadores.first { $0.nome == .utaPi }
            linhas.append(
                "IP médio das artérias uterinas: \(formatar(utaPi, casas: 2))"
                    + (mom.map { " (\(formatar($0.mom, casas: 2)) MoM)" } ?? "")
            )
        }

        linhas.append(contentsOf: [
            "",
            "Risco de pré-eclâmpsia com parto antes de 37 semanas: 1 em \(formatarInteiro(umEmN))",
            "",
        ])

        if altoRisco {
            linhas.append(
                "Alto risco para pré-eclâmpsia pré-termo (corte de 1 em 100). "
                    + "Recomenda-se profilaxia com ácido acetilsalicílico 150 mg à noite, do primeiro trimestre até 36 semanas, conforme o ensaio ASPRE, a critério do médico assistente."
            )
        } else {
            linhas.append(
                "Baixo risco para pré-eclâmpsia pré-termo (corte de 1 em 100). "
                    + "Seguimento pré-natal de rotina."
            )
        }

        // A origem da PAM já aparece ao lado da medida. O texto simples é o
        // contrato comum do iOS e da web; a web aplica o itálico apenas na
        // visualização, sem gravar asteriscos no laudo.
        if marcadores.contains(where: \.truncado) {
            linhas.append(contentsOf: [
                "",
                "Observação técnica: valor de marcador fora da faixa do modelo, truncado conforme a especificação.",
            ])
        }

        linhas.append(contentsOf: [
            "",
            "Baseado no modelo de riscos competitivos da Fetal Medicine Foundation (Wright D, Wright A, Nicolaides KH. Am J Obstet Gynecol 2020;223:12-23). Não constitui software certificado pela FMF.",
        ])

        return linhas.joined(separator: "\n")
    }

    private static func indicador(_ valor: Bool) -> Double { valor ? 1 : 0 }

    private static func truncar(_ valor: Double, minimo: Double, maximo: Double) -> Double {
        min(max(valor, minimo), maximo)
    }

    private static func formatar(_ valor: Double, casas: Int) -> String {
        String(format: "%.*f", locale: Locale(identifier: "pt_BR"), casas, valor)
    }

    private static func formatarInteiro(_ valor: Double) -> String {
        guard valor.isFinite else { return "∞" }
        return valor.formatted(
            .number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(0))
        )
    }
}
