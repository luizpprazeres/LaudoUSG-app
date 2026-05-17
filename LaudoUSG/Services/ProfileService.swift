import Foundation

struct UserProfileRecord: Codable, Sendable, Hashable {
    let id: String
    let email: String?
    let name: String?
    let defaultWritingStyleId: String?
    let plan: String?
}

enum ProfileService {
    private struct ProfileEnvelope: Decodable {
        let profile: UserProfileRecord
    }

    private struct UpdateProfileBody: Encodable {
        var name: String?
        var defaultWritingStyleId: String?
    }

    static func fetchProfile() async throws -> UserProfileRecord {
        let envelope = try await APIClient.shared.get("/api/me/profile", as: ProfileEnvelope.self)
        return envelope.profile
    }

    static func fetchWritingStyles() async throws -> [WritingStyleRecord] {
        try await SupabaseRESTClient.shared.get(
            "/rest/v1/writing_styles",
            query: [
                "select": "id,slug,label,description,is_default,category_code",
                "order": "label.asc"
            ],
            as: [WritingStyleRecord].self
        )
    }

    static func updateDefaultWritingStyle(_ styleId: String) async throws {
        let body = UpdateProfileBody(defaultWritingStyleId: styleId)
        let encoded = try JSONEncoder.api.encode(body)
        _ = try await APIClient.shared.patchRaw("/api/me/profile", body: encoded)
    }
}
