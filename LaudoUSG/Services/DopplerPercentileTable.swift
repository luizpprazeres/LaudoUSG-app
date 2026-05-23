import Foundation

public enum DopplerArtery: Sendable, Equatable {
    case umbilical
    case cerebralMedia
    case uterinasMedia
    case ductoVenoso
}

public struct PercentileResult: Sendable, Equatable {
    public let artery: DopplerArtery
    public let measuredIP: Double
    public let p5: Double
    public let p50: Double
    public let p95: Double
    public let estimatedPercentile: String

    public init(
        artery: DopplerArtery,
        measuredIP: Double,
        p5: Double,
        p50: Double,
        p95: Double,
        estimatedPercentile: String
    ) {
        self.artery = artery
        self.measuredIP = measuredIP
        self.p5 = p5
        self.p50 = p50
        self.p95 = p95
        self.estimatedPercentile = estimatedPercentile
    }
}

public enum DopplerPercentileTable {
    public static func calculate(artery: DopplerArtery, ip: Double, igWeeks: Int) -> PercentileResult? {
        guard let range = table(for: artery)[igWeeks] else { return nil }

        return PercentileResult(
            artery: artery,
            measuredIP: ip,
            p5: range.p5,
            p50: range.p50,
            p95: range.p95,
            estimatedPercentile: estimatedPercentile(for: ip, range: range)
        )
    }

    private struct Range: Sendable {
        let p5: Double
        let p50: Double
        let p95: Double
    }

    private static func table(for artery: DopplerArtery) -> [Int: Range] {
        switch artery {
        case .umbilical:
            return umbilical
        case .cerebralMedia:
            return cerebralMedia
        case .uterinasMedia:
            return uterinasMedia
        case .ductoVenoso:
            return [:]
        }
    }

    private static func estimatedPercentile(for ip: Double, range: Range) -> String {
        let tolerance = 0.0005

        if ip < range.p5 - tolerance { return "<P5" }
        if ip > range.p95 + tolerance { return ">P95" }
        if abs(ip - range.p5) <= tolerance { return "P5" }
        if abs(ip - range.p50) <= tolerance { return "P50" }
        if abs(ip - range.p95) <= tolerance { return "P95" }

        // P5/P95 cobrem ±1.6449σ na curva normal; reusa zTable do DopplerCalculator
        // pra mapear z → percentil contínuo (P6..P94).
        let sigma = (range.p95 - range.p5) / (2 * 1.6449)
        guard sigma > 0 else { return "P50" }
        let z = (ip - range.p50) / sigma
        let p = DopplerCalculator.zToPercentile(z)
        let rounded = Int(p.rounded())
        if rounded <= 5 { return "P5" }
        if rounded >= 95 { return "P95" }
        return "P\(rounded)"
    }

    // Weekly p5, p50 and p95 derived from the Fetal Medicine Barcelona/FMF formulas already used by DopplerCalculator for UA PI.
    private static let umbilical: [Int: Range] = [
        20: Range(p5: 1.045, p50: 1.537, p95: 2.028),
        21: Range(p5: 0.980, p50: 1.472, p95: 1.964),
        22: Range(p5: 0.920, p50: 1.412, p95: 1.903),
        23: Range(p5: 0.862, p50: 1.354, p95: 1.846),
        24: Range(p5: 0.809, p50: 1.301, p95: 1.792),
        25: Range(p5: 0.758, p50: 1.250, p95: 1.742),
        26: Range(p5: 0.711, p50: 1.203, p95: 1.695),
        27: Range(p5: 0.668, p50: 1.160, p95: 1.652),
        28: Range(p5: 0.628, p50: 1.120, p95: 1.612),
        29: Range(p5: 0.592, p50: 1.084, p95: 1.576),
        30: Range(p5: 0.559, p50: 1.051, p95: 1.543),
        31: Range(p5: 0.529, p50: 1.021, p95: 1.513),
        32: Range(p5: 0.504, p50: 0.995, p95: 1.487),
        33: Range(p5: 0.481, p50: 0.973, p95: 1.465),
        34: Range(p5: 0.462, p50: 0.954, p95: 1.446),
        35: Range(p5: 0.447, p50: 0.938, p95: 1.430),
        36: Range(p5: 0.434, p50: 0.926, p95: 1.418),
        37: Range(p5: 0.426, p50: 0.918, p95: 1.410),
        38: Range(p5: 0.421, p50: 0.913, p95: 1.405),
        39: Range(p5: 0.419, p50: 0.911, p95: 1.403),
        40: Range(p5: 0.421, p50: 0.913, p95: 1.405),
        41: Range(p5: 0.426, p50: 0.918, p95: 1.410),
    ]

    // Weekly p5, p50 and p95 derived from the Fetal Medicine Barcelona/FMF formulas already used by DopplerCalculator for MCA PI.
    private static let cerebralMedia: [Int: Range] = [
        20: Range(p5: 1.249, p50: 1.618, p95: 1.987),
        21: Range(p5: 1.300, p50: 1.714, p95: 2.128),
        22: Range(p5: 1.344, p50: 1.798, p95: 2.253),
        23: Range(p5: 1.380, p50: 1.871, p95: 2.361),
        24: Range(p5: 1.409, p50: 1.932, p95: 2.454),
        25: Range(p5: 1.431, p50: 1.981, p95: 2.531),
        26: Range(p5: 1.446, p50: 2.019, p95: 2.591),
        27: Range(p5: 1.453, p50: 2.045, p95: 2.636),
        28: Range(p5: 1.453, p50: 2.059, p95: 2.665),
        29: Range(p5: 1.446, p50: 2.062, p95: 2.678),
        30: Range(p5: 1.432, p50: 2.053, p95: 2.674),
        31: Range(p5: 1.411, p50: 2.033, p95: 2.655),
        32: Range(p5: 1.382, p50: 2.001, p95: 2.620),
        33: Range(p5: 1.346, p50: 1.958, p95: 2.569),
        34: Range(p5: 1.303, p50: 1.903, p95: 2.502),
        35: Range(p5: 1.253, p50: 1.836, p95: 2.419),
        36: Range(p5: 1.195, p50: 1.758, p95: 2.320),
        37: Range(p5: 1.130, p50: 1.668, p95: 2.205),
        38: Range(p5: 1.058, p50: 1.566, p95: 2.074),
        39: Range(p5: 0.979, p50: 1.453, p95: 1.927),
        40: Range(p5: 0.893, p50: 1.328, p95: 1.764),
        41: Range(p5: 0.799, p50: 1.192, p95: 1.585),
    ]

    // Weekly p5, p50 and p95 derived from the Fetal Medicine Barcelona/FMF formulas already used by DopplerCalculator for mean uterine artery PI.
    private static let uterinasMedia: [Int: Range] = [
        20: Range(p5: 0.748, p50: 1.103, p95: 1.626),
        21: Range(p5: 0.718, p50: 1.055, p95: 1.551),
        22: Range(p5: 0.691, p50: 1.012, p95: 1.482),
        23: Range(p5: 0.665, p50: 0.972, p95: 1.419),
        24: Range(p5: 0.642, p50: 0.935, p95: 1.362),
        25: Range(p5: 0.621, p50: 0.902, p95: 1.309),
        26: Range(p5: 0.602, p50: 0.871, p95: 1.261),
        27: Range(p5: 0.584, p50: 0.843, p95: 1.217),
        28: Range(p5: 0.568, p50: 0.818, p95: 1.177),
        29: Range(p5: 0.554, p50: 0.794, p95: 1.140),
        30: Range(p5: 0.541, p50: 0.774, p95: 1.106),
        31: Range(p5: 0.529, p50: 0.755, p95: 1.076),
        32: Range(p5: 0.519, p50: 0.737, p95: 1.049),
        33: Range(p5: 0.509, p50: 0.722, p95: 1.024),
        34: Range(p5: 0.501, p50: 0.709, p95: 1.002),
        35: Range(p5: 0.494, p50: 0.697, p95: 0.982),
        36: Range(p5: 0.488, p50: 0.686, p95: 0.964),
        37: Range(p5: 0.483, p50: 0.677, p95: 0.949),
        38: Range(p5: 0.479, p50: 0.670, p95: 0.935),
        39: Range(p5: 0.476, p50: 0.663, p95: 0.924),
        40: Range(p5: 0.474, p50: 0.659, p95: 0.914),
        41: Range(p5: 0.473, p50: 0.655, p95: 0.907),
    ]
}
