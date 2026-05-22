import Foundation

enum SalaService {
    private struct EmptyBody: Encodable {}
    private struct RevokeResponse: Decodable {
        let revoked: Int
    }
    private struct PushBody: Encodable {
        let reportId: String
    }
    private struct PushResponse: Decodable {
        let ok: Bool
    }

    static func generatePairing() async throws -> SalaPairing {
        try await APIClient.shared.post(
            "/api/sala/pair/generate",
            body: EmptyBody(),
            as: SalaPairing.self
        )
    }

    static func revoke() async throws -> Int {
        let response: RevokeResponse = try await APIClient.shared.post(
            "/api/sala/revoke",
            body: EmptyBody(),
            as: RevokeResponse.self
        )
        return response.revoked
    }

    static func pushReport(id: String) async throws {
        let _: PushResponse = try await APIClient.shared.post(
            "/api/sala/push",
            body: PushBody(reportId: id),
            as: PushResponse.self
        )
    }
}
