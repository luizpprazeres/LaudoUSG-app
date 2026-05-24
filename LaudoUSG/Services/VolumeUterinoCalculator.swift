import Foundation

/// Volume uterino pela fórmula do elipsoide (W × H × L × 0,523).
/// Referências de normalidade variam por status hormonal e paridade:
/// - Nulípara/menacme: 40-90 mL
/// - Multípara/menacme: 80-130 mL
/// - Menopausa: < 60 mL (atrofia esperada)
/// - Pré-menarca: < 25 mL
enum VolumeUterinoCalculator {
    enum HormonalStatus: String, Sendable, CaseIterable, Identifiable {
        case preMenarca
        case nulipara
        case multipara
        case menopausa

        var id: String { rawValue }
        var label: String {
            switch self {
            case .preMenarca: return "Pré-menarca"
            case .nulipara: return "Menacme / nulípara"
            case .multipara: return "Menacme / multípara"
            case .menopausa: return "Menopausa"
            }
        }

        /// Volume em mL — intervalo de normalidade (referência).
        var faixaNormal: (Double, Double) {
            switch self {
            case .preMenarca: return (0, 25)
            case .nulipara: return (40, 90)
            case .multipara: return (80, 130)
            case .menopausa: return (10, 60)
            }
        }
    }

    struct VUInput: Sendable {
        let widthCm: Double
        let heightCm: Double
        let lengthCm: Double
        let status: HormonalStatus
    }

    enum Classification: String, Sendable {
        case normal
        case acimaReferencia
        case abaixoReferencia

        func label(for status: HormonalStatus) -> String {
            switch self {
            case .normal: return "Volume uterino dentro da normalidade para \(status.label.lowercased())"
            case .acimaReferencia: return "Volume uterino acima da referência para \(status.label.lowercased())"
            case .abaixoReferencia: return "Volume uterino abaixo da referência para \(status.label.lowercased())"
            }
        }
    }

    struct VUResult: Sendable {
        let volumeCc: Double
        let classification: Classification
        let conclusao: String
        let insertBloco: String
    }

    static func calculate(_ input: VUInput) -> VUResult? {
        guard input.widthCm > 0, input.heightCm > 0, input.lengthCm > 0 else { return nil }
        let vol = input.widthCm * input.heightCm * input.lengthCm * 0.523
        let (low, high) = input.status.faixaNormal

        let cls: Classification
        if vol < low { cls = .abaixoReferencia }
        else if vol > high { cls = .acimaReferencia }
        else { cls = .normal }

        let dims = String(format: "%.1f × %.1f × %.1f", input.widthCm, input.heightCm, input.lengthCm)
            .replacingOccurrences(of: ".", with: ",")
        let volFmt = String(format: "%.1f", vol).replacingOccurrences(of: ".", with: ",")
        let lowFmt = String(format: "%.0f", low)
        let highFmt = String(format: "%.0f", high)

        let conclusao = cls.label(for: input.status)
        let bloco = """
        Útero com dimensões de \(dims) cm.
        Volume calculado (elipsoide): \(volFmt) mL (referência para \(input.status.label.lowercased()): \(lowFmt)-\(highFmt) mL).

        Conclusão: \(conclusao).
        """

        return VUResult(volumeCc: vol, classification: cls, conclusao: conclusao, insertBloco: bloco)
    }
}
