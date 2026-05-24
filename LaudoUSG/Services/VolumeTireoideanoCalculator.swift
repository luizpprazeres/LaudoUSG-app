import Foundation

/// Volume tireoideano (cada lobo W × H × L × 0,523; soma dos lobos).
/// Istmo geralmente não é incluído. Referência:
/// - Mulher adulta: ≤ 18 mL = normal
/// - Homem adulto: ≤ 25 mL = normal
/// - Crianças: usar tabela por idade/sexo (não aplicado nesta versão).
enum VolumeTireoideanoCalculator {
    enum Sex: String, Sendable, CaseIterable, Identifiable {
        case feminino
        case masculino

        var id: String { rawValue }
        var label: String { self == .feminino ? "Feminino" : "Masculino" }
        var limiteSuperior: Double { self == .feminino ? 18.0 : 25.0 }
    }

    struct LobeInput: Sendable, Hashable {
        let widthCm: Double
        let heightCm: Double
        let lengthCm: Double

        var volume: Double {
            max(0, widthCm) * max(0, heightCm) * max(0, lengthCm) * 0.523
        }
    }

    struct VTInput: Sendable {
        let sex: Sex
        let direito: LobeInput
        let esquerdo: LobeInput
    }

    enum Classification: String, Sendable {
        case normal
        case aumentado
        case reduzido

        var label: String {
            switch self {
            case .normal: return "Volume tireoideano dentro da normalidade"
            case .aumentado: return "Volume tireoideano aumentado (compatível com bócio)"
            case .reduzido: return "Volume tireoideano reduzido"
            }
        }
    }

    struct VTResult: Sendable {
        let volumeDireito: Double
        let volumeEsquerdo: Double
        let volumeTotal: Double
        let classification: Classification
        let insertBloco: String
    }

    static func calculate(_ input: VTInput) -> VTResult? {
        let d = input.direito.volume
        let e = input.esquerdo.volume
        guard d > 0 || e > 0 else { return nil }
        let total = d + e

        let cls: Classification
        if total < 4 { cls = .reduzido }
        else if total <= input.sex.limiteSuperior { cls = .normal }
        else { cls = .aumentado }

        let dFmt = fmt(input.direito)
        let eFmt = fmt(input.esquerdo)
        let totalFmt = String(format: "%.1f", total).replacingOccurrences(of: ".", with: ",")
        let dVolFmt = String(format: "%.1f", d).replacingOccurrences(of: ".", with: ",")
        let eVolFmt = String(format: "%.1f", e).replacingOccurrences(of: ".", with: ",")
        let limiteFmt = String(format: "%.0f", input.sex.limiteSuperior)

        let bloco = """
        Lobo direito: \(dFmt) — volume: \(dVolFmt) mL.
        Lobo esquerdo: \(eFmt) — volume: \(eVolFmt) mL.
        Volume tireoideano total: \(totalFmt) mL (limite superior para \(input.sex.label.lowercased()): \(limiteFmt) mL).

        Conclusão: \(cls.label).
        """

        return VTResult(
            volumeDireito: d,
            volumeEsquerdo: e,
            volumeTotal: total,
            classification: cls,
            insertBloco: bloco
        )
    }

    private static func fmt(_ l: LobeInput) -> String {
        String(format: "%.1f × %.1f × %.1f cm", l.widthCm, l.heightCm, l.lengthCm)
            .replacingOccurrences(of: ".", with: ",")
    }
}
