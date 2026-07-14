import Foundation

enum ReportService {
    static func generateStream(request: GenerateRequest) async throws -> AsyncThrowingStream<GenerateSSEEvent, Error> {
        let body = try JSONEncoder.api.encode(request)
        let bytes = try await APIClient.shared.streamSSE(path: "/api/generate", body: body)
        return SSEStreamer.stream(from: bytes)
    }

    /// Ajuste pontual de laudo pronto via linguagem natural (edição incremental).
    /// O servedor edita SEMPRE o conteúdo armazenado do report (report_id); atrás
    /// da flag EDIT_INCREMENTAL (OFF → 404 edit_incremental_disabled).
    static func editReport(reportId: String, instruction: String) async throws -> EditReportResponse {
        try await APIClient.shared.post(
            "/api/edit",
            body: EditReportRequest(reportId: reportId, instruction: instruction),
            as: EditReportResponse.self
        )
    }
}
