import Foundation

/// Antral Follicle Count (AFC) — contagem de folículos antrais (2-10mm) em ambos
/// ovários como marcador de reserva ovariana. Soma direita + esquerda.
///
/// Classificação (consenso clínico Bologna/PCOS Rotterdam):
/// - <7: reserva ovariana diminuída
/// - 7-14: reserva ovariana normal
/// - 15-19: reserva ovariana alta
/// - ≥20: suspeita morfológica de SOP (síndrome dos ovários policísticos)
enum AFCCalculator {
    struct AFCInput: Sendable, Hashable {
        let direito: Int
        let esquerdo: Int
    }

    enum Classification: String, Sendable {
        case diminuida
        case normal
        case alta
        case sopSuspeita

        var label: String {
            switch self {
            case .diminuida: return "Reserva ovariana diminuída"
            case .normal: return "Reserva ovariana normal"
            case .alta: return "Reserva ovariana alta"
            case .sopSuspeita: return "Achados morfológicos sugestivos de síndrome dos ovários policísticos (SOP)"
            }
        }

        var recomendacao: String {
            switch self {
            case .diminuida: return " Convém, a critério clínico, correlacionar com dosagens hormonais (FSH, AMH) para avaliar reserva ovariana."
            case .normal, .alta: return ""
            case .sopSuspeita: return " Convém, a critério clínico, correlacionar com critérios de Rotterdam (clínica + dosagens hormonais) para diagnóstico de SOP."
            }
        }
    }

    struct AFCResult: Sendable, Hashable {
        let total: Int
        let classification: Classification
        let insertBloco: String
    }

    static func calculate(_ input: AFCInput) -> AFCResult? {
        guard input.direito >= 0, input.esquerdo >= 0 else { return nil }
        let total = input.direito + input.esquerdo
        guard total > 0 else { return nil }

        let cls: Classification
        if total < 7 { cls = .diminuida }
        else if total < 15 { cls = .normal }
        else if total < 20 { cls = .alta }
        else { cls = .sopSuspeita }

        let bloco = """
        Contagem de folículos antrais (AFC):
        - Ovário direito: \(input.direito) folículos.
        - Ovário esquerdo: \(input.esquerdo) folículos.
        - Total: \(total) folículos.

        Conclusão: \(cls.label).\(cls.recomendacao)
        """

        return AFCResult(total: total, classification: cls, insertBloco: bloco)
    }
}
