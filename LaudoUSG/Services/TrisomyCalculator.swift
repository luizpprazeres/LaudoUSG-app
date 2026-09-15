import Foundation

struct TrisomyErroDeDominio: LocalizedError, Equatable, Sendable {
    let mensagem: String

    init(_ mensagem: String) {
        self.mensagem = mensagem
    }

    var errorDescription: String? { mensagem }
}

/// Rastreio combinado do 1º trimestre (trissomias 21, 18 e 13) — porte literal do motor
/// TypeScript `fmfTrisomy.ts` (FMF, calibrado ao app oficial). Paridade numérica garantida
/// pelo golden `golden-trissomias.json`.
enum TrisomyCalculator {
    enum Etnia: String, CaseIterable, Codable, Sendable {
        case branca = "white"
        case negra = "black"
        case sulAsiatica = "south_asian"
        case lesteAsiatica = "east_asian"
        case mista = "mixed"

        var label: String {
            switch self {
            case .branca: "Branca"
            case .negra: "Negra / afro-caribenha"
            case .sulAsiatica: "Sul-asiática"
            case .lesteAsiatica: "Leste-asiática"
            case .mista: "Mista"
            }
        }
    }

    enum Categoria: String, Codable, Sendable {
        case alto
        case intermediario
        case baixo

        var label: String {
            switch self {
            case .alto: "Alto risco"
            case .intermediario: "Risco intermediário"
            case .baixo: "Baixo risco"
            }
        }
    }

    struct Entrada: Sendable {
        /// Anos, decimal, na data do exame: (exame − nascimento) / 365,25. O motor converte para a idade na DPP.
        var maternalAge: Double
        /// CCN em mm (45–84).
        var crl: Double
        /// TN em mm.
        var nt: Double
        /// FCF em bpm (80–220).
        var fhr: Double? = nil
        /// IG datada do exame em dias (DUM/datação manual); usada na FCF esperada e na bioquímica. Se ausente, usa a IG do CCN.
        var gaDaysDated: Double? = nil
        /// Free β-hCG em MoM corrigido.
        var freeBetaHcgMoM: Double? = nil
        /// PAPP-A em MoM corrigido.
        var pappaMoM: Double? = nil
        /// Confirmação de que a bioquímica foi informada como MoM já corrigido pelo laboratório.
        var isMoMCorrected: Bool = false
        /// IP do ducto venoso.
        var dvPI: Double? = nil
        /// nil = não avaliada; false = fluxo normal (neutro); true = regurgitação.
        var tricuspidRegurgitation: Bool? = nil
        /// nil = não avaliado; false = presente; true = ausente.
        var nasalBoneAbsent: Bool? = nil
        var smoking: Bool = false
        var ethnicity: Etnia = .branca
        /// Peso materno em kg.
        var weight: Double? = nil
        var previousT21: Bool = false
        var previousT18: Bool = false
        var previousT13: Bool = false

        init(
            maternalAge: Double,
            crl: Double,
            nt: Double,
            fhr: Double? = nil,
            gaDaysDated: Double? = nil,
            freeBetaHcgMoM: Double? = nil,
            pappaMoM: Double? = nil,
            isMoMCorrected: Bool = false,
            dvPI: Double? = nil,
            tricuspidRegurgitation: Bool? = nil,
            nasalBoneAbsent: Bool? = nil,
            smoking: Bool = false,
            ethnicity: Etnia = .branca,
            weight: Double? = nil,
            previousT21: Bool = false,
            previousT18: Bool = false,
            previousT13: Bool = false
        ) {
            self.maternalAge = maternalAge
            self.crl = crl
            self.nt = nt
            self.fhr = fhr
            self.gaDaysDated = gaDaysDated
            self.freeBetaHcgMoM = freeBetaHcgMoM
            self.pappaMoM = pappaMoM
            self.isMoMCorrected = isMoMCorrected
            self.dvPI = dvPI
            self.tricuspidRegurgitation = tricuspidRegurgitation
            self.nasalBoneAbsent = nasalBoneAbsent
            self.smoking = smoking
            self.ethnicity = ethnicity
            self.weight = weight
            self.previousT21 = previousT21
            self.previousT18 = previousT18
            self.previousT13 = previousT13
        }
    }

    struct Risco: Sendable {
        /// Probabilidade (ex.: 0,004 = 1/250).
        let probability: Double
        /// Denominador do 1/N (arredondado como no motor TS).
        let ratio: Int
        let category: Categoria

        /// Texto de exibição como no app da FMF: "< 1 em 10.000", "1 em 2", "1 em 3.300".
        var texto: String { TrisomyCalculator.formatarRazao(probability) }
    }

    struct Basal: Sendable {
        let t21: Risco
        let t18: Risco
        let t13: Risco
    }

    struct Resultado: Sendable {
        let versaoParametros: String
        let fingerprintParametros: String
        let basal: Basal
        let t21: Risco
        let t18: Risco
        let t13: Risco
        /// T13 e T18 combinadas (p13 + p18), como o app da FMF exibe ("Trisomy 13/18").
        let t18t13: Risco
        /// Risco menor que 1:10.000 é exibido como "< 1 em 10.000".
        let displayCapRatio: Int
        /// Risco maior que "1 em 2" não é exibido acima disso.
        let displayFloorRatio: Int
        let gaDays: Int
        let gaWeeks: Int
        let gaDaysRemainder: Int
        let markersUsed: [String]
        let markersMissing: [String]
        let warnings: [String]
        let insertBloco: String
    }

    static let versaoParametros = TrisomyCalculatorParams.modelVersion
    static let fingerprintParametros = TrisomyCalculatorParams.sourceFingerprint
    static let displayCapRatio = 10000
    static let displayFloorRatio = 2
    static let faixaCrl = 45.0...84.0

    private static let marcadoresOpcionais = ["FCF", "Free β-hCG", "PAPP-A", "Ducto venoso", "Tricúspide", "Osso nasal"]

    // MARK: - API pública

    static func calcular(_ entrada: Entrada) throws -> Resultado {
        try validarEntrada(entrada)
        let gaDays = crlParaGaDias(entrada.crl)
        let gaDaysDated = entrada.gaDaysDated ?? gaDays
        let roundedGaDays = jsRound(gaDays)
        let gaWeeks = Foundation.floor(roundedGaDays / 7)
        let gaDaysRemainder = roundedGaDays.truncatingRemainder(dividingBy: 7)
        var markersUsed = ["Idade materna", "TN"]
        var warnings: [String] = []
        let ethnicity = entrada.ethnicity

        let prior = computePriorRisk(
            ma: entrada.maternalAge,
            gaDays: gaDays,
            prevT21: entrada.previousT21,
            prevT18: entrada.previousT18,
            prevT13: entrada.previousT13
        )
        let basal = Basal(
            t21: makeRisk(prior.t21, classifyRiskT21),
            t18: makeRisk(prior.t18, classifyRiskT18T13),
            t13: makeRisk(prior.t13, classifyRiskT18T13)
        )

        let ntLR = computeNtLikelihoodRatios(nt: entrada.nt, crl: entrada.crl)

        var lrT21 = ntLR.t21
        var lrT18 = ntLR.t18
        var lrT13 = ntLR.t13

        let fhr = entrada.fhr
        if fhr != nil { markersUsed.append("FCF") }

        let biochemLR = computeBiochemLR(
            fbhcgMoM: entrada.freeBetaHcgMoM,
            pappaMoM: entrada.pappaMoM,
            fhr: fhr,
            gaDays: gaDaysDated
        )
        let tlHcg = TrisomyCalculatorParams.truncationFbhcgT1
        if let hcg = entrada.freeBetaHcgMoM, hcg < tlHcg.lower || hcg > tlHcg.upper {
            warnings.append(
                "Free β-hCG foi truncada para o intervalo \(numeroJS(tlHcg.lower))–\(numeroJS(tlHcg.upper)) MoM."
            )
        }
        let tlPappa = TrisomyCalculatorParams.truncationPappa
        if let pappa = entrada.pappaMoM, pappa < tlPappa.lower || pappa > tlPappa.upper {
            warnings.append(
                "PAPP-A foi truncada para o intervalo \(numeroJS(tlPappa.lower))–\(numeroJS(tlPappa.upper)) MoM."
            )
        }
        if let fhrValor = entrada.fhr {
            let delta = fhrValor - expectedFhr(gaDays)
            let tlFhr = TrisomyCalculatorParams.truncationFhr
            if delta < tlFhr.lower || delta > tlFhr.upper {
                warnings.append("A diferença da FCF foi truncada ao limite previsto pelo modelo.")
            }
        }
        if let biochemLR {
            lrT21 *= biochemLR.t21
            lrT18 *= biochemLR.t18
            lrT13 *= biochemLR.t13
            if entrada.freeBetaHcgMoM != nil { markersUsed.append("Free β-hCG") }
            if entrada.pappaMoM != nil { markersUsed.append("PAPP-A") }
        }

        if let dvPI = entrada.dvPI {
            let dvLR = computeDvLR(dvpi: dvPI, crl: entrada.crl, isBlack: ethnicity == .negra)
            lrT21 *= dvLR.t21
            lrT18 *= dvLR.t18
            lrT13 *= dvLR.t13
            markersUsed.append("Ducto venoso")
        }

        if entrada.tricuspidRegurgitation == false {
            markersUsed.append("Tricúspide")
        } else if entrada.tricuspidRegurgitation == true {
            let trLR = computeTricuspidLR(
                tr: true,
                nt: entrada.nt,
                smoking: entrada.smoking,
                weight: entrada.weight ?? 69
            )
            lrT21 *= trLR.t21
            lrT18 *= trLR.t18
            lrT13 *= trLR.t13
            markersUsed.append("Tricúspide")
        }

        if let nbAbsent = entrada.nasalBoneAbsent {
            let nbLR = computeNasalBoneLR(
                nbAbsent: nbAbsent,
                nt: entrada.nt,
                crl: entrada.crl,
                pappaMoM: entrada.pappaMoM,
                fbhcgMoM: entrada.freeBetaHcgMoM,
                ethnicity: ethnicity,
                smoking: entrada.smoking
            )
            lrT21 *= nbLR.t21
            lrT18 *= nbLR.t18
            lrT13 *= nbLR.t13
            markersUsed.append("Osso nasal")
        }

        let lrTotalMin = TrisomyCalculatorParams.lrTotalMin
        lrT21 = max(lrT21, lrTotalMin)
        lrT18 = max(lrT18, lrTotalMin)
        lrT13 = max(lrT13, lrTotalMin)

        let postT21 = prior.t21 * lrT21
        let postT18 = prior.t18 * lrT18
        let postT13 = prior.t13 * lrT13
        let total = prior.u + postT21 + postT18 + postT13

        let riskT21 = postT21 / total
        let riskT18 = postT18 / total
        let riskT13 = postT13 / total

        let markersMissing = marcadoresOpcionais.filter { !markersUsed.contains($0) }

        let t21 = makeRisk(riskT21, classifyRiskT21)
        let t18 = makeRisk(riskT18, classifyRiskT18T13)
        let t13 = makeRisk(riskT13, classifyRiskT18T13)
        let t18t13 = makeRisk(riskT18 + riskT13, classifyRiskT18T13)

        return Resultado(
            versaoParametros: versaoParametros,
            fingerprintParametros: fingerprintParametros,
            basal: basal,
            t21: t21,
            t18: t18,
            t13: t13,
            t18t13: t18t13,
            displayCapRatio: displayCapRatio,
            displayFloorRatio: displayFloorRatio,
            gaDays: Int(roundedGaDays),
            gaWeeks: Int(gaWeeks),
            gaDaysRemainder: Int(gaDaysRemainder),
            markersUsed: markersUsed,
            markersMissing: markersMissing,
            warnings: warnings,
            insertBloco: formatarBloco(
                entrada: entrada,
                gaWeeks: Int(gaWeeks),
                gaDaysRemainder: Int(gaDaysRemainder),
                basal: basal,
                t21: t21,
                t18t13: t18t13,
                markersUsed: markersUsed,
                warnings: warnings
            )
        )
    }

    /// Robinson-Fleming: CCN (mm) → IG (dias).
    static func crlParaGaDias(_ crl: Double) -> Double {
        23.73 + 8.052 * Foundation.sqrt(1.037 * crl)
    }

    /// Exibição como no app da FMF: "< 1 em 10.000" acima do teto, "1 em 2" abaixo do piso,
    /// senão "1 em N" com 2 algarismos significativos (1 em 3.300, 1 em 550, 1 em 63).
    static func formatarRazao(_ probabilidade: Double) -> String {
        guard probabilidade.isFinite, probabilidade > 0 else {
            return "< 1 em \(formatarInteiro(Double(displayCapRatio)))"
        }
        let n = 1 / probabilidade
        if n > Double(displayCapRatio) {
            return "< 1 em \(formatarInteiro(Double(displayCapRatio)))"
        }
        if n < Double(displayFloorRatio) {
            return "1 em \(formatarInteiro(Double(displayFloorRatio)))"
        }
        let arredondado: Double
        if n < 10 {
            arredondado = jsRound(n)
        } else {
            let magnitude = Foundation.pow(10, Foundation.floor(Foundation.log10(n)) - 1)
            arredondado = jsRound(n / magnitude) * magnitude
        }
        if arredondado > Double(displayCapRatio) {
            return "< 1 em \(formatarInteiro(Double(displayCapRatio)))"
        }
        return "1 em \(formatarInteiro(arredondado))"
    }

    // MARK: - Prior (Cuckle + Snijders)

    private struct Prior {
        let u: Double
        let t21: Double
        let t18: Double
        let t13: Double
    }

    private static func computePriorRisk(
        ma: Double,
        gaDays: Double,
        prevT21: Bool,
        prevT18: Bool,
        prevT13: Bool
    ) -> Prior {
        let maEdd = clamp(ma + (280 - gaDays) / 365.25, 15, 51)
        let ga = gaDays

        let priorProb = 0.0007 + Foundation.exp(-16.2395 + 0.286 * maEdd)

        let lgGA7 = Foundation.log10(ga / 7)
        let rpT21 = Foundation.pow(10, 0.9425 - 1.023 * lgGA7 + 0.2718 * lgGA7 * lgGA7)
        let rpT18 = -0.142396674 + 63.5954883 / ga
        let rpT13 = -0.032203267 + 19.09501251 / ga

        let prevT18Coeff = 0.006 / (-0.142396674 + 63.5954883 / 84)
        let prevT13Coeff = 0.006 / (-0.032203267 + 19.09501251 / 84)
        let prevT21Coeff = 0.0042

        let priorT21 = (priorProb + indicador(prevT21) * prevT21Coeff) * rpT21
        let priorT18 = (priorProb + indicador(prevT18) * prevT18Coeff) * rpT18
        let priorT13 = (priorProb + indicador(prevT13) * prevT13Coeff) * rpT13
        let priorU = 1 - (priorT21 + priorT18 + priorT13)

        return Prior(u: priorU, t21: priorT21, t18: priorT18, t13: priorT13)
    }

    // MARK: - Razões de verossimilhança

    private struct LR {
        let t21: Double
        let t18: Double
        let t13: Double
    }

    /// Limite de truncamento da TN (cal-2026-09-15 v3): interpolação linear entre os nós de CCN.
    private static func ntTruncLimit(_ crl: Double) -> Double {
        let nodes = TrisomyCalculatorParams.ntTruncNodes
        guard let first = nodes.first, let last = nodes.last else { return 1.01 }
        if crl <= first.crl { return first.limite }
        for indice in 0..<(nodes.count - 1) {
            let a = nodes[indice]
            let b = nodes[indice + 1]
            if crl <= b.crl {
                return a.limite + (b.limite - a.limite) * (crl - a.crl) / (b.crl - a.crl)
            }
        }
        return last.limite
    }

    private static func computeNtLikelihoodRatios(nt: Double, crl: Double) -> LR {
        let p = TrisomyCalculatorParams.ntMix
        let logNt = Foundation.log10(nt)
        let crlR = jsRound(crl * 10) / 10

        let sr = Foundation.sqrt(Foundation.pow(p.sd, 2) + Foundation.pow(p.sdOp, 2))
        let sc = Foundation.sqrt(Foundation.pow(p.sdB, 2) + Foundation.pow(p.sdOp, 2))
        let sdT21 = Foundation.sqrt(Foundation.pow(p.sdT21, 2) + Foundation.pow(p.sdOp, 2))
        let sdT18 = Foundation.sqrt(Foundation.pow(p.sdT18, 2) + Foundation.pow(p.sdOp, 2))
        let sdT13 = Foundation.sqrt(Foundation.pow(p.sdT13, 2) + Foundation.pow(p.sdOp, 2))

        let mr = p.b0 + p.b1 * crlR + p.b2 * crlR * crlR

        let pu = 1 / (1 + Foundation.exp(-(p.a0 + p.a1 * crlR)))

        let likU = (1 - pu) * dnorm(logNt, mr, sr) + pu * dnorm(logNt, p.m1, sc)

        let truncLimit = ntTruncLimit(crlR)

        func ntLR(_ pAff: Double, _ mAff: Double, _ sdAff: Double) -> Double {
            var likAff = (1 - pAff) * dnorm(logNt, mr, sr) + pAff * dnorm(logNt, mAff, sdAff)
            if nt < truncLimit {
                let logTrunc = Foundation.log10(truncLimit)
                let likAffTrunc = (1 - pAff) * dnorm(logTrunc, mr, sr) + pAff * dnorm(logTrunc, mAff, sdAff)
                let likUTrunc = (1 - pu) * dnorm(logTrunc, mr, sr) + pu * dnorm(logTrunc, p.m1, sc)
                likAff = (likAffTrunc / likUTrunc) * likU
            }
            return likU > 0 ? likAff / likU : 1
        }

        return LR(
            t21: ntLR(p.p21, p.m21, sdT21),
            t18: ntLR(p.p18, p.m18, sdT18),
            t13: ntLR(p.p13, p.m13, sdT13)
        )
    }

    private static func computeBiochemLR(
        fbhcgMoM: Double?,
        pappaMoM: Double?,
        fhr: Double?,
        gaDays: Double
    ) -> LR? {
        if fbhcgMoM == nil, pappaMoM == nil, fhr == nil { return nil }

        let params = TrisomyCalculatorParams.self
        var values: [Double] = []
        var sdUn: [Double] = []
        var sdT21: [Double] = []
        var sdT18: [Double] = []
        var sdT13: [Double] = []
        var muT21: [Double] = []
        var muT18: [Double] = []
        var muT13: [Double] = []
        var corIndices: [Int] = []

        let gaDiff = gaDays - 77
        // NOTA: ×2 e não ×gaDiff², conforme o código R original.
        func meanCoeff(_ m: TrisomyCalculatorParams.MeanCoeff) -> Double {
            m.b0 + m.b1 * gaDiff + m.b2 * gaDiff * 2
        }

        if let fbhcgMoM {
            let tl = params.truncationFbhcgT1
            let logMoM = clamp(
                Foundation.log10(clamp(fbhcgMoM, tl.lower, tl.upper)),
                Foundation.log10(tl.lower),
                Foundation.log10(tl.upper)
            )
            values.append(logMoM)
            sdUn.append(params.gaussSd.un[0])
            sdT21.append(params.gaussSd.t21[0])
            sdT18.append(params.gaussSd.t18[0])
            sdT13.append(params.gaussSd.t13[0])
            muT21.append(meanCoeff(params.gaussMeanT21.fbhcgT1))
            muT18.append(meanCoeff(params.gaussMeanT18.fbhcgT1))
            muT13.append(meanCoeff(params.gaussMeanT13.fbhcgT1))
            corIndices.append(0)
        }

        if let pappaMoM {
            let tl = params.truncationPappa
            let logMoM = clamp(
                Foundation.log10(clamp(pappaMoM, tl.lower, tl.upper)),
                Foundation.log10(tl.lower),
                Foundation.log10(tl.upper)
            )
            values.append(logMoM)
            sdUn.append(params.gaussSd.un[1])
            sdT21.append(params.gaussSd.t21[1])
            sdT18.append(params.gaussSd.t18[1])
            sdT13.append(params.gaussSd.t13[1])
            muT21.append(meanCoeff(params.gaussMeanT21.pappa))
            muT18.append(meanCoeff(params.gaussMeanT18.pappa))
            muT13.append(meanCoeff(params.gaussMeanT13.pappa))
            corIndices.append(1)
        }

        if let fhr {
            let expectedFHR = expectedFhr(gaDays)
            let tl = params.truncationFhr
            let deltaFhr = clamp(fhr - expectedFHR, tl.lower, tl.upper)
            values.append(deltaFhr)  // delta bruto, sem log
            sdUn.append(params.gaussSd.un[2])
            sdT21.append(params.gaussSd.t21[2])
            sdT18.append(params.gaussSd.t18[2])
            sdT13.append(params.gaussSd.t13[2])
            muT21.append(meanCoeff(params.gaussMeanT21.fhr))
            muT18.append(meanCoeff(params.gaussMeanT18.fhr))
            muT13.append(meanCoeff(params.gaussMeanT13.fhr))
            corIndices.append(2)
        }

        func subCor(_ cor: [[Double]]) -> [[Double]] {
            corIndices.map { i in corIndices.map { j in cor[i][j] } }
        }

        let covUn = buildCov(sdUn, subCor(params.gaussCor.un))
        let covT21 = buildCov(sdT21, subCor(params.gaussCor.t21))
        let covT18 = buildCov(sdT18, subCor(params.gaussCor.t18))
        let covT13 = buildCov(sdT13, subCor(params.gaussCor.t13))

        let likUn = dmvnorm(values, covUn)

        let xT21 = values.enumerated().map { $0.element - muT21[$0.offset] }
        let xT18 = values.enumerated().map { $0.element - muT18[$0.offset] }
        let xT13 = values.enumerated().map { $0.element - muT13[$0.offset] }

        let likT21 = dmvnorm(xT21, covT21)
        let likT18 = dmvnorm(xT18, covT18)
        let likT13 = dmvnorm(xT13, covT13)

        if likUn <= 0 { return nil }

        let piso = params.bioLrMin
        let teto = params.lrMax
        return LR(
            t21: clamp(likT21 / likUn, piso, teto),
            t18: clamp(likT18 / likUn, piso, teto),
            t13: clamp(likT13 / likUn, piso, teto)
        )
    }

    private static func computeDvLR(dvpi: Double, crl: Double, isBlack: Bool) -> LR {
        let p = TrisomyCalculatorParams.dvpiMix
        let eth = indicador(isBlack)
        let crlR = jsRound(crl * 10) / 10

        let sr = Foundation.sqrt(Foundation.pow(p.sd, 2) + Foundation.pow(p.sdOp, 2))
        let sc = Foundation.sqrt(Foundation.pow(p.sdB, 2) + Foundation.pow(p.sdOp, 2))
        let sdT21 = Foundation.sqrt(Foundation.pow(p.sdT21, 2) + Foundation.pow(p.sdOp, 2))
        let sdT18 = Foundation.sqrt(Foundation.pow(p.sdT18, 2) + Foundation.pow(p.sdOp, 2))
        let sdT13 = Foundation.sqrt(Foundation.pow(p.sdT13, 2) + Foundation.pow(p.sdOp, 2))

        let mr = p.b0 + p.b1 * crlR + p.b2 * crlR * crlR + p.b3 * eth
        let pu = 1 / (1 + Foundation.exp(-(p.a0 + p.a1 * (crlR - 65) + p.a2 * eth)))

        let tlKey = Int(jsRound(crlR * 10))

        func dvLR(_ pAff: Double, _ mAff: Double, _ sdAff: Double, _ tabela: [Double]) -> Double {
            let trunc = dvpiTLimit(tabela, chave: tlKey)
            let x = max(dvpi, trunc)  // trunca por baixo
            let likAff = (1 - pAff) * dnorm(x, mr, sr) + pAff * dnorm(x, mAff, sdAff)
            let likU = (1 - pu) * dnorm(x, mr, sr) + pu * dnorm(x, p.mc, sc)
            return likU > 0
                ? clamp(likAff / likU, TrisomyCalculatorParams.lrMin, TrisomyCalculatorParams.lrMax)
                : 1
        }

        return LR(
            t21: dvLR(p.p21, p.m21, sdT21, TrisomyCalculatorParams.dvpiTLimitsT21),
            t18: dvLR(p.p18, p.m18, sdT18, TrisomyCalculatorParams.dvpiTLimitsT18),
            t13: dvLR(p.p13, p.m13, sdT13, TrisomyCalculatorParams.dvpiTLimitsT13)
        )
    }

    private static func dvpiTLimit(_ tabela: [Double], chave: Int) -> Double {
        let indice = chave - 450
        guard indice >= 0, indice < tabela.count else {
            return TrisomyCalculatorParams.dvpiTLimitDefault
        }
        return tabela[indice]
    }

    private static func computeTricuspidLR(tr: Bool, nt: Double, smoking: Bool, weight: Double) -> LR {
        let p = TrisomyCalculatorParams.tricuspid
        let trVal = indicador(tr)
        let lpUn = p.intercept + p.nt * nt + p.smoker * indicador(smoking) + p.weight * weight

        func trLR(_ coeff: Double) -> Double {
            let lpAff = lpUn + coeff
            let pUn = 1 / (1 + Foundation.exp(-lpUn))
            let pAff = 1 / (1 + Foundation.exp(-lpAff))
            let likUn = Foundation.pow(pUn, trVal) * Foundation.pow(1 - pUn, 1 - trVal)
            let likAff = Foundation.pow(pAff, trVal) * Foundation.pow(1 - pAff, 1 - trVal)
            return likUn > 0 ? likAff / likUn : 1
        }

        return LR(t21: trLR(p.t21), t18: trLR(p.t18), t13: trLR(p.t13))
    }

    private static func computeNasalBoneLR(
        nbAbsent: Bool,
        nt: Double,
        crl: Double,
        pappaMoM: Double?,
        fbhcgMoM: Double?,
        ethnicity: Etnia,
        smoking: Bool
    ) -> LR {
        let p = TrisomyCalculatorParams.nasalBone
        let nb: Double = nbAbsent ? 0 : 1
        let logPappa = Foundation.log10(pappaMoM ?? 1)
        let logFbhcg = Foundation.log10(fbhcgMoM ?? 1)

        let ethCoeff: Double
        switch ethnicity {
        case .negra: ethCoeff = p.black
        case .sulAsiatica: ethCoeff = p.asian
        case .mista: ethCoeff = p.mixed
        case .lesteAsiatica: ethCoeff = p.oriental
        case .branca: ethCoeff = 0
        }

        let lpUn = p.constant + p.sm * indicador(smoking) + p.nt * nt + p.crl * crl
            + p.pLmom * logPappa + p.fLmom * logFbhcg + ethCoeff

        func nbLR(_ coeff: Double) -> Double {
            let lpAff = lpUn + coeff
            let pUn = 1 / (1 + Foundation.exp(-lpUn))
            let pAff = 1 / (1 + Foundation.exp(-lpAff))
            let likUn = Foundation.pow(pUn, 1 - nb) * Foundation.pow(1 - pUn, nb)
            let likAff = Foundation.pow(pAff, 1 - nb) * Foundation.pow(1 - pAff, nb)
            return likUn > 0 ? likAff / likUn : 1
        }

        return LR(t21: nbLR(p.t21), t18: nbLR(p.t18), t13: nbLR(p.t13))
    }

    // MARK: - Classificação

    private static func classifyRiskT21(_ prob: Double) -> Categoria {
        let ratio = 1 / prob
        if ratio <= 100 { return .alto }
        if ratio <= 1000 { return .intermediario }
        return .baixo
    }

    private static func classifyRiskT18T13(_ prob: Double) -> Categoria {
        (1 / prob) <= 100 ? .alto : .baixo
    }

    private static func makeRisk(_ prob: Double, _ classifier: (Double) -> Categoria) -> Risco {
        let safeProb = max(prob, 1e-10)
        return Risco(
            probability: safeProb,
            ratio: Int(jsRound(1 / safeProb)),
            category: classifier(safeProb)
        )
    }

    // MARK: - Validação (mesmas faixas e mensagens do motor TS)

    private static func validarEntrada(_ entrada: Entrada) throws {
        try validarFaixa(entrada.maternalAge, 15, 50, "idade materna")
        try validarFaixa(entrada.crl, 45, 84, "CCN")
        try validarFaixa(entrada.nt, 0.5, 10, "translucência nucal")
        try validarOpcional(entrada.fhr, 80, 220, "frequência cardíaca fetal")
        try validarPositivo(entrada.freeBetaHcgMoM, "Free β-hCG")
        try validarPositivo(entrada.pappaMoM, "PAPP-A")
        try validarPositivo(entrada.dvPI, "IP do ducto venoso")

        if (entrada.freeBetaHcgMoM != nil || entrada.pappaMoM != nil), entrada.isMoMCorrected != true {
            throw TrisomyErroDeDominio("A bioquímica deve ser informada como MoM já corrigido pelo laboratório.")
        }
        if entrada.tricuspidRegurgitation != nil {
            try validarFaixa(entrada.weight, 35, 200, "peso materno para o marcador tricúspide")
        } else if entrada.weight != nil {
            try validarFaixa(entrada.weight, 35, 200, "peso materno")
        }
    }

    private static func validarFaixa(_ valor: Double?, _ minimo: Double, _ maximo: Double, _ campo: String) throws {
        guard let valor, valor.isFinite, valor >= minimo, valor <= maximo else {
            throw TrisomyErroDeDominio("\(campo): informe um valor entre \(numeroJS(minimo)) e \(numeroJS(maximo)).")
        }
    }

    private static func validarOpcional(_ valor: Double?, _ minimo: Double, _ maximo: Double, _ campo: String) throws {
        if valor != nil { try validarFaixa(valor, minimo, maximo, campo) }
    }

    private static func validarPositivo(_ valor: Double?, _ campo: String) throws {
        if let valor, !valor.isFinite || valor <= 0 {
            throw TrisomyErroDeDominio("\(campo): informe um valor maior que zero.")
        }
    }

    // MARK: - Utilitários numéricos

    private static func clamp(_ x: Double, _ minimo: Double, _ maximo: Double) -> Double {
        max(minimo, min(maximo, x))
    }

    private static func dnorm(_ x: Double, _ mu: Double, _ sd: Double) -> Double {
        let z = (x - mu) / sd
        return Foundation.exp(-0.5 * z * z) / (sd * Foundation.sqrt(2 * Double.pi))
    }

    /// Frequência cardíaca fetal esperada por IG (Kagan 2008).
    private static func expectedFhr(_ gaDays: Double) -> Double {
        265.98 - 1.410084 - 1.7631 * gaDays + 0.0064445 * gaDays * gaDays
    }

    /// Densidade normal multivariada (1D, 2D ou 3D), como no motor TS.
    private static func dmvnorm(_ x: [Double], _ sigma: [[Double]]) -> Double {
        let n = x.count
        if n == 1 { return dnorm(x[0], 0, Foundation.sqrt(sigma[0][0])) }

        if n == 2 {
            let det = sigma[0][0] * sigma[1][1] - sigma[0][1] * sigma[1][0]
            if det <= 0 { return 0 }
            let inv00 = sigma[1][1] / det
            let inv01 = -sigma[0][1] / det
            let inv10 = -sigma[1][0] / det
            let inv11 = sigma[0][0] / det
            let q = inv00 * x[0] * x[0] + (inv01 + inv10) * x[0] * x[1] + inv11 * x[1] * x[1]
            return Foundation.exp(-0.5 * q) / (2 * Double.pi * Foundation.sqrt(det))
        }

        if n == 3 {
            let m = sigma
            let det =
                m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
                m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
                m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
            if det <= 0 { return 0 }

            let inv: [[Double]] = [
                [
                    (m[1][1] * m[2][2] - m[1][2] * m[2][1]) / det,
                    (m[0][2] * m[2][1] - m[0][1] * m[2][2]) / det,
                    (m[0][1] * m[1][2] - m[0][2] * m[1][1]) / det,
                ],
                [
                    (m[1][2] * m[2][0] - m[1][0] * m[2][2]) / det,
                    (m[0][0] * m[2][2] - m[0][2] * m[2][0]) / det,
                    (m[0][2] * m[1][0] - m[0][0] * m[1][2]) / det,
                ],
                [
                    (m[1][0] * m[2][1] - m[1][1] * m[2][0]) / det,
                    (m[0][1] * m[2][0] - m[0][0] * m[2][1]) / det,
                    (m[0][0] * m[1][1] - m[0][1] * m[1][0]) / det,
                ],
            ]
            var q = 0.0
            for i in 0..<3 {
                for j in 0..<3 {
                    q += inv[i][j] * x[i] * x[j]
                }
            }
            return Foundation.exp(-0.5 * q) / (Foundation.pow(2 * Double.pi, 1.5) * Foundation.sqrt(det))
        }
        return 0
    }

    /// Matriz de covariância a partir dos SDs e da matriz de correlação.
    private static func buildCov(_ sd: [Double], _ cor: [[Double]]) -> [[Double]] {
        let n = sd.count
        var cov = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in 0..<n {
                cov[i][j] = sd[i] * cor[i][j] * sd[j]
            }
        }
        return cov
    }

    /// `Math.round` do JavaScript (meio arredonda para +∞).
    private static func jsRound(_ x: Double) -> Double {
        Foundation.floor(x + 0.5)
    }

    private static func indicador(_ valor: Bool) -> Double { valor ? 1 : 0 }

    /// Número como o JavaScript imprime em template strings (15 → "15", 0.5 → "0.5").
    private static func numeroJS(_ valor: Double) -> String {
        if valor == Foundation.floor(valor), abs(valor) < 1e15 {
            return String(Int(valor))
        }
        return "\(valor)"
    }

    // MARK: - Bloco para o laudo

    private static func formatarBloco(
        entrada: Entrada,
        gaWeeks: Int,
        gaDaysRemainder: Int,
        basal: Basal,
        t21: Risco,
        t18t13: Risco,
        markersUsed: [String],
        warnings: [String]
    ) -> String {
        // Enxuto de propósito: IG, CCN, TN e demais medidas já constam no laudo.
        // O que importa aqui é o risco basal e o risco ajustado, legíveis de uma vez.
        let basal1318 = formatarRazao(basal.t18.probability + basal.t13.probability)
        let marcadores = markersUsed.filter { $0 != "Idade materna" }
        let porMarcadores = marcadores.isEmpty ? "" : " (\(marcadores.joined(separator: ", ")))"

        var linhas = [
            "RASTREIO COMBINADO DE TRISSOMIAS (1º trimestre, FMF)",
            "Risco basal, pela idade materna e idade gestacional: trissomia 21 — \(basal.t21.texto); trissomias 13/18 — \(basal1318).",
            "Risco ajustado pelos marcadores\(porMarcadores): trissomia 21 — \(t21.texto); trissomias 13/18 — \(t18t13.texto).",
        ]

        switch t21.category {
        case .alto:
            linhas.append("Alto risco para trissomia 21 (≥ 1 em 100): recomenda-se aconselhamento genético e oferta de teste diagnóstico invasivo, a critério do médico assistente.")
        case .intermediario:
            linhas.append("Risco intermediário para trissomia 21 (entre 1 em 101 e 1 em 1.000): pode-se considerar DNA fetal livre no sangue materno, a critério do médico assistente.")
        case .baixo:
            linhas.append("Baixo risco para trissomia 21 (< 1 em 1.000).")
        }
        if t18t13.category == .alto {
            linhas.append("Alto risco para trissomias 13/18 (≥ 1 em 100): recomenda-se aconselhamento genético e avaliação morfológica detalhada.")
        }
        if !warnings.isEmpty {
            linhas.append("Observação: " + warnings.joined(separator: " "))
        }
        return linhas.joined(separator: "\n")
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
