import Foundation

enum DopplerCalculator {
    typealias IGResult = GestationalAgeCalculator.IGResult

    struct DopplerInput: Sendable, Hashable {
        let weeks: Int
        let days: Int
        let ipUmbilical: Double
        let ipMCA: Double
        let ipUterinaDireita: Double
        let ipUterinaEsquerda: Double
    }

    struct VesselResult: Sendable, Hashable {
        let ip: Double
        let zscore: Double
        let percentile: Double
        let pathological: Bool
    }

    struct UterineVesselResult: Sendable, Hashable {
        let ip: Double
        let ipMedio: Double
        let zscore: Double
        let percentile: Double
        let pathological: Bool
    }

    struct DopplerResult: Sendable, Hashable {
        let arteriaUmbilical: VesselResult
        let arteriaCerebralMedia: VesselResult
        let arteriasUterinas: UterineVesselResult
        let ratioCerebroplacentario: VesselResult
    }

    static func calculate(_ input: DopplerInput) -> DopplerResult {
        let ga = Double(input.weeks) + Double(input.days) / 7
        let arteriaUmbilical = calcArteriaUmbilical(ga: ga, ip: input.ipUmbilical)
        let arteriaCerebralMedia = calcArteriaCerebralMedia(ga: ga, ip: input.ipMCA)
        let arteriasUterinas = calcArteriasUterinas(
            weeks: input.weeks,
            days: input.days,
            ipDireita: input.ipUterinaDireita,
            ipEsquerda: input.ipUterinaEsquerda
        )
        let ratioCerebroplacentario = calcRatioCerebroplacentario(
            ga: ga,
            ipMCA: input.ipMCA,
            ipUA: input.ipUmbilical
        )

        return aplicarCorrecoesClinicas(
            DopplerResult(
                arteriaUmbilical: arteriaUmbilical,
                arteriaCerebralMedia: arteriaCerebralMedia,
                arteriasUterinas: arteriasUterinas,
                ratioCerebroplacentario: ratioCerebroplacentario
            )
        )
    }

    static func insertBloco(from result: DopplerResult, ig: IGResult) -> String {
        """
        Doppler obstétrico (IG: \(ig.weeks) semanas\(ig.days > 0 ? " e \(ig.days) dias" : "")):
        - Artéria umbilical: IP \(fmt(result.arteriaUmbilical.ip)) (p\(pct(result.arteriaUmbilical.percentile)), \(status(result.arteriaUmbilical.pathological)))
        - Artéria cerebral média: IP \(fmt(result.arteriaCerebralMedia.ip)) (p\(pct(result.arteriaCerebralMedia.percentile)), \(status(result.arteriaCerebralMedia.pathological)))
        - Artérias uterinas (IP médio \(fmt(result.arteriasUterinas.ipMedio))): p\(pct(result.arteriasUterinas.percentile)), \(status(result.arteriasUterinas.pathological))
        - Ratio cerebroplacentário: \(fmt(result.ratioCerebroplacentario.ip)) (p\(pct(result.ratioCerebroplacentario.percentile)), \(status(result.ratioCerebroplacentario.pathological)))
        """
    }

    private static let zTable: [(z: Double, percentile: Double)] = [
        (-3.719, 0.01), (-3.09, 0.1), (-2.576, 0.5), (-2.326, 1), (-2.054, 2),
        (-1.96, 2.5), (-1.881, 3), (-1.751, 4), (-1.645, 5), (-1.555, 6),
        (-1.476, 7), (-1.405, 8), (-1.341, 9), (-1.282, 10), (-1.227, 11),
        (-1.175, 12), (-1.126, 13), (-1.08, 14), (-1.036, 15), (-0.994, 16),
        (-0.954, 17), (-0.915, 18), (-0.878, 19), (-0.842, 20), (-0.806, 21),
        (-0.772, 22), (-0.739, 23), (-0.706, 24), (-0.674, 25), (-0.643, 26),
        (-0.613, 27), (-0.583, 28), (-0.553, 29), (-0.524, 30), (-0.496, 31),
        (-0.468, 32), (-0.44, 33), (-0.412, 34), (-0.385, 35), (-0.358, 36),
        (-0.332, 37), (-0.305, 38), (-0.279, 39), (-0.253, 40), (-0.228, 41),
        (-0.202, 42), (-0.176, 43), (-0.151, 44), (-0.126, 45), (-0.1, 46),
        (-0.075, 47), (-0.05, 48), (-0.025, 49), (0, 50), (0.025, 51),
        (0.05, 52), (0.075, 53), (0.1, 54), (0.126, 55), (0.151, 56),
        (0.176, 57), (0.202, 58), (0.228, 59), (0.253, 60), (0.279, 61),
        (0.305, 62), (0.332, 63), (0.358, 64), (0.385, 65), (0.412, 66),
        (0.44, 67), (0.468, 68), (0.496, 69), (0.524, 70), (0.553, 71),
        (0.583, 72), (0.613, 73), (0.643, 74), (0.674, 75), (0.706, 76),
        (0.739, 77), (0.772, 78), (0.806, 79), (0.842, 80), (0.878, 81),
        (0.915, 82), (0.954, 83), (0.994, 84), (1.036, 85), (1.08, 86),
        (1.126, 87), (1.175, 88), (1.227, 89), (1.282, 90), (1.341, 91),
        (1.405, 92), (1.476, 93), (1.555, 94), (1.645, 95), (1.751, 96),
        (1.881, 97), (1.96, 97.5), (2.054, 98), (2.326, 99), (2.576, 99.5),
        (3.09, 99.9), (3.719, 99.99),
    ]

    static func zToPercentile(_ z: Double) -> Double {
        guard let first = zTable.first, let last = zTable.last else { return 50 }
        if z <= first.z { return first.percentile }
        if z >= last.z { return last.percentile }

        for index in 0..<(zTable.count - 1) {
            let a = zTable[index]
            let b = zTable[index + 1]
            if z >= a.z && z < b.z {
                let t = (z - a.z) / (b.z - a.z)
                let p = a.percentile + t * (b.percentile - a.percentile)
                return p.rounded()
            }
        }

        return 50
    }

    private static func calcArteriaUmbilical(ga: Double, ip: Double) -> VesselResult {
        let mean = 3.55219 - 0.13558 * ga + 0.00174 * ga * ga
        let sd = 0.299
        let zscore = (ip - mean) / sd
        return VesselResult(ip: ip, zscore: zscore, percentile: zToPercentile(zscore), pathological: zscore > 1.645)
    }

    private static func calcArteriaCerebralMedia(ga: Double, ip: Double) -> VesselResult {
        let mean = -2.7317 + 0.3335 * ga - 0.0058 * ga * ga
        let sd = -0.88005 + 0.08182 * ga - 0.00133 * ga * ga
        let zscore = (ip - mean) / sd
        return VesselResult(ip: ip, zscore: zscore, percentile: zToPercentile(zscore), pathological: zscore < -1.645)
    }

    private static func calcArteriasUterinas(
        weeks: Int,
        days: Int,
        ipDireita: Double,
        ipEsquerda: Double
    ) -> UterineVesselResult {
        let totalDays = weeks * 7 + days
        let ipMedio = (ipDireita + ipEsquerda) / 2
        let logMedio = log(ipMedio)
        let meanLog = 1.39 - 0.012 * Double(totalDays) + 1.98e-5 * Double(totalDays) * Double(totalDays)
        let sdLog = 0.272 - 0.000259 * Double(totalDays)
        let zscore = (logMedio - meanLog) / sdLog
        return UterineVesselResult(
            ip: ipMedio,
            ipMedio: ipMedio,
            zscore: zscore,
            percentile: zToPercentile(zscore),
            pathological: zscore > 1.645
        )
    }

    private static func calcRatioCerebroplacentario(ga: Double, ipMCA: Double, ipUA: Double) -> VesselResult {
        let ratio = ipMCA / ipUA
        let mean = -4.0636 + 0.383 * ga - 0.0059 * ga * ga
        let sd = -0.9664 + 0.09027 * ga - 0.0014 * ga * ga
        let zscore = (ratio - mean) / sd
        return VesselResult(ip: ratio, zscore: zscore, percentile: zToPercentile(zscore), pathological: zscore < -1.645)
    }

    private static func aplicarCorrecoesClinicas(_ result: DopplerResult) -> DopplerResult {
        let uaAlterada = result.arteriaUmbilical.pathological
        let auCorrigida = result.arteriaUmbilical.percentile < 10
            ? VesselResult(ip: result.arteriaUmbilical.ip, zscore: result.arteriaUmbilical.zscore, percentile: 5, pathological: false)
            : result.arteriaUmbilical
        let acmCorrigida = !uaAlterada && result.arteriaCerebralMedia.pathological
            ? VesselResult(ip: result.arteriaCerebralMedia.ip, zscore: result.arteriaCerebralMedia.zscore, percentile: 5, pathological: false)
            : result.arteriaCerebralMedia
        let rcpCorrigido = !uaAlterada && result.ratioCerebroplacentario.pathological
            ? VesselResult(ip: result.ratioCerebroplacentario.ip, zscore: result.ratioCerebroplacentario.zscore, percentile: 5, pathological: false)
            : result.ratioCerebroplacentario

        return DopplerResult(
            arteriaUmbilical: auCorrigida,
            arteriaCerebralMedia: acmCorrigida,
            arteriasUterinas: result.arteriasUterinas,
            ratioCerebroplacentario: rcpCorrigido
        )
    }

    static func fmt(_ value: Double, decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", value)
    }

    static func pct(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : fmt(value, decimals: 1)
    }

    private static func status(_ pathological: Bool) -> String {
        pathological ? "ALTERADO" : "dentro do esperado"
    }
}
