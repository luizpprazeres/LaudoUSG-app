import Foundation

struct UserPhrase: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let userId: String
    var title: String
    var body: String
    var categoryCode: String?
    var position: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case body
        case categoryCode = "category_code"
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserPhraseDraft: Codable, Sendable {
    var title: String
    var body: String
    var categoryCode: String?
    var position: Int

    enum CodingKeys: String, CodingKey {
        case title
        case body
        case categoryCode = "category_code"
        case position
    }
}
