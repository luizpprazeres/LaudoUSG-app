import Foundation

enum HistoryService {
    static func fetchRecentReports(filter: HistoryFilter = HistoryFilter(), limit: Int = 50) async throws -> [Report] {
        var query: [String: String] = [
            "select": "id,category_code,status,generated_output,final_output,raw_input,created_at,updated_at",
            "order": "created_at.desc",
            "limit": "\(limit)"
        ]

        if let start = filter.dateRange.startDate() {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query["created_at"] = "gte.\(iso.string(from: start))"
        }

        if !filter.categories.isEmpty {
            let csv = filter.categories.map { $0.rawValue }.sorted().joined(separator: ",")
            query["category_code"] = "in.(\(csv))"
        }

        return try await SupabaseRESTClient.shared.get(
            "/rest/v1/reports",
            query: query,
            as: [Report].self
        )
    }

    static func fetchReport(id: String) async throws -> Report {
        let envelope = try await APIClient.shared.get("/api/reports/\(id)", as: ReportEnvelope.self)
        return envelope.report
    }

    static func updateFinalOutput(reportId: String, finalText: String) async throws {
        try await SupabaseRESTClient.shared.patch(
            "/rest/v1/reports",
            query: ["id": "eq.\(reportId)"],
            body: ReportFinalOutputUpdate(finalOutput: finalText, updatedAt: Date())
        )
    }
}

private struct ReportEnvelope: Decodable {
    let report: Report
}

private struct ReportFinalOutputUpdate: Encodable {
    let finalOutput: String
    let updatedAt: Date
}
