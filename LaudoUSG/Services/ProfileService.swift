import Foundation

struct UserProfileRecord: Codable, Sendable, Hashable {
    let id: String
    let email: String?
    let name: String?
    let crm: String?
    let uf: String?
    let defaultWritingStyleId: String?
    let plan: String?
    let termsAcceptedAt: Date?
    let termsVersionAccepted: String?
    let privacyVersionAccepted: String?
    let medicalDisclaimerVersionAccepted: String?
    let onboardingCompletedAt: Date?
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

    static func updateProfile(name: String, crm: String, uf: String) async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw AuthError.invalidResponse
        }
        let body = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "crm": crm.trimmingCharacters(in: .whitespacesAndNewlines),
            "uf": uf.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        ]
        let encoded = try JSONEncoder().encode(body)
        _ = try await SupabaseRESTClient.shared.patchRaw(
            "/rest/v1/profiles",
            query: ["id": "eq.\(userId)"],
            body: encoded
        )
    }

    static func recordLegalAcceptance(
        termsVersion: String,
        privacyVersion: String,
        disclaimerVersion: String
    ) async throws -> Date {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw AuthError.invalidResponse
        }

        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        let body: [String: String] = [
            "terms_accepted_at": isoFormatter.string(from: now),
            "terms_version_accepted": termsVersion,
            "privacy_version_accepted": privacyVersion,
            "medical_disclaimer_version_accepted": disclaimerVersion
        ]

        let encoded = try JSONEncoder().encode(body)
        _ = try await SupabaseRESTClient.shared.patchRaw(
            "/rest/v1/profiles",
            query: ["id": "eq.\(userId)"],
            body: encoded
        )
        return now
    }

    static func markOnboardingComplete() async throws -> Date {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw AuthError.invalidResponse
        }
        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        let body = ["onboarding_completed_at": isoFormatter.string(from: now)]
        let encoded = try JSONEncoder().encode(body)
        _ = try await SupabaseRESTClient.shared.patchRaw(
            "/rest/v1/profiles",
            query: ["id": "eq.\(userId)"],
            body: encoded
        )
        return now
    }
}
