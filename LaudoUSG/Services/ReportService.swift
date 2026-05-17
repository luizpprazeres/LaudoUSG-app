import Foundation

enum ReportService {
    static func generateStream(request: GenerateRequest) async throws -> AsyncThrowingStream<GenerateSSEEvent, Error> {
        let body = try JSONEncoder.api.encode(request)
        let bytes = try await APIClient.shared.streamSSE(path: "/api/generate", body: body)
        return SSEStreamer.stream(from: bytes)
    }
}
