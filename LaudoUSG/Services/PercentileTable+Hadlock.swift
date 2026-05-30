import Foundation

enum HadlockTable {
    static let version = "hadlock-1991-gardosi-mikolajczyk-2011"
    static let supportsSexSpecific = false

    static let unisex: [Int: PercentileBand] = [
        24: PercentileBand(p3: 537, p10: 582, p50: 678, p90: 775, p97: 820),
        25: PercentileBand(p3: 627, p10: 680, p50: 792, p90: 905, p97: 957),
        26: PercentileBand(p3: 727, p10: 788, p50: 918, p90: 1049, p97: 1110),
        27: PercentileBand(p3: 837, p10: 907, p50: 1057, p90: 1207, p97: 1278),
        28: PercentileBand(p3: 957, p10: 1037, p50: 1209, p90: 1380, p97: 1460),
        29: PercentileBand(p3: 1086, p10: 1177, p50: 1372, p90: 1567, p97: 1658),
        30: PercentileBand(p3: 1224, p10: 1327, p50: 1546, p90: 1766, p97: 1868),
        31: PercentileBand(p3: 1370, p10: 1485, p50: 1730, p90: 1976, p97: 2091),
        32: PercentileBand(p3: 1522, p10: 1650, p50: 1923, p90: 2196, p97: 2323),
        33: PercentileBand(p3: 1679, p10: 1820, p50: 2121, p90: 2423, p97: 2563),
        34: PercentileBand(p3: 1840, p10: 1994, p50: 2324, p90: 2654, p97: 2808),
        35: PercentileBand(p3: 2002, p10: 2169, p50: 2528, p90: 2887, p97: 3055),
        36: PercentileBand(p3: 2162, p10: 2343, p50: 2731, p90: 3119, p97: 3300),
        37: PercentileBand(p3: 2319, p10: 2513, p50: 2929, p90: 3345, p97: 3540),
        38: PercentileBand(p3: 2470, p10: 2677, p50: 3120, p90: 3562, p97: 3770),
        39: PercentileBand(p3: 2612, p10: 2831, p50: 3299, p90: 3767, p97: 3986),
        40: PercentileBand(p3: 2742, p10: 2972, p50: 3464, p90: 3956, p97: 4186),
        41: PercentileBand(p3: 2859, p10: 3099, p50: 3611, p90: 4124, p97: 4364),
    ]

    static func lookup(igWeeks: Int, igDays: Int) -> PercentileBand? {
        let totalDays = igWeeks * 7 + igDays
        let clampedWeek = max(24, min(41, totalDays / 7))
        let fraction = Double(totalDays - clampedWeek * 7) / 7
        guard let band = unisex[clampedWeek] else { return nil }
        if fraction == 0 { return band }
        guard clampedWeek < 41, let nextBand = unisex[clampedWeek + 1] else { return band }
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
