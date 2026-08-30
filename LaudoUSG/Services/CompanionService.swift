import Foundation

enum CompanionService {
    private struct ConnectBody: Encodable {
        let connectedAt: Date
        let pairingCode: String? = nil
        let updatedAt: Date
    }

    private struct EventBody: Encodable {
        let sessionId: String
        let userId: String
        let kind: String
        let payload: Payload
    }

    private struct Payload: Encodable { let text: String }

    static func connect(code rawCode: String) async throws -> CompanionConnection {
        let code = rawCode
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard code.range(of: "^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$", options: .regularExpression) != nil else {
            throw CompanionError.invalidCode
        }
        guard await AuthService.shared.currentUserId() != nil else { throw SupabaseError.unauthorized }
        let now = Date()
        let rows = try await SupabaseRESTClient.shared.patchReturning(
            "/rest/v1/companion_sessions",
            query: [
                "pairing_code": "eq.\(code)",
                "pairing_expires_at": "gt.\(ISO8601DateFormatter.api.string(from: now))",
                "connected_at": "is.null",
                "revoked_at": "is.null",
                "select": "id,expires_at"
            ],
            body: ConnectBody(connectedAt: now, updatedAt: now),
            as: [CompanionSessionRecord].self
        )
        guard let row = rows.first else { throw CompanionError.invalidOrUsed }
        return CompanionConnection(sessionId: row.id, expiresAt: row.expiresAt)
    }

    static func sendText(_ rawText: String, connection: CompanionConnection) async throws {
        try await send(rawText, kind: "text", connection: connection)
    }

    static func sendTranscript(_ rawText: String, connection: CompanionConnection) async throws {
        try await send(rawText, kind: "transcript", connection: connection)
    }

    private static func send(_ rawText: String, kind: String, connection: CompanionConnection) async throws {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CompanionError.emptyText }
        guard text.count <= 2_000 else { throw CompanionError.textTooLong }
        guard connection.expiresAt > Date() else { throw CompanionError.expired }
        guard let userId = await AuthService.shared.currentUserId() else { throw SupabaseError.unauthorized }
        try await SupabaseRESTClient.shared.postRaw(
            "/rest/v1/companion_events",
            query: [:],
            body: JSONEncoder.api.encode(EventBody(sessionId: connection.sessionId, userId: userId, kind: kind, payload: Payload(text: text)))
        )
    }

    static func restoreConnection() async throws -> CompanionConnection? {
        let rows = try await SupabaseRESTClient.shared.get(
            "/rest/v1/companion_sessions",
            query: [
                "select": "id,expires_at",
                "connected_at": "not.is.null",
                "revoked_at": "is.null",
                "expires_at": "gt.\(ISO8601DateFormatter.api.string(from: Date()))",
                "order": "connected_at.desc",
                "limit": "1"
            ],
            as: [CompanionSessionRecord].self
        )
        guard let row = rows.first else { return nil }
        return CompanionConnection(sessionId: row.id, expiresAt: row.expiresAt)
    }
}

enum CompanionError: LocalizedError {
    case invalidCode, invalidOrUsed, emptyText, textTooLong, expired
    var errorDescription: String? {
        switch self {
        case .invalidCode: return "Digite os 6 caracteres mostrados na web."
        case .invalidOrUsed: return "Código inválido, expirado, utilizado ou de outra conta."
        case .emptyText: return "Digite uma mensagem para a auxiliar."
        case .textTooLong: return "A mensagem deve ter no máximo 2.000 caracteres."
        case .expired: return "O turno expirou. Pareie novamente."
        }
    }
}
