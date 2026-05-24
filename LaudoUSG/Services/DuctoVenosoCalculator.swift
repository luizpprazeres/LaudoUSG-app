import Foundation

/// Z-score do índice de pulsatilidade (IP) do ducto venoso fetal — marcador de
/// função cardíaca direita / oxigenação fetal. Baseado em Hecher 2001.
///
/// Mediana decresce com IG: ~1.00 (20 sem) → ~0.55 (40 sem)
/// SD ~ 0.16
///
/// Classificação:
/// - Z < 1.5: normal
/// - 1.5 ≤ Z < 2.0: limítrofe — vigilância
/// - Z ≥ 2.0: alterado (sugere comprometimento)
/// - Onda A reversa/ausente: padrão patológico independente do Z
enum DuctoVenosoCalculator {
    struct DVInput: Sendable, Hashable {
        let igWeeks: Int
        let pi: Double
        let ondaA: OndaA
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
        case limitrofe
        case alterado
        case ondaPatologica

        var label: String {
            switch self {
            case .normal: return "Doppler do ducto venoso dentro da normalidade"
            case .limitrofe: return "Doppler do ducto venoso limítrofe — recomenda-se vigilância"
            case .alterado: return "Doppler do ducto venoso alterado — sugere comprometimento hemodinâmico fetal"
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

    /// Mediana de PI do ducto venoso por IG (Hecher 2001, simplificada por regressão linear).
    private static func medianFor(igWeeks: Int) -> Double {
        // Linear approximation: 0.92 - 0.014 * IG (cm/s decresce com idade)
        max(0.40, 0.92 - 0.014 * Double(igWeeks))
    }

    private static let sd = 0.16

    static func calculate(_ input: DVInput) -> DVResult? {
        guard input.igWeeks >= 20, input.igWeeks <= 40, input.pi > 0 else { return nil }

        let median = medianFor(igWeeks: input.igWeeks)
        let z = (input.pi - median) / sd
        let percentile = Int(DopplerCalculator.zToPercentile(z).rounded())

        let cls: Classification
        if input.ondaA != .positiva {
            cls = .ondaPatologica
        } else if z < 1.5 {
            cls = .normal
        } else if z < 2.0 {
            cls = .limitrofe
        } else {
            cls = .alterado
        }

        let piFmt = String(format: "%.2f", input.pi).replacingOccurrences(of: ".", with: ",")
        let medFmt = String(format: "%.2f", median).replacingOccurrences(of: ".", with: ",")
        let zFmt = String(format: "%+.2f", z).replacingOccurrences(of: ".", with: ",")

        let bloco = """
        Doppler do ducto venoso:
        - IP: \(piFmt) (mediana esperada para \(input.igWeeks) sem: \(medFmt)).
        - Z-score: \(zFmt) (percentil \(percentile)).
        - \(input.ondaA.label).

        Conclusão: \(cls.label).
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
