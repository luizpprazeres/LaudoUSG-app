import Foundation

struct SalaPairing: Codable, Sendable, Hashable {
    let code: String
    let token: String
    let expiresAt: Date
    let salaUrl: String
    let salaShortUrl: String

    init(code: String, token: String, expiresAt: Date, salaUrl: String, salaShortUrl: String) {
        self.code = code
        self.token = token
        self.expiresAt = expiresAt
        self.salaUrl = salaUrl
        self.salaShortUrl = salaShortUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: GenericKeys.self)
        self.code = try c.decode(String.self, forKey: GenericKeys(stringValue: "code")!)
        self.token = try c.decode(String.self, forKey: GenericKeys(stringValue: "token")!)
        self.salaUrl = try c.decode(String.self, forKey: GenericKeys(stringValue: "salaUrl")!)
        self.salaShortUrl = try c.decode(String.self, forKey: GenericKeys(stringValue: "salaShortUrl")!)

        let raw = try c.decode(String.self, forKey: GenericKeys(stringValue: "expiresAt")!)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: raw) {
            self.expiresAt = parsed
        } else {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            self.expiresAt = fallback.date(from: raw) ?? Date().addingTimeInterval(86_400)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: GenericKeys.self)
        try c.encode(code, forKey: GenericKeys(stringValue: "code")!)
        try c.encode(token, forKey: GenericKeys(stringValue: "token")!)
        try c.encode(salaUrl, forKey: GenericKeys(stringValue: "salaUrl")!)
        try c.encode(salaShortUrl, forKey: GenericKeys(stringValue: "salaShortUrl")!)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        try c.encode(formatter.string(from: expiresAt), forKey: GenericKeys(stringValue: "expiresAt")!)
    }

    var formattedCode: String {
        guard code.count == 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return "\(code[code.startIndex..<mid]) \(code[mid...])"
    }

    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
}

private struct GenericKeys: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
