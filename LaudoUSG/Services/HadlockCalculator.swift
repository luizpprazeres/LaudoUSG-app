import Foundation
import os

struct BiometryInput: Sendable, Hashable {
    let dbp: Double
    let cc: Double
    let ca: Double
    let cf: Double
    let igWeeks: Int
    let igDays: Int
    let sex: Sex

    init(
        dbp: Double,
        cc: Double,
        ca: Double,
        cf: Double,
        igWeeks: Int,
        igDays: Int,
        sex: Sex = .unisex
    ) {
        self.dbp = dbp
        self.cc = cc
        self.ca = ca
        self.cf = cf
        self.igWeeks = igWeeks
        self.igDays = igDays
        self.sex = sex
    }
}

enum WeightFormula: String, Codable, Sendable, CaseIterable {
    case hadlock4_1985

    var version: String { "hadlock4-1985" }
    var displayName: String { "Hadlock 4 (1985)" }
}

enum PercentileSource: String, Codable, Sendable, CaseIterable {
    case intergrowth21st = "intergrowth21st"
    case hadlock1991 = "hadlock1991"
    case whoMulticentre2017 = "whoMulticentre2017"

    var displayName: String {
        switch self {
        case .intergrowth21st: "Intergrowth-21st"
        case .hadlock1991: "Hadlock 1991"
        case .whoMulticentre2017: "WHO Multicentre 2017"
        }
    }

    var auditTag: String { displayName }

    /// Fontes cuja tabela ainda não foi curada não aparecem nas preferências
    /// e, se já estiverem salvas, caem para o padrão (Intergrowth-21st).
    var isAvailable: Bool {
        switch self {
        case .intergrowth21st, .hadlock1991: true
        case .whoMulticentre2017:
            !(WHOMulticentreTable.unisex.isEmpty
                && WHOMulticentreTable.boys.isEmpty
                && WHOMulticentreTable.girls.isEmpty)
        }
    }
}

/// Biometrias aceitas em mm ou cm (o campo diz "ex: 72 mm ou 7,2 cm").
/// O limiar de cada medida fica entre o MAIOR valor plausível em cm e o
/// MENOR valor plausível em mm a partir de 14 semanas, para que uma CA ou CC
/// de termo (30–40 cm) nunca seja lida como milímetros.
enum BiometryMeasure: Sendable {
    case dbp, cc, ca, cf

    var mmThreshold: Double {
        switch self {
        case .dbp: 12   // cm: 2–10   | mm: 20–100
        case .cc: 45    // cm: 8–38   | mm: 80–380
        case .ca: 45    // cm: 7–42   | mm: 70–420
        case .cf: 10    // cm: 1–8,5  | mm: 12–85
        }
    }
}

struct BiometryResult: Sendable, Hashable {
    let weightGrams: Int
    let weightVariation: Int
    let percentileValue: Int
    let percentileLabel: String
    let isSGA: Bool
    let isLGA: Bool
    let insertBloco: String
    let formulaUsed: WeightFormula
    let percentileSourceUsed: PercentileSource
    let sexDetected: Sex
    let sexUsedInLookup: Sex
    let sourceVersion: String
}

enum HadlockCalculator {
    private static let logger = Logger(
        subsystem: "com.laudousg.LaudoUSG",
        category: "obstetric"
    )

    static func calculate(
        _ input: BiometryInput,
        weightFormula: WeightFormula = .hadlock4_1985,
        percentileSource: PercentileSource = .intergrowth21st
    ) -> BiometryResult? {
        let dbpCm = normalizeCm(input.dbp, measure: .dbp)
        let ccCm = normalizeCm(input.cc, measure: .cc)
        let caCm = normalizeCm(input.ca, measure: .ca)
        let cfCm = normalizeCm(input.cf, measure: .cf)
        let effectiveSource: PercentileSource = percentileSource.isAvailable
            ? percentileSource
            : .intergrowth21st

        guard dbpCm > 1, ccCm > 1, caCm > 1, cfCm > 1 else { return nil }

        let logEFW = 1.3596
            - 0.00386 * caCm * cfCm
            + 0.0064 * ccCm
            + 0.00061 * dbpCm * caCm
            + 0.0424 * caCm
            + 0.174 * cfCm

        let efw = pow(10, logEFW)
        let weight = Int(efw.rounded())
        let variation = Int((efw * 0.15).rounded())
        guard let lookup = percentileLookup(
            source: effectiveSource,
            weight: weight,
            igWeeks: input.igWeeks,
            igDays: input.igDays,
            sex: input.sex
        ) else { return nil }
        let percentileValue = lookup.percentile
        let percentileLabel = PercentileMath.label(percentileValue)
        let bloco = insertBlock(
            weight: weight,
            variation: variation,
            percentileLabel: percentileLabel,
            source: effectiveSource,
            sexDetected: input.sex,
            sexUsedInLookup: lookup.sexUsed
        )

        logger.info(
            "biometry weight=\(weight) percentile=\(percentileValue) source=\(effectiveSource.auditTag) sexDetected=\(input.sex.rawValue) sexUsed=\(lookup.sexUsed.rawValue) version=\(lookup.version)"
        )

        return BiometryResult(
            weightGrams: weight,
            weightVariation: variation,
            percentileValue: percentileValue,
            percentileLabel: percentileLabel,
            isSGA: percentileValue < 10,
            isLGA: percentileValue > 90,
            insertBloco: bloco,
            formulaUsed: weightFormula,
            percentileSourceUsed: effectiveSource,
            sexDetected: input.sex,
            sexUsedInLookup: lookup.sexUsed,
            sourceVersion: lookup.version
        )
    }

    static func gestationalAgeByFemur(cf: Double) -> GestationalAge? {
        let cfMm = cf >= BiometryMeasure.cf.mmThreshold ? cf : cf * 10
        guard cfMm > 10 else { return nil }
        let cfCm = cfMm / 10
        let weeks = 10.35 + 2.46 * cfCm + 0.17 * pow(cfCm, 2)
        guard weeks.isFinite, weeks > 0 else { return nil }
        let roundedDays = Int((weeks * 7).rounded())
        return GestationalAge(weeks: roundedDays / 7, days: roundedDays % 7, source: .biometria)
    }

    static func normalizeCm(_ value: Double, measure: BiometryMeasure) -> Double {
        value >= measure.mmThreshold ? value / 10 : value
    }

    private static func percentileLookup(
        source: PercentileSource,
        weight: Int,
        igWeeks: Int,
        igDays: Int,
        sex: Sex
    ) -> (percentile: Int, sexUsed: Sex, version: String)? {
        switch source {
        case .intergrowth21st:
            return (
                IntergrowthTable.percentileFor(
                    weight: weight,
                    igWeeks: igWeeks,
                    igDays: igDays
                ),
                .unisex,
                IntergrowthTable.version
            )
        case .hadlock1991:
            return (
                HadlockTable.percentileFor(
                    weight: weight,
                    igWeeks: igWeeks,
                    igDays: igDays
                ),
                .unisex,
                HadlockTable.version
            )
        case .whoMulticentre2017:
            guard let band = WHOMulticentreTable.lookup(
                igWeeks: igWeeks,
                igDays: igDays,
                sex: sex
            ) else {
                return nil
            }
            return (
                PercentileMath.percentileFor(weight: weight, band: band),
                WHOMulticentreTable.usedSex(requested: sex),
                WHOMulticentreTable.version
            )
        }
    }

    private static func insertBlock(
        weight: Int,
        variation: Int,
        percentileLabel: String,
        source: PercentileSource,
        sexDetected: Sex,
        sexUsedInLookup: Sex
    ) -> String {
        var suffix = ""
        if sexUsedInLookup != .unisex && source == .whoMulticentre2017 {
            suffix = " — curva \(sexUsedInLookup.displayName)"
        }
        var text = "Peso fetal estimado em \(weight) g (±\(variation) g, \(percentileLabel) \(source.displayName)\(suffix))."
        if sexDetected != .unisex {
            text += " Sexo \(sexDetected.displayName) detectado nos achados."
        }
        return text
    }
}
