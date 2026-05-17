import Foundation

struct AnalyticsSummary: Codable, Sendable {
    let totalReports: Int
    let reportsLast7d: Int
    let reportsLast30d: Int
    let avgLatencyMs: Int?
    let topCategories: [CategoryStat]
    let totalCostUsd: Double
    let editsRatio: Double
}

struct CategoryStat: Codable, Sendable, Identifiable {
    let code: String
    let label: String
    let count: Int

    var id: String { code }
}
