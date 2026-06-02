import Foundation

struct SalaRedeemResponse: Decodable {
    let token: String
}

enum SalaService {
    static func redeem(pairingCode: String) async throws -> String {
        let normalized = pairingCode
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard normalized.count == 6 else { throw SalaError.invalidCode }

        let result: SalaRedeemResponse
        do {
            result = try await WatchAPIClient.shared.get(
                "/api/sala/pair/redeem",
                query: [URLQueryItem(name: "code", value: normalized)]
            )
        } catch WatchAPIError.http(400), WatchAPIError.http(404) {
            throw SalaError.invalidCode
        }
        try KeychainStore.save(normalized, for: "sala.pairingCode")
        try KeychainStore.save(result.token, for: "sala.token")
        return normalized
    }
}

enum SalaError: LocalizedError {
    case invalidCode

    var errorDescription: String? {
        "Código inválido ou expirado."
    }
}
