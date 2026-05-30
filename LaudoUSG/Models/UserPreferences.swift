import Foundation

struct UserPreferences: Codable, Sendable, Equatable {
    var weightFormula: WeightFormula = .hadlock4_1985
    var percentileSource: PercentileSource = .intergrowth21st

    static let `default` = UserPreferences()
}
