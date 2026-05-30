import Foundation

struct PercentileBand: Sendable, Hashable {
    let p3: Double
    let p10: Double
    let p50: Double
    let p90: Double
    let p97: Double
}

enum IntergrowthTable {
    static let version = "intergrowth21st-2016-stirnemann"
    static let supportsSexSpecific = false

    static let unisex: [Int: PercentileBand] = [
        22: PercentileBand(p3: 463, p10: 481, p50: 525, p90: 578, p97: 607),
        23: PercentileBand(p3: 516, p10: 538, p50: 592, p90: 658, p97: 694),
        24: PercentileBand(p3: 575, p10: 602, p50: 668, p90: 751, p97: 796),
        25: PercentileBand(p3: 642, p10: 675, p50: 756, p90: 857, p97: 913),
        26: PercentileBand(p3: 716, p10: 757, p50: 856, p90: 980, p97: 1048),
        27: PercentileBand(p3: 800, p10: 848, p50: 969, p90: 1119, p97: 1202),
        28: PercentileBand(p3: 892, p10: 951, p50: 1097, p90: 1277, p97: 1376),
        29: PercentileBand(p3: 994, p10: 1064, p50: 1239, p90: 1453, p97: 1570),
        30: PercentileBand(p3: 1105, p10: 1189, p50: 1396, p90: 1648, p97: 1784),
        31: PercentileBand(p3: 1226, p10: 1325, p50: 1568, p90: 1861, p97: 2017),
        32: PercentileBand(p3: 1356, p10: 1472, p50: 1755, p90: 2090, p97: 2267),
        33: PercentileBand(p3: 1495, p10: 1630, p50: 1954, p90: 2332, p97: 2529),
        34: PercentileBand(p3: 1641, p10: 1796, p50: 2162, p90: 2582, p97: 2798),
        35: PercentileBand(p3: 1794, p10: 1969, p50: 2378, p90: 2836, p97: 3069),
        36: PercentileBand(p3: 1951, p10: 2146, p50: 2594, p90: 3086, p97: 3331),
        37: PercentileBand(p3: 2109, p10: 2323, p50: 2806, p90: 3324, p97: 3578),
        38: PercentileBand(p3: 2266, p10: 2496, p50: 3006, p90: 3540, p97: 3798),
        39: PercentileBand(p3: 2416, p10: 2658, p50: 3186, p90: 3726, p97: 3982),
        40: PercentileBand(p3: 2554, p10: 2805, p50: 3338, p90: 3871, p97: 4121),
    ]

    static func lookup(igWeeks: Int, igDays: Int) -> PercentileBand? {
        let totalDays = igWeeks * 7 + igDays
        let clampedWeek = max(22, min(40, totalDays / 7))
        let fraction = Double(totalDays - clampedWeek * 7) / 7
        guard let band = unisex[clampedWeek] else { return nil }
        if fraction == 0 { return band }
        guard clampedWeek < 40, let nextBand = unisex[clampedWeek + 1] else { return band }
        return interpolate(band, nextBand, fraction: fraction)
    }

    static func percentileFor(weight: Int, igWeeks: Int, igDays: Int) -> Int {
        guard let band = lookup(igWeeks: igWeeks, igDays: igDays) else { return 50 }
        return PercentileMath.percentileFor(weight: weight, band: band)
    }

    private static func interpolate(
        _ a: PercentileBand,
        _ b: PercentileBand,
        fraction: Double
    ) -> PercentileBand {
        PercentileBand(
            p3: a.p3 + (b.p3 - a.p3) * fraction,
            p10: a.p10 + (b.p10 - a.p10) * fraction,
            p50: a.p50 + (b.p50 - a.p50) * fraction,
            p90: a.p90 + (b.p90 - a.p90) * fraction,
            p97: a.p97 + (b.p97 - a.p97) * fraction
        )
    }
}

enum PercentileMath {
    static func percentileFor(weight: Int, band: PercentileBand) -> Int {
        let sigma = (band.p90 - band.p10) / 2.5631
        guard sigma > 0 else { return 50 }
        let z = (Double(weight) - band.p50) / sigma
        return Int(DopplerCalculator.zToPercentile(z).rounded())
    }

    static func label(_ p: Int) -> String {
        if p < 3 { return "percentil < 3" }
        if p > 97 { return "percentil > 97" }
        return "percentil \(p)"
    }
}
