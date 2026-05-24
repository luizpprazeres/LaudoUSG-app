import Foundation

/// Volume prostático pela fórmula do elipsoide (W × H × L × 0,523).
/// Útil em ultrassom transretal e suprapúbico. PSA density = PSA / volume
/// (≥ 0,15 ng/mL/cc associado a maior risco de Ca prostático clinicamente significativo).
enum VolumeProstaticoCalculator {
    struct VPInput: Sendable, Hashable {
        let widthCm: Double      // L1 (transverso)
        let heightCm: Double     // L2 (AP)
        let lengthCm: Double     // L3 (cranio-caudal)
        let psaNgPerMl: Double?  // opcional
    }

    enum Classification: String, Sendable {
        case normal
        case levementeAumentado
        case moderadamenteAumentado
        case acentuadamenteAumentado

        var label: String {
            switch self {
            case .normal: return "Volume dentro da normalidade"
            case .levementeAumentado: return "Próstata levemente aumentada"
            case .moderadamenteAumentado: return "Próstata moderadamente aumentada"
            case .acentuadamenteAumentado: return "Próstata acentuadamente aumentada"
            }
        }
    }

    struct VPResult: Sendable, Hashable {
        let volumeCc: Double
        let classification: Classification
        let psaDensity: Double?
        let psaDensityElevated: Bool
        let insertBloco: String
    }

    static func calculate(_ input: VPInput) -> VPResult? {
        guard input.widthCm > 0, input.heightCm > 0, input.lengthCm > 0 else { return nil }
        let vol = input.widthCm * input.heightCm * input.lengthCm * 0.523

        let cls: Classification
        if vol < 30 { cls = .normal }
        else if vol < 50 { cls = .levementeAumentado }
        else if vol < 80 { cls = .moderadamenteAumentado }
        else { cls = .acentuadamenteAumentado }

        var density: Double? = nil
        var densityElevated = false
        if let psa = input.psaNgPerMl, psa > 0, vol > 0 {
            density = psa / vol
            densityElevated = (density ?? 0) >= 0.15
        }

        let dims = String(format: "%.1f × %.1f × %.1f", input.widthCm, input.heightCm, input.lengthCm)
            .replacingOccurrences(of: ".", with: ",")
        let volFmt = String(format: "%.1f", vol).replacingOccurrences(of: ".", with: ",")

        var bloco = """
        Próstata com dimensões de \(dims) cm.
        Volume calculado (elipsoide): \(volFmt) cm³.

        Conclusão: \(cls.label).
        """

        if let d = density {
            let dFmt = String(format: "%.2f", d).replacingOccurrences(of: ".", with: ",")
            let psaFmt = String(format: "%.2f", input.psaNgPerMl ?? 0).replacingOccurrences(of: ".", with: ",")
            let suffix = densityElevated ? " — acima do limiar de 0,15 ng/mL/cc (sugere maior risco de Ca clinicamente significativo)." : "."
            bloco += "\n\nPSA: \(psaFmt) ng/mL — densidade do PSA: \(dFmt) ng/mL/cc\(suffix)"
        }

        return VPResult(
            volumeCc: vol,
            classification: cls,
            psaDensity: density,
            psaDensityElevated: densityElevated,
            insertBloco: bloco
        )
    }
}
