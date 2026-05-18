import Foundation

struct AnalyticsSummary: Codable, Sendable {
    let totalReports: Int
    let reportsLast7d: Int
    let reportsLast30d: Int
    let avgLatencyMs: Int?
    let topCategories: [CategoryStat]
    let totalCostUsd: Double
    let editsRatio: Double

    init(
        totalReports: Int,
        reportsLast7d: Int,
        reportsLast30d: Int,
        avgLatencyMs: Int?,
        topCategories: [CategoryStat],
        totalCostUsd: Double,
        editsRatio: Double
    ) {
        self.totalReports = totalReports
        self.reportsLast7d = reportsLast7d
        self.reportsLast30d = reportsLast30d
        self.avgLatencyMs = avgLatencyMs
        self.topCategories = topCategories
        self.totalCostUsd = totalCostUsd
        self.editsRatio = editsRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalReports = try container.decodeIfPresent(Int.self, forKey: .totalReports) ?? 0
        reportsLast7d = try container.decodeIfPresent(Int.self, forKey: .reportsLast7d) ?? 0
        reportsLast30d = try container.decodeIfPresent(Int.self, forKey: .reportsLast30d) ?? 0
        avgLatencyMs = try container.decodeIfPresent(Int.self, forKey: .avgLatencyMs)
        topCategories = try container.decodeIfPresent([CategoryStat].self, forKey: .topCategories) ?? []
        totalCostUsd = try container.decodeIfPresent(Double.self, forKey: .totalCostUsd) ?? 0
        editsRatio = try container.decodeIfPresent(Double.self, forKey: .editsRatio) ?? 0
    }
}

struct CategoryStat: Codable, Sendable, Identifiable {
    let code: String
    let label: String
    let count: Int

    var id: String { code }

    init(code: String, label: String, count: Int) {
        self.code = code
        self.label = label
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCode = try container.decodeIfPresent(String.self, forKey: .code)
            ?? container.decodeIfPresent(String.self, forKey: .categoryCode)
            ?? "DESCONHECIDO"
        code = decodedCode
        label = try container.decodeIfPresent(String.self, forKey: .label)
            ?? ReportCategory(rawValue: decodedCode)?.label
            ?? decodedCode
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(label, forKey: .label)
        try container.encode(count, forKey: .count)
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case categoryCode
        case label
        case count
    }
}
