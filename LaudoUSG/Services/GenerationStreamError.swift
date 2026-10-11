import Foundation

/// Mensagens de falha do stream de `/api/generate`, compartilhadas pela tela de
/// geração e pelo onboarding.
///
/// O `URLSession` do `APIClient` corta qualquer requisição em 120 s
/// (`timeoutIntervalForResource`) e espera conectividade (`waitsForConnectivity`)
/// até esse mesmo limite. Um erro no meio do stream chega aqui como `URLError`
/// cru (não `APIError`), com texto do sistema pouco útil — por isso a tradução.
enum GenerationStreamError {
    /// Stream encerrado sem `done`, `error`, `blocked` nem `clarify`.
    static let interrupted = "A geração foi interrompida antes de concluir. Tente novamente."

    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .transport(let underlying):
                if let urlError = underlying as? URLError, let text = message(for: urlError) { return text }
                return apiError.errorDescription ?? interrupted
            case .unauthorized:
                return "Sessão expirada. Faça login novamente."
            default:
                return apiError.errorDescription ?? interrupted
            }
        }
        if let urlError = error as? URLError, let text = message(for: urlError) { return text }
        return error.localizedDescription
    }

    private static func message(for error: URLError) -> String? {
        switch error.code {
        case .timedOut:
            return "A geração passou de 2 minutos sem concluir. Verifique a conexão e tente novamente."
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return "Sem conexão com a internet. Verifique a rede e tente novamente."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Não foi possível falar com o servidor. Tente novamente em instantes."
        default:
            return nil
        }
    }
}
