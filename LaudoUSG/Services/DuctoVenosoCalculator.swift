import Foundation

/// Z-score do índice de pulsatilidade (IP) do ducto venoso fetal — marcador de
/// função cardíaca direita / oxigenação fetal. Usa literalmente a equação da
/// Calculadora v2021 da Fetal Medicine Barcelona.
///
/// Classificação:
/// - Z ≤ 1,645 (até p95): dentro do esperado
/// - Z > 1,645 (p96 ou superior): alterado
/// - Onda A reversa/ausente: padrão patológico independente do Z
enum DuctoVenosoCalculator {
    struct DVInput: Sendable, Hashable {
        let igWeeks: Int
        let igDays: Int
        let pi: Double
        let ondaA: OndaA

        init(igWeeks: Int, igDays: Int = 0, pi: Double, ondaA: OndaA) {
            self.igWeeks = igWeeks
            self.igDays = igDays
            self.pi = pi
            self.ondaA = ondaA
        }
    }

    enum OndaA: String, Sendable {
        case positiva
        case ausente
        case reversa

        var label: String {
            switch self {
            case .positiva: return "Onda A positiva"
            case .ausente: return "Onda A ausente"
            case .reversa: return "Onda A reversa"
            }
        }
    }

    enum Classification: String, Sendable {
        case normal
        case alterado
        case ondaPatologica

        var label: String {
            switch self {
            case .normal: return "Doppler do ducto venoso dentro da normalidade"
            case .alterado: return "Índice de pulsatilidade do ducto venoso acima do percentil 95 para a idade gestacional"
            case .ondaPatologica: return "Padrão patológico ao Doppler do ducto venoso — sugere descompensação cardíaca direita"
            }
        }
    }

    struct DVResult: Sendable, Hashable {
        let pi: Double
        let medianExpected: Double
        let zScore: Double
        let percentile: Int
        let classification: Classification
        let insertBloco: String
    }

    /// Equação literal do calc.js Barcelona: média = 0,903 − 0,0116 × IG.
    private static func medianFor(igWeeks: Int, igDays: Int) -> Double {
        0.903 - 0.0116 * (Double(igWeeks) + Double(igDays) / 7.0)
    }

    private static let sd = 0.1483

    static func calculate(_ input: DVInput) -> DVResult? {
        guard input.igWeeks >= 20,
              input.igWeeks <= 44,
              (0...6).contains(input.igDays),
              input.pi > 0
        else { return nil }

        let median = medianFor(igWeeks: input.igWeeks, igDays: input.igDays)
        let z = (input.pi - median) / sd
        let percentile = Int(DopplerCalculator.barcelonaDopplerPercentile(z).value.rounded())

        let cls: Classification
        if input.ondaA != .positiva {
            cls = .ondaPatologica
        } else if z <= 1.645 {
            cls = .normal
        } else {
            cls = .alterado
        }

        let piFmt = String(format: "%.2f", input.pi).replacingOccurrences(of: ".", with: ",")
        let medFmt = String(format: "%.2f", median).replacingOccurrences(of: ".", with: ",")
        let zFmt = String(format: "%+.2f", z).replacingOccurrences(of: ".", with: ",")

        let bloco = """
        Doppler do ducto venoso:
        - IP: \(piFmt) (mediana esperada para \(input.igWeeks) sem e \(input.igDays) dias: \(medFmt)).
        - Z-score: \(zFmt) (percentil \(DopplerCalculator.pct(Double(percentile)))).
        - \(input.ondaA.label).

        Conclusão: \(cls.label).
        Referência: Calculadora v2021 da Fetal Medicine Barcelona.
        """

        return DVResult(
            pi: input.pi,
            medianExpected: median,
            zScore: z,
            percentile: percentile,
            classification: cls,
            insertBloco: bloco
        )
    }
}
