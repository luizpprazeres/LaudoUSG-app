import Foundation

enum ConsultorRole: String, Sendable, Codable {
    case user
    case assistant
}

struct ConsultorMessage: Identifiable, Sendable, Hashable {
    let id: UUID
    let role: ConsultorRole
    var text: String
    var imagesBase64: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: ConsultorRole,
        text: String,
        imagesBase64: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.imagesBase64 = imagesBase64
        self.createdAt = createdAt
    }
}
