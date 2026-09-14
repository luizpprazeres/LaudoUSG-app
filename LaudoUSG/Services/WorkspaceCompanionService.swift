import Foundation

enum WorkspaceCompanionService {
    private struct PairBody: Encodable {
        let code: String
        let deviceLabel: String
    }

    private struct PairResponse: Decodable {
        let session: WorkspaceCompanionSession
    }

    private struct SendInputBody: Encodable {
        let sessionId: String
        let clientEventId: String
        let kind: WorkspaceCompanionInputKind
        let text: String
        let categoryCode: String
    }

    private struct SendInputResponse: Decodable {
        let ok: Bool
        let inputId: String?
    }

    static func pair(code: String) async throws -> WorkspaceCompanionSession {
        let body = try JSONEncoder().encode(
            PairBody(code: code, deviceLabel: "iPhone")
        )
        let data = try await APIClient.shared.postRawJSON(
            "/api/workspace/pair",
            body: body
        )
        let response = try JSONDecoder.api.decode(PairResponse.self, from: data)
        return response.session
    }

    static func send(
        sessionId: String,
        kind: WorkspaceCompanionInputKind,
        text: String,
        categoryCode: String
    ) async throws {
        // Os endpoints de workspace são compartilhados com o cliente web e usam
        // camelCase. O encoder global da API converte chaves para snake_case, então
        // este fluxo precisa preservar explicitamente os nomes do contrato.
        let body = try JSONEncoder().encode(
            SendInputBody(
                sessionId: sessionId,
                clientEventId: UUID().uuidString.lowercased(),
                kind: kind,
                text: text,
                categoryCode: categoryCode
            )
        )
        let data = try await APIClient.shared.postRawJSON(
            "/api/workspace/inputs",
            body: body
        )
        _ = try JSONDecoder.api.decode(SendInputResponse.self, from: data)
    }
}
