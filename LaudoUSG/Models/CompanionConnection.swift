import Foundation

struct CompanionConnection: Codable, Sendable, Hashable {
    let sessionId: String
    let expiresAt: Date
}

struct CompanionSessionRecord: Codable, Sendable {
    let id: String
    let expiresAt: Date
}

