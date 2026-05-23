import Foundation

enum ConsultorSSEEvent: Sendable, Decodable {
    case content(text: String)
    case done
    case error(message: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "content":
            self = .content(text: try container.decode(String.self, forKey: .text))
        case "done":
            self = .done
        case "error":
            self = .error(message: try container.decode(String.self, forKey: .message))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Evento Consultor SSE desconhecido: \(type)"
            )
        }
    }
}
