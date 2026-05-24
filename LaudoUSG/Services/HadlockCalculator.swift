import Foundation

/// Estimativa de peso fetal por biometria — Hadlock 4 (1985), a fórmula mais usada
/// no Brasil pra cálculo de EFW (Estimated Fetal Weight) em USG obstétrica.
///
/// log10(EFW) = 1.3596 − 0.00386·CA·CF + 0.0064·CC + 0.00061·DBP·CA + 0.0424·CA + 0.174·CF
///
/// Aceita medidas em mm ou cm — converte automaticamente. Output em gramas + percentil
/// estimado via tabela Hadlock por IG (peso esperado p10/p50/p90 por semana).
enum HadlockCalculator {
    struct HadlockInput: Sendable, Hashable {
        let dbp: Double  // cm
        let cc: Double   // cm
        let ca: Double   // cm
        let cf: Double   // cm
        let igWeeks: Int
        let igDays: Int
    }

    struct HadlockResult: Sendable, Hashable {
        let weightGrams: Int         // EFW arredondado
        let weightVariation: Int     // ±15% (Hadlock erro típico)
        let percentile: String       // "<P10", "P10", "P25", "P50", "P75", "P90", ">P90"
        let percentileValue: Int     // 0-100 estimado
        let isSGA: Bool              // small for gestational age (<P10)
        let isLGA: Bool              // large for gestational age (>P90)
        let insertBloco: String      // snippet pra inserir no laudo
    }

    /// Calcula EFW via Hadlock 4. Retorna nil se algum input < 1.0 cm (provavelmente erro).
    static func calculate(_ input: HadlockInput) -> HadlockResult? {
        // Normaliza mm → cm (se valor > 20, assume mm)
        let dbpCm = normalizeCm(input.dbp)
        let ccCm = normalizeCm(input.cc)
        let caCm = normalizeCm(input.ca)
        let cfCm = normalizeCm(input.cf)

        guard dbpCm > 1, ccCm > 1, caCm > 1, cfCm > 1 else { return nil }

        let logEFW = 1.3596
            - 0.00386 * caCm * cfCm
            + 0.0064 * ccCm
            + 0.00061 * dbpCm * caCm
            + 0.0424 * caCm
            + 0.174 * cfCm

        let efw = pow(10, logEFW)
        let weight = Int(efw.rounded())
        let variation = Int((efw * 0.15).rounded())  // Hadlock 4: ±15% pra IG > 24 sem

        let percentileValue = percentileFor(weight: weight, igWeeks: input.igWeeks)
        let percentileLabel = labelForPercentile(percentileValue)

        let bloco = """
        Peso fetal estimado em \(weight) g (±\(variation) g, \(percentileLabel)).
        """

        return HadlockResult(
            weightGrams: weight,
            weightVariation: variation,
            percentile: percentileLabel,
            percentileValue: percentileValue,
            isSGA: percentileValue < 10,
            isLGA: percentileValue > 90,
            insertBloco: bloco
        )
    }

    private static func normalizeCm(_ value: Double) -> Double {
        value > 20 ? value / 10 : value
    }

    /// Tabela de peso fetal esperado (p10/p50/p90 em gramas) por semana, baseada em
    /// Hadlock et al. 1991 + estudos brasileiros. Interpola percentil real via Z-score.
    private static let weightCurve: [Int: (p10: Double, p50: Double, p90: Double)] = [
        20: (260, 300, 340), 21: (310, 360, 410), 22: (370, 430, 490),
        23: (440, 510, 580), 24: (520, 600, 680), 25: (600, 700, 800),
        26: (700, 820, 940), 27: (820, 960, 1100), 28: (950, 1110, 1270),
        29: (1100, 1280, 1460), 30: (1260, 1470, 1680), 31: (1430, 1670, 1910),
        32: (1610, 1880, 2150), 33: (1800, 2100, 2400), 34: (2000, 2330, 2660),
        35: (2200, 2570, 2940), 36: (2410, 2810, 3210), 37: (2620, 3060, 3500),
        38: (2820, 3290, 3760), 39: (3000, 3500, 4000), 40: (3160, 3690, 4220),
        41: (3270, 3820, 4370),
    ]

    private static func percentileFor(weight: Int, igWeeks: Int) -> Int {
        let clampedWeek = max(20, min(41, igWeeks))
        guard let curve = weightCurve[clampedWeek] else { return 50 }
        // Aproxima sigma via (p90 - p10)/2.5631 (z=±1.2816 cobre p10-p90)
        let sigma = (curve.p90 - curve.p10) / 2.5631
        guard sigma > 0 else { return 50 }
        let z = (Double(weight) - curve.p50) / sigma
        return Int(DopplerCalculator.zToPercentile(z).rounded())
    }

    private static func labelForPercentile(_ p: Int) -> String {
        if p < 3 { return "percentil < 3" }
        if p < 10 { return "percentil \(p)" }
        if p > 97 { return "percentil > 97" }
        if p > 90 { return "percentil \(p)" }
        return "percentil \(p)"
    }
}
