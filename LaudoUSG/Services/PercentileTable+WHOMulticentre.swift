import Foundation

enum WHOMulticentreTable {
    static let version = "who-multicentre-kiserud-2017-PENDING-CURATION"
    static let supportsSexSpecific = true

    static let unisex: [Int: PercentileBand] = [:]
    static let boys: [Int: PercentileBand] = [:]
    static let girls: [Int: PercentileBand] = [:]

    static func lookup(igWeeks: Int, igDays: Int, sex: Sex) -> PercentileBand? {
        let table: [Int: PercentileBand]
        switch sex {
        case .male: table = boys.isEmpty ? unisex : boys
        case .female: table = girls.isEmpty ? unisex : girls
        case .unisex: table = unisex
        }
        guard !table.isEmpty else { return nil }
        let totalDays = igWeeks * 7 + igDays
        let clampedWeek = max(14, min(40, totalDays / 7))
        return table[clampedWeek]
    }

    static func usedSex(requested: Sex) -> Sex {
        switch requested {
        case .male: boys.isEmpty ? .unisex : .male
        case .female: girls.isEmpty ? .unisex : .female
        case .unisex: .unisex
        }
    }
}
