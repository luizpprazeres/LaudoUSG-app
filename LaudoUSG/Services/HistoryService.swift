import Foundation

enum HistoryService {
    static func fetchRecentReports(limit: Int = 50) async throws -> [Report] {
        try await SupabaseRESTClient.shared.get(
            "/rest/v1/reports",
            query: [
                "select": "id,category_code,status,generated_output,final_output,raw_input,created_at,updated_at",
                "order": "created_at.desc",
                "limit": "\(limit)"
            ],
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
