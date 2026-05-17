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
}

struct UserPhraseDraft: Codable, Sendable {
    var title: String
    var body: String
    var categoryCode: String?
    var position: Int
}
