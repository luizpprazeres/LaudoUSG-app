import Foundation
import os

struct WatchAuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        if let timestamp = try? container.decode(TimeInterval.self, forKey: .expiresAt) {
            expiresAt = Date(timeIntervalSince1970: timestamp)
        } else {
            let seconds = try container.decode(TimeInterval.self, forKey: .expiresIn)
            expiresAt = Date().addingTimeInterval(seconds)
        }
    }

    init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(expiresAt.timeIntervalSince1970, forKey: .expiresAt)
    }
}

actor WatchAuthService {
    static let shared = WatchAuthService()

    private let log = Logger(subsystem: "com.laudousg.LaudoUSG.watch", category: "Auth")
    private let sessionKey = "auth.session"
    private var cachedSession: WatchAuthSession?

    func hasSession() -> Bool {
        loadSession() != nil
    }

    func signIn(email: String, password: String) async throws {
        let url = APIConfig.supabaseURL.appendingPathComponent("/auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let finalURL = components?.url else { throw WatchAuthError.invalidResponse }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(APIConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(APIConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode([
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "password": password,
        ])

        let session: WatchAuthSession = try await perform(request)
        try persist(session)
        log.info("Watch sign-in completed")
    }

    func accessToken() async throws -> String {
        guard let session = loadSession() else { throw WatchAuthError.signedOut }
        if session.expiresAt > Date().addingTimeInterval(60) {
            return session.accessToken
        }
        return try await refresh(using: session.refreshToken).accessToken
    }

    func signOut() {
        cachedSession = nil
        KeychainStore.delete(sessionKey)
    }

    private func refresh(using refreshToken: String) async throws -> WatchAuthSession {
        let url = APIConfig.supabaseURL.appendingPathComponent("/auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let finalURL = components?.url else { throw WatchAuthError.invalidResponse }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(APIConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(APIConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let session: WatchAuthSession = try await perform(request)
        try persist(session)
        log.info("Watch auth token refreshed")
        return session
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WatchAuthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WatchAuthError.invalidCredentials
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Sem este catch, DecodingError vazava cru pra UI como
            // "The data couldn't be read because it isn't in the correct format."
            // — confunde o usuário (laudo pode ter sido gerado normalmente).
            log.error("Auth decode falhou: \(error.localizedDescription, privacy: .public)")
            throw WatchAuthError.invalidResponse
        }
    }

    private func loadSession() -> WatchAuthSession? {
        if let cachedSession { return cachedSession }
        guard let json = KeychainStore.read(sessionKey),
              let data = json.data(using: .utf8),
              let session = try? JSONDecoder().decode(WatchAuthSession.self, from: data) else {
            return nil
        }
        cachedSession = session
        return session
    }

    private func persist(_ session: WatchAuthSession) throws {
        let data = try JSONEncoder().encode(session)
        guard let json = String(data: data, encoding: .utf8) else {
            throw WatchAuthError.invalidResponse
        }
        try KeychainStore.save(json, for: sessionKey)
        cachedSession = session
    }
}

enum WatchAuthError: LocalizedError {
    case invalidCredentials
    case invalidResponse
    case signedOut

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Email ou senha inválidos."
        case .invalidResponse: return "Resposta inválida da autenticação."
        case .signedOut: return "Faça login novamente."
        }
    }
}
