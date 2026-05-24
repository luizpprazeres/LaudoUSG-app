import Foundation

/// Volume residual pós-miccional (urina residual na bexiga após esvaziamento).
/// Útil em ultrassom de vias urinárias e próstata suprapúbica.
///
/// Cálculo pela fórmula do elipsoide (W × H × L × 0,523).
///
/// Classificação clínica:
/// - < 50 mL: sem retenção significativa
/// - 50-100 mL: questionável / borderline
/// - 100-200 mL: retenção urinária moderada
/// - > 200 mL: retenção urinária significativa
enum VolumeResidualCalculator {
    struct VRInput: Sendable, Hashable {
        let widthCm: Double
        let heightCm: Double
        let lengthCm: Double
    }

    enum Classification: String, Sendable {
        case ausente
        case borderline
        case moderado
        case significativo

        var label: String {
            switch self {
            case .ausente: return "Sem retenção urinária significativa"
            case .borderline: return "Resíduo pós-miccional limítrofe"
            case .moderado: return "Resíduo pós-miccional aumentado (retenção urinária moderada)"
            case .significativo: return "Retenção urinária significativa"
            }
        }

        var recomendacao: String {
            switch self {
            case .ausente: return ""
            case .borderline: return " Convém, a critério clínico, correlacionar com queixas urinárias."
            case .moderado: return " Recomenda-se correlação clínico-urológica."
            case .significativo: return " Recomenda-se avaliação urológica."
            }
        }
    }

    struct VRResult: Sendable, Hashable {
        let volumeMl: Double
        let classification: Classification
        let insertBloco: String
    }

    static func calculate(_ input: VRInput) -> VRResult? {
        guard input.widthCm > 0, input.heightCm > 0, input.lengthCm > 0 else { return nil }
        let vol = input.widthCm * input.heightCm * input.lengthCm * 0.523

        let cls: Classification
        if vol < 50 { cls = .ausente }
        else if vol < 100 { cls = .borderline }
        else if vol < 200 { cls = .moderado }
        else { cls = .significativo }

        let dims = String(format: "%.1f × %.1f × %.1f", input.widthCm, input.heightCm, input.lengthCm)
            .replacingOccurrences(of: ".", with: ",")
        let volFmt = String(format: "%.0f", vol)

        let bloco = """
        Bexiga após esvaziamento com dimensões de \(dims) cm.
        Volume residual pós-miccional: \(volFmt) mL.

        Conclusão: \(cls.label).\(cls.recomendacao)
        """

        return VRResult(volumeMl: vol, classification: cls, insertBloco: bloco)
    }
}
