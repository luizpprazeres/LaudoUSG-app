import Foundation

struct SalaPairing: Codable, Sendable, Hashable {
    let code: String
    let token: String
    let expiresAt: Date
    let salaUrl: String
    let salaShortUrl: String

    enum CodingKeys: String, CodingKey {
        case code
        case token
        case expiresAt = "expires_at"
        case salaUrl = "sala_url"
        case salaShortUrl = "sala_short_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try c.decode(String.self, forKey: .code)
        self.token = try c.decode(String.self, forKey: .token)
        let raw = try c.decode(String.self, forKey: .expiresAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: raw) {
            self.expiresAt = parsed
        } else {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            self.expiresAt = fallback.date(from: raw) ?? Date().addingTimeInterval(86_400)
        }
        self.salaUrl = try c.decode(String.self, forKey: .salaUrl)
        self.salaShortUrl = try c.decode(String.self, forKey: .salaShortUrl)
    }

    init(code: String, token: String, expiresAt: Date, salaUrl: String, salaShortUrl: String) {
        self.code = code
        self.token = token
        self.expiresAt = expiresAt
        self.salaUrl = salaUrl
        self.salaShortUrl = salaShortUrl
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encode(token, forKey: .token)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        try c.encode(formatter.string(from: expiresAt), forKey: .expiresAt)
        try c.encode(salaUrl, forKey: .salaUrl)
        try c.encode(salaShortUrl, forKey: .salaShortUrl)
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
