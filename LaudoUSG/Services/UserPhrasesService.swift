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
        let response = try await APIClient.shared.get(
            "/api/me/user-phrases",
            as: UserPhrasesResponse.self
        )
        guard let categoryCode else { return response.phrases }
        return response.phrases.filter { $0.categoryCode == nil || $0.categoryCode == categoryCode }
    }

    static func create(_ draft: UserPhraseDraft) async throws {
        let body = try JSONEncoder.api.encode(draft)
        _ = try await APIClient.shared.postRawJSON("/api/me/user-phrases", body: body)
    }

    static func update(id: String, draft: UserPhraseDraft) async throws {
        let body = try JSONEncoder.api.encode(UserPhraseUpdatePayload(id: id, draft: draft))
        _ = try await APIClient.shared.patchRaw("/api/me/user-phrases", body: body)
    }

    static func delete(id: String) async throws {
        try await APIClient.shared.delete(
            "/api/me/user-phrases",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
    }
}

private struct UserPhrasesResponse: Decodable {
    let phrases: [UserPhrase]
}

private struct UserPhraseUpdatePayload: Encodable {
    let id: String
    let title: String
    let body: String
    let categoryCode: String?

    init(id: String, draft: UserPhraseDraft) {
        self.id = id
        self.title = draft.title
        self.body = draft.body
        self.categoryCode = draft.categoryCode
    }
}
