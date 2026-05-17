import Foundation

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case network(Error)
    case invalidResponse
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Email ou senha inválidos."
        case .network(let err): return "Erro de conexão: \(err.localizedDescription)"
        case .invalidResponse: return "Resposta inesperada do servidor de autenticação."
        case .server(let message): return message
        }
    }
}

struct AuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date?
    let userId: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try c.decode(String.self, forKey: .accessToken)
        self.refreshToken = try c.decode(String.self, forKey: .refreshToken)

        if let absoluteExpiry = try? c.decode(TimeInterval.self, forKey: .expiresAt) {
            self.expiresAt = Date(timeIntervalSince1970: absoluteExpiry)
        } else if let inSeconds = try? c.decode(TimeInterval.self, forKey: .expiresIn) {
            self.expiresAt = Date().addingTimeInterval(inSeconds)
        } else {
            self.expiresAt = nil
        }

        let user = try c.decode(SupabaseUser.self, forKey: .user)
        self.userId = user.id
        self.email = user.email ?? ""
    }

    init(accessToken: String, refreshToken: String, expiresAt: Date?, userId: String, email: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userId = userId
        self.email = email
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(accessToken, forKey: .accessToken)
        try c.encode(refreshToken, forKey: .refreshToken)
        if let expiresAt {
            try c.encode(expiresAt.timeIntervalSince1970, forKey: .expiresAt)
        }
    }
}

private struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

actor AuthService {
    static let shared = AuthService()

    private let session: URLSession
    private let storageKey = "laudousg.session.v1"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let finalURL = components?.url else { throw AuthError.invalidResponse }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }

        if (200..<300).contains(http.statusCode) {
            let decoded = try JSONDecoder().decode(AuthSession.self, from: data)
            persist(decoded)
            await APIClient.shared.setToken(decoded.accessToken)
            await SupabaseRESTClient.shared.setToken(decoded.accessToken)
            return decoded
        }

        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = (payload["error_description"] as? String) ?? (payload["msg"] as? String) {
            if http.statusCode == 400 || message.lowercased().contains("invalid") {
                throw AuthError.invalidCredentials
            }
            throw AuthError.server(message: message)
        }
        throw AuthError.invalidResponse
    }

    func signOut() async {
        UserDefaults.standard.removeObject(forKey: storageKey)
        await APIClient.shared.setToken(nil)
        await SupabaseRESTClient.shared.setToken(nil)
    }

    func restoreSession() async -> AuthSession? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        guard let session = try? JSONDecoder().decode(StoredSession.self, from: data) else { return nil }
        if let expiresAt = session.expiresAt, expiresAt < Date().addingTimeInterval(60) {
            return nil
        }
        await APIClient.shared.setToken(session.accessToken)
        await SupabaseRESTClient.shared.setToken(session.accessToken)
        return AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: session.expiresAt,
            userId: session.userId,
            email: session.email
        )
    }

    private func persist(_ session: AuthSession) {
        let stored = StoredSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: session.expiresAt,
            userId: session.userId,
            email: session.email
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

private struct StoredSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date?
    let userId: String
    let email: String
}
