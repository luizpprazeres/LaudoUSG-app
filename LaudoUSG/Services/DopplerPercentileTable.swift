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
    public static func calculate(
        artery: DopplerArtery,
        ip: Double,
        igWeeks: Int,
        igDays: Int = 0
    ) -> PercentileResult? {
        guard ip > 0,
              (0...6).contains(igDays),
              let formula = formulaValues(for: artery, ip: ip, igWeeks: igWeeks, igDays: igDays)
        else { return nil }
        let percentile = DopplerCalculator.barcelonaDopplerPercentile(formula.z).label
        let estimated: String
        if percentile == "<1" { estimated = "<P1" }
        else if percentile == ">99" { estimated = ">P99" }
        else { estimated = "P\(percentile)" }

        return PercentileResult(
            artery: artery,
            measuredIP: ip,
            p5: formula.range.p5,
            p50: formula.range.p50,
            p95: formula.range.p95,
            estimatedPercentile: estimated
        )
    }

    private struct Range: Sendable {
        let p5: Double
        let p50: Double
        let p95: Double
    }

    private static func formulaValues(
        for artery: DopplerArtery,
        ip: Double,
        igWeeks: Int,
        igDays: Int
    ) -> (range: Range, z: Double)? {
        let ga = Double(igWeeks) + Double(igDays) / 7.0
        switch artery {
        case .umbilical:
            guard (20...44).contains(igWeeks) else { return nil }
            let mean = 3.55219 - 0.13558 * ga + 0.00174 * ga * ga
            let sd = 0.299
            return (Range(p5: mean - 1.645 * sd, p50: mean, p95: mean + 1.645 * sd), (ip - mean) / sd)
        case .cerebralMedia:
            guard (20...44).contains(igWeeks) else { return nil }
            let mean = -2.7317 + 0.3335 * ga - 0.0058 * ga * ga
            let sd = -0.88005 + 0.08182 * ga - 0.00133 * ga * ga
            return (Range(p5: mean - 1.645 * sd, p50: mean, p95: mean + 1.645 * sd), (ip - mean) / sd)
        case .uterinasMedia:
            guard (11...44).contains(igWeeks) else { return nil }
            let totalDays = Double(igWeeks * 7 + igDays)
            let meanLog = 1.39 - 0.012 * totalDays + 1.98e-5 * totalDays * totalDays
            let sdLog = 0.272 - 0.000259 * totalDays
            let range = Range(
                p5: exp(meanLog - 1.645 * sdLog),
                p50: exp(meanLog),
                p95: exp(meanLog + 1.645 * sdLog)
            )
            return (range, (log(ip) - meanLog) / sdLog)
        case .ductoVenoso:
            guard (20...44).contains(igWeeks) else { return nil }
            let mean = 0.903 - 0.0116 * ga
            let sd = 0.1483
            return (Range(p5: mean - 1.645 * sd, p50: mean, p95: mean + 1.645 * sd), (ip - mean) / sd)
        }
    }

}
