import Foundation

/// Índice de Líquido Amniótico (ILA) pela técnica dos 4 quadrantes (Phelan, 1987).
/// Soma das medidas verticais dos maiores bolsões em cada quadrante (Q1+Q2+Q3+Q4).
///
/// Classificação:
/// - <5 cm: oligoidrâmnio (reduzido)
/// - 5-8 cm: tendência a oligo
/// - 8-24 cm: normal
/// - >24 cm: polidrâmnio (aumentado)
enum ILA4QCalculator {
    struct ILAInput: Sendable, Hashable {
        let q1: Double  // cm
        let q2: Double
        let q3: Double
        let q4: Double
    }

    enum Classification: String, Sendable {
        case oligoSevero       // <5 cm
        case oligoModerado     // 5-8 cm
        case normal            // 8-24 cm
        case poli              // >24 cm

        var corpoSnippet: String {
            switch self {
            case .oligoSevero, .oligoModerado: return "reduzida"
            case .normal: return "normal"
            case .poli: return "aumentada"
            }
        }

        var label: String {
            switch self {
            case .oligoSevero: return "Líquido amniótico em quantidade reduzida (oligoidrâmnio)"
            case .oligoModerado: return "Líquido amniótico em quantidade reduzida (tendência a oligoidrâmnio)"
            case .normal: return "Líquido amniótico em quantidade normal"
            case .poli: return "Líquido amniótico em quantidade aumentada (polidrâmnio)"
            }
        }
    }

    struct ILAResult: Sendable, Hashable {
        let total: Double           // soma dos 4 quadrantes
        let classification: Classification
        let insertBloco: String     // snippet pra inserir no laudo
    }

    static func calculate(_ input: ILAInput) -> ILAResult? {
        guard input.q1 >= 0, input.q2 >= 0, input.q3 >= 0, input.q4 >= 0 else { return nil }
        let total = input.q1 + input.q2 + input.q3 + input.q4
        guard total > 0 else { return nil }

        let cls: Classification
        if total < 5 { cls = .oligoSevero }
        else if total < 8 { cls = .oligoModerado }
        else if total <= 24 { cls = .normal }
        else { cls = .poli }

        let totalFmt = formatNumber(total)
        let bloco = """
        Índice do líquido amniótico (ILA) = \(formatNumber(input.q1)) + \(formatNumber(input.q2)) + \(formatNumber(input.q3)) + \(formatNumber(input.q4)) = \(totalFmt) cm.

        Conclusão: \(cls.label) (ILA mede \(totalFmt) cm).
        """

        return ILAResult(total: total, classification: cls, insertBloco: bloco)
    }

    private static func formatNumber(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rounded))"
            : String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }
}
