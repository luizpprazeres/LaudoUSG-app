import Foundation

enum HistoryService {
    enum ReviewError: Error, LocalizedError {
        case textChanged
        case revisionUnavailable
        case invalidResponse
        case conflict

        var errorDescription: String? {
            switch self {
            case .textChanged:
                return "O texto salvo não corresponde ao que está visível. Aguarde o salvamento e confira o laudo antes de revisar."
            case .revisionUnavailable:
                return "Não foi possível confirmar a versão atual do laudo. Tente novamente."
            case .invalidResponse:
                return "O servidor não confirmou a revisão médica. Tente novamente."
            case .conflict:
                return "O laudo mudou enquanto você revisava. Confira o texto atualizado e revise novamente para liberar à Sala."
            }
        }
    }

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

    /// Confirma a revisão apenas da versão que acabou de ser lida do servidor.
    /// O texto esperado não é registrado; o backend recebe a revisão e compara
    /// novamente dentro da operação atômica.
    static func reviewReport(id: String, expectedText: String) async throws -> ReportReviewResponse {
        let persisted = try await fetchReport(id: id)
        let persistedText = persisted.finalOutput ?? persisted.generatedOutput ?? ""
        guard persistedText == expectedText else { throw ReviewError.textChanged }
        guard let revision = persisted.contentRevision else { throw ReviewError.revisionUnavailable }

        do {
            let body = try JSONEncoder().encode(ReportReviewRequest(expectedRevision: revision, expectedText: expectedText))
            let data = try await APIClient.shared.postRawJSON("/api/reports/\(id)/review", body: body)
            let response: ReportReviewResponse
            do {
                response = try JSONDecoder.api.decode(ReportReviewResponse.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
            guard response.ok,
                  response.reviewStatus == .reviewed,
                  response.contentRevision == revision else {
                throw ReviewError.invalidResponse
            }
            return response
        } catch APIError.http(status: 409, body: _) {
            throw ReviewError.conflict
        }
    }

    static func updateFinalOutput(reportId: String, finalText: String) async throws {
        try await SupabaseRESTClient.shared.patch(
            "/rest/v1/reports",
            query: ["id": "eq.\(reportId)"],
            body: ReportFinalOutputUpdate(finalOutput: finalText, updatedAt: Date())
        )
    }

    static func deleteReports(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        let csv = ids.joined(separator: ",")
        try await SupabaseRESTClient.shared.delete(
            "/rest/v1/reports",
            query: ["id": "in.(\(csv))"]
        )
    }
}

private struct ReportEnvelope: Decodable {
    let report: Report
}

struct ReportReviewRequest: Encodable {
    let expectedRevision: Int
    let expectedText: String
}

struct ReportReviewResponse: Decodable {
    let ok: Bool
    let contentRevision: Int
    let reviewStatus: ReportReviewStatus
    let reviewedAt: Date
}

private struct ReportFinalOutputUpdate: Encodable {
    let finalOutput: String
    let updatedAt: Date
}
