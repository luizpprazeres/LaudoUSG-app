import Foundation

enum ConsultorService {
    static func sendMessage(
        history: [ConsultorMessage],
        category: String?,
        reportId: String?
    ) async throws -> AsyncThrowingStream<ConsultorSSEEvent, Error> {
        let body = try encodeBody(history: history, category: category, reportId: reportId)
        let bytes = try await APIClient.shared.streamSSE(path: "/api/consultant", body: body)
        return SSEStreamer.stream(from: bytes)
    }

    private static func encodeBody(
        history: [ConsultorMessage],
        category: String?,
        reportId: String?
    ) throws -> Data {
        let wireMessages = history.map { msg -> WireMessage in
            if msg.imagesBase64.isEmpty {
                return WireMessage(role: msg.role.rawValue, content: .text(msg.text))
            }
            var parts: [WirePart] = [.text(msg.text)]
            for base64 in msg.imagesBase64 {
                parts.append(.image(WireImageURL(url: base64)))
            }
            return WireMessage(role: msg.role.rawValue, content: .parts(parts))
        }

        let payload = WireRequest(
            messages: wireMessages,
            category: category,
            reportId: reportId
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(payload)
    }
}

private struct WireRequest: Encodable {
    let messages: [WireMessage]
    let category: String?
    let reportId: String?
}

private struct WireMessage: Encodable {
    let role: String
    let content: WireContent
}

private enum WireContent: Encodable {
    case text(String)
    case parts([WirePart])

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s): try c.encode(s)
        case .parts(let p): try c.encode(p)
        }
    }
}

private enum WirePart: Encodable {
    case text(String)
    case image(WireImageURL)

    private enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode("text", forKey: .type)
            try c.encode(s, forKey: .text)
        case .image(let img):
            try c.encode("image_url", forKey: .type)
            try c.encode(img, forKey: .imageUrl)
        }
    }
}

private struct WireImageURL: Encodable {
    let url: String
}
