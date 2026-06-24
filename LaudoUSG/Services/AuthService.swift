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

enum SignUpResult {
    case needsEmailConfirmation(email: String)
    case signedIn(AuthSession)
}

enum DeepLinkResult {
    case signedIn(AuthSession)
    case passwordRecovery(AuthSession)
}

enum SignUpError: LocalizedError {
    case userAlreadyExists
    case weakPassword
    case rateLimited
    case network(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .userAlreadyExists: return "Este email já tem conta. Faça login."
        case .weakPassword: return "Senha muito fraca. Use 8+ caracteres com letra e número."
        case .rateLimited: return "Muitas tentativas. Aguarde 1 minuto."
        case .network(let m): return "Erro de conexão: \(m)"
        case .unknown(let m): return m
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

private struct SignUpPayload: Encodable {
    let email: String
    let password: String
    let data: SignUpMetadata
    let options: SignUpOptions
}

private struct SignUpMetadata: Encodable {
    let name: String
    let crm: String
    let uf: String
    let termsAcceptedAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case crm
        case uf
        case termsAcceptedAt = "terms_accepted_at"
    }
}

private struct SignUpOptions: Encodable {
    let emailRedirectTo: String
}

private struct PasswordResetPayload: Encodable {
    let email: String
    let options: PasswordResetOptions
}

private struct PasswordResetOptions: Encodable {
    let redirectTo: String

    enum CodingKeys: String, CodingKey {
        case redirectTo = "redirect_to"
    }
}

private struct UpdatePasswordPayload: Encodable {
    let password: String
}

private struct SignUpResponse: Decodable {
    let user: SignUpUser?
    let session: AuthSession?
}

private struct SignUpUser: Decodable {
    let id: String
    let email: String?
    let confirmedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case confirmedAt = "confirmed_at"
    }
}

actor AuthService {
    static let shared = AuthService()

    private let session: URLSession
    private let storageKey = "laudousg.session.v1"
    private var refreshTask: Task<AuthSession, Error>?

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
            if message.lowercased().contains("email_not_confirmed") || message.lowercased().contains("email not confirmed") {
                throw AuthError.server(message: message)
            }
            if http.statusCode == 400 || message.lowercased().contains("invalid") {
                throw AuthError.invalidCredentials
            }
            throw AuthError.server(message: message)
        }
        throw AuthError.invalidResponse
    }

    func signUp(draft: SignUpDraft) async throws -> SignUpResult {
        let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let formatter = ISO8601DateFormatter()
        let payload = SignUpPayload(
            email: draft.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: draft.password,
            data: SignUpMetadata(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                crm: draft.crm.trimmingCharacters(in: .whitespacesAndNewlines),
                uf: draft.uf.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                termsAcceptedAt: formatter.string(from: Date())
            ),
            options: SignUpOptions(emailRedirectTo: "laudousg://auth/callback")
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw SignUpError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SignUpError.unknown("Resposta inesperada do servidor.")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw mapSignUpError(status: http.statusCode, data: responseData)
        }

        let decoded = try JSONDecoder().decode(SignUpResponse.self, from: responseData)
        if let session = decoded.session {
            persist(session)
            await APIClient.shared.setToken(session.accessToken)
            await SupabaseRESTClient.shared.setToken(session.accessToken)
            return .signedIn(session)
        }
        return .needsEmailConfirmation(email: decoded.user?.email ?? payload.email)
    }

    func resendConfirmation(email: String) async throws {
        let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/resend")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode([
            "type": "signup",
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ])

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw SignUpError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SignUpError.unknown("Resposta inesperada do servidor.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapSignUpError(status: http.statusCode, data: responseData)
        }
    }

    func handleMagicLink(_ url: URL) async throws -> DeepLinkResult {
        guard let fragment = url.fragment else { throw AuthError.invalidResponse }
        let values = parseFragment(fragment)
        guard let accessToken = values["access_token"],
              let refreshToken = values["refresh_token"] else {
            throw AuthError.invalidResponse
        }
        let expiresIn = TimeInterval(values["expires_in"] ?? "")
        let user = try await fetchUser(accessToken: accessToken)
        let session = AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) },
            userId: user.id,
            email: user.email ?? ""
        )
        persist(session)
        await APIClient.shared.setToken(session.accessToken)
        await SupabaseRESTClient.shared.setToken(session.accessToken)
        if values["type"] == "recovery" {
            return .passwordRecovery(session)
        }
        return .signedIn(session)
    }

    func requestPasswordReset(email: String) async throws {
        let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/recover")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(
            PasswordResetPayload(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                options: PasswordResetOptions(redirectTo: "laudousg://auth/reset-password")
            )
        )

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 429 { throw SignUpError.rateLimited }
            throw AuthError.server(message: authMessage(from: responseData) ?? "Erro ao enviar link de recuperação.")
        }
    }

    func updatePassword(newPassword: String) async throws {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(StoredSession.self, from: data) else {
            throw AuthError.invalidResponse
        }

        let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/user")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(stored.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(UpdatePasswordPayload(password: newPassword))

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = authMessage(from: responseData) ?? "Erro ao atualizar senha."
            if http.statusCode == 422, message.lowercased().contains("weak_password") {
                throw SignUpError.weakPassword
            }
            throw AuthError.server(message: message)
        }
    }

    func deleteAccount() async throws {
        try await APIClient.shared.delete("/api/me/delete-account")
        await signOut()
    }

    func refresh() async throws -> AuthSession {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<AuthSession, Error> {
            guard let storedData = UserDefaults.standard.data(forKey: storageKey),
                  let stored = try? JSONDecoder().decode(StoredSession.self, from: storedData) else {
                throw AuthError.invalidResponse
            }

            let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/token")
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
            guard let finalURL = components?.url else { throw AuthError.invalidResponse }

            var request = URLRequest(url: finalURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(["refresh_token": stored.refreshToken])

            let responseData: Data
            let response: URLResponse

            do {
                (responseData, response) = try await session.data(for: request)
            } catch {
                throw AuthError.network(error)
            }

            guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                if let payload = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let message = (payload["error_description"] as? String) ?? (payload["msg"] as? String) {
                    throw AuthError.server(message: message)
                }
                throw AuthError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(AuthSession.self, from: responseData)
            persist(decoded)
            await APIClient.shared.setToken(decoded.accessToken)
            await SupabaseRESTClient.shared.setToken(decoded.accessToken)
            return decoded
        }

        refreshTask = task

        do {
            let session = try await task.value
            refreshTask = nil
            return session
        } catch {
            refreshTask = nil
            await signOut()
            throw error
        }
    }

    func signOut() async {
        UserDefaults.standard.removeObject(forKey: storageKey)
        await APIClient.shared.setToken(nil)
        await SupabaseRESTClient.shared.setToken(nil)
    }

    func currentUserId() -> String? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let session = try? JSONDecoder().decode(StoredSession.self, from: data) else {
            return nil
        }
        return session.userId
    }

    func restoreSession() async -> AuthSession? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        guard let session = try? JSONDecoder().decode(StoredSession.self, from: data) else { return nil }
        if let expiresAt = session.expiresAt, expiresAt < Date().addingTimeInterval(60) {
            // #4: token expirado, mas o refresh token dura semanas — renova antes
            // de desistir, em vez de deslogar o usuário a cada abertura após ~1h.
            return try? await refresh()
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

    private func fetchUser(accessToken: String) async throws -> SupabaseUser {
        let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/user")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AuthError.invalidResponse }
        return try JSONDecoder().decode(SupabaseUser.self, from: responseData)
    }

    private func parseFragment(_ fragment: String) -> [String: String] {
        var values: [String: String] = [:]
        for pair in fragment.split(separator: "&", omittingEmptySubsequences: false) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            values[key] = value
        }
        return values
    }

    private func mapSignUpError(status: Int, data: Data) -> SignUpError {
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = [
            payload?["error"] as? String,
            payload?["error_description"] as? String,
            payload?["msg"] as? String,
            payload?["message"] as? String,
            payload?["code"] as? String
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        if status == 429 { return .rateLimited }
        if message.contains("weak_password") { return .weakPassword }
        if status == 422 || message.contains("user_already_exists") || message.contains("already registered") {
            return .userAlreadyExists
        }
        if status >= 500 { return .unknown("Erro no servidor. Tente novamente.") }
        return .unknown("Erro no servidor. Tente novamente.")
    }

    private func authMessage(from data: Data) -> String? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        return [
            payload["error_description"] as? String,
            payload["msg"] as? String,
            payload["message"] as? String,
            payload["error"] as? String,
            payload["code"] as? String
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

private struct StoredSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date?
    let userId: String
    let email: String
}
