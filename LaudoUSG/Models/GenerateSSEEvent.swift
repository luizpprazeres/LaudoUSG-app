import Foundation

enum GenerateSSEEvent: Sendable {
    case open(OpenPayload)
    case heartbeat(HeartbeatPayload)
    case stage(StagePayload)
    case structured(StructuredPayload)
    case validator(ValidatorPayload)
    case clarify(ClarifyPayload)
    case rag(RagPayload)
    case warning(WarningPayload)
    case token(TokenPayload)
    case sanity(SanityPayload)
    case done(DonePayload)
    case blocked(BlockedPayload)
    case error(ErrorPayload)
}

extension GenerateSSEEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "open":
            self = .open(try OpenPayload(from: decoder))
        case "heartbeat":
            self = .heartbeat(try HeartbeatPayload(from: decoder))
        case "stage":
            self = .stage(try StagePayload(from: decoder))
        case "structured":
            self = .structured(try StructuredPayload(from: decoder))
        case "validator":
            self = .validator(try ValidatorPayload(from: decoder))
        case "clarify":
            self = .clarify(try ClarifyPayload(from: decoder))
        case "rag":
            self = .rag(try RagPayload(from: decoder))
        case "warning":
            self = .warning(try WarningPayload(from: decoder))
        case "token":
            self = .token(try TokenPayload(from: decoder))
        case "sanity":
            self = .sanity(try SanityPayload(from: decoder))
        case "done":
            self = .done(try DonePayload(from: decoder))
        case "blocked":
            self = .blocked(try BlockedPayload(from: decoder))
        case "error":
            self = .error(try ErrorPayload(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Evento SSE desconhecido: \(type)"
            )
        }
    }
}

struct OpenPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let reportId: String
}

struct HeartbeatPayload: Decodable, Sendable, Hashable {
    let ts: String?
}

struct StagePayload: Decodable, Sendable, Hashable {
    let ts: String?
    let stage: String
    let label: String
}

struct StructuredPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let payload: StructuredFindings
}

struct ValidatorPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let ok: Bool
    let issuesCount: Int
}

struct ClarifyPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let questions: [ClarifyQuestion]
}

struct ClarifyQuestion: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    let kind: String
    let text: String
    let suggestedAnswer: String?
}

struct RagPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let blocksUsed: [String]
    let blocksSummary: [RagBlockSummary]
}

struct RagBlockSummary: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    let kind: String
    let title: String
    let priority: Int
}

struct WarningPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let code: String
    let message: String
}

struct TokenPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let delta: String
}

struct SanityPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let result: SanityResult
}

struct DonePayload: Decodable, Sendable, Hashable {
    let ts: String?
    let reportId: String
    let finalText: String
}

struct BlockedPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let reportId: String
    let reason: String
    let sanity: SanityResult
}

struct ErrorPayload: Decodable, Sendable, Hashable {
    let ts: String?
    let code: String
    let message: String
}
