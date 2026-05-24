import Foundation

/// Risco de anemia fetal via Doppler MCA-PSV (Mari, 2000).
/// Velocidade de pico sistólico (PSV) da artéria cerebral média comparada à mediana
/// esperada pra IG (em MoM — Multiples of Median).
///
/// Classificação:
/// - MoM < 1.29: normal
/// - 1.29 ≤ MoM < 1.50: anemia leve
/// - MoM ≥ 1.50: anemia moderada a severa (suspeita transfusão intrauterina)
enum AnemiaMCAPSVCalculator {
    struct AnemiaInput: Sendable, Hashable {
        let igWeeks: Int
        let igDays: Int
        let psvCmSec: Double  // velocidade pico sistólico em cm/s
    }

    enum Severity: String, Sendable {
        case normal
        case mild         // 1.29-1.50 MoM
        case moderate     // 1.50-1.55 MoM
        case severe       // ≥1.55 MoM

        var label: String {
            switch self {
            case .normal: return "MCA-PSV dentro da normalidade — sem evidência de anemia fetal"
            case .mild: return "MCA-PSV elevado — suspeita de anemia fetal leve"
            case .moderate: return "MCA-PSV acima de 1,50 MoM — suspeita de anemia fetal moderada a severa"
            case .severe: return "MCA-PSV acima de 1,55 MoM — anemia fetal severa; considerar transfusão intrauterina"
            }
        }

        var recomendacao: String {
            switch self {
            case .normal: return ""
            case .mild: return " Reavaliar em 1-2 semanas com novo Doppler."
            case .moderate, .severe: return " Convém, a critério clínico, encaminhar a centro de referência em medicina fetal para avaliação imediata."
            }
        }
    }

    struct AnemiaResult: Sendable, Hashable {
        let psv: Double
        let medianExpected: Double
        let mom: Double
        let severity: Severity
        let insertBloco: String
    }

    /// Mediana MCA-PSV (cm/s) por IG (Mari 2000, simplificado).
    /// Fórmula: mediana = e^(2.31 + 0.046 × IG_decimal)
    /// Tabela explícita pra evitar erros de cálculo em produção.
    private static let medianTable: [Int: Double] = [
        18: 23.2, 19: 24.3, 20: 25.5, 21: 26.7, 22: 28.0,
        23: 29.3, 24: 30.7, 25: 32.1, 26: 33.6, 27: 35.2,
        28: 36.9, 29: 38.7, 30: 40.5, 31: 42.4, 32: 44.4,
        33: 46.5, 34: 48.7, 35: 51.0, 36: 53.4, 37: 55.9,
        38: 58.5, 39: 61.3, 40: 64.1,
    ]

    static func calculate(_ input: AnemiaInput) -> AnemiaResult? {
        guard input.igWeeks >= 18, input.igWeeks <= 40, input.psvCmSec > 0 else { return nil }

        let clampedWeek = max(18, min(40, input.igWeeks))
        guard let median = medianTable[clampedWeek] else { return nil }

        let mom = input.psvCmSec / median

        let severity: Severity
        if mom < 1.29 { severity = .normal }
        else if mom < 1.50 { severity = .mild }
        else if mom < 1.55 { severity = .moderate }
        else { severity = .severe }

        let psvFmt = formatNumber(input.psvCmSec)
        let medianFmt = formatNumber(median)
        let momFmt = String(format: "%.2f", mom).replacingOccurrences(of: ".", with: ",")

        let bloco = """
        Doppler da artéria cerebral média:
        - Velocidade de pico sistólico (PSV): \(psvFmt) cm/s (mediana esperada para \(input.igWeeks) semanas: \(medianFmt) cm/s).
        - MoM (Multiples of Median): \(momFmt).

        Conclusão: \(severity.label).\(severity.recomendacao)
        """

        return AnemiaResult(
            psv: input.psvCmSec,
            medianExpected: median,
            mom: mom,
            severity: severity,
            insertBloco: bloco
        )
    }

    private static func formatNumber(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }
}
