import Foundation

enum UserPhrasesService {
    static let fallbackPhrases: [FallbackPhrase] = [
        FallbackPhrase(title: "DUM (Data da Última Menstruação)", body: "DUM: ____. Idade gestacional de ____ semanas e ____ dias na data do exame."),
        FallbackPhrase(title: "Idade gestacional por USG", body: "Idade gestacional ajustada pela USG: ____ semanas e ____ dias. DPP: ____."),
        FallbackPhrase(title: "Data provável do parto", body: "Data provável do parto: ____."),
        FallbackPhrase(title: "Feto único — apresentação cefálica", body: "Feto único, em situação longitudinal e apresentação cefálica, com BCF presentes."),
        FallbackPhrase(title: "Placenta corporal posterior grau 0/I", body: "Placenta de implantação corporal posterior, grau 0/I de Grannum."),
        FallbackPhrase(title: "Líquido amniótico normal", body: "Líquido amniótico em quantidade normal (ILA 12 cm)."),
        FallbackPhrase(title: "Tireoide tópica normal", body: "Glândula tireoide tópica, contornos regulares, dimensões e ecotextura preservadas."),
        FallbackPhrase(title: "Doppler tireoidiano normal", body: "Vascularização ao Doppler colorido sem alterações.")
    ]

    struct FallbackPhrase: Identifiable, Hashable, Sendable {
        let id = UUID()
        let title: String
        let body: String
    }

    static func fetch(categoryCode: String? = nil) async throws -> [UserPhrase] {
        var query: [String: String] = [
            "select": "id,user_id,title,body,category_code,position,created_at,updated_at",
            "order": "position.asc"
        ]
        if let categoryCode {
            query["or"] = "(category_code.is.null,category_code.eq.\(categoryCode))"
        }
        return try await SupabaseRESTClient.shared.get(
            "/rest/v1/user_phrases",
            query: query,
            as: [UserPhrase].self
        )
    }

    static func create(_ draft: UserPhraseDraft) async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw SupabaseError.unauthorized
        }
        let body = try JSONEncoder.api.encode(UserPhraseCreatePayload(userId: userId, draft: draft))
        try await SupabaseRESTClient.shared.postRaw(
            "/rest/v1/user_phrases",
            query: [:],
            body: body
        )
    }

    static func update(id: String, draft: UserPhraseDraft) async throws {
        try await SupabaseRESTClient.shared.patch(
            "/rest/v1/user_phrases",
            query: ["id": "eq.\(id)"],
            body: draft
        )
    }

    static func delete(id: String) async throws {
        try await SupabaseRESTClient.shared.delete(
            "/rest/v1/user_phrases",
            query: ["id": "eq.\(id)"]
        )
    }
}

private struct UserPhraseCreatePayload: Encodable {
    let userId: String
    let title: String
    let body: String
    let categoryCode: String?
    let position: Int

    init(userId: String, draft: UserPhraseDraft) {
        self.userId = userId
        self.title = draft.title
        self.body = draft.body
        self.categoryCode = draft.categoryCode
        self.position = draft.position
    }
}
