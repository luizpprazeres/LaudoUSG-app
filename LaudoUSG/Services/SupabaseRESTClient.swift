import Foundation

enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case http(status: Int, body: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida do Supabase."
        case .invalidResponse: return "Resposta inválida do Supabase."
        case .unauthorized: return "Sessão expirada. Faça login novamente."
        case .http(let status, _): return "Erro do Supabase (\(status))."
        case .decoding(let error): return "Falha ao ler resposta: \(error.localizedDescription)"
        case .transport(let error): return "Erro de conexão: \(error.localizedDescription)"
        }
    }
}

actor SupabaseRESTClient {
    static let shared = SupabaseRESTClient()

    private let session: URLSession
    private var bearerToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func setToken(_ token: String?) {
        self.bearerToken = token
    }

    func get<T: Decodable>(
        _ path: String,
        query: [String: String],
        as type: T.Type
    ) async throws -> T {
        let data = try await performWithRefresh {
            try makeRequest(path: path, method: "GET", query: query)
        }

        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw SupabaseError.decoding(error)
        }
    }

    func patch<B: Encodable>(
        _ path: String,
        query: [String: String],
        body: B
    ) async throws {
        let encoded = try JSONEncoder.api.encode(body)
        _ = try await performWithRefresh {
            var request = try makeRequest(path: path, method: "PATCH", query: query)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = encoded
            return request
        }
    }

    func patchRaw(
        _ path: String,
        query: [String: String],
        body: Data
    ) async throws -> Data {
        try await performWithRefresh {
            var request = try makeRequest(path: path, method: "PATCH", query: query)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = body
            return request
        }
    }

    func postRaw(
        _ path: String,
        query: [String: String],
        body: Data
    ) async throws {
        _ = try await performWithRefresh {
            var request = try makeRequest(path: path, method: "POST", query: query)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = body
            return request
        }
    }

    func delete(
        _ path: String,
        query: [String: String]
    ) async throws {
        _ = try await performWithRefresh {
            var request = try makeRequest(path: path, method: "DELETE", query: query)
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            return request
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        query: [String: String]
    ) throws -> URLRequest {
        guard var components = URLComponents(url: AppConfig.supabaseURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseError.invalidURL
        }

        components.path = normalizedPath(path)
        components.queryItems = query
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func performWithRefresh(_ makeRequest: () throws -> URLRequest) async throws -> Data {
        do {
            return try await perform(makeRequest())
        } catch SupabaseError.unauthorized {
            try await refreshForRetry()
            return try await perform(makeRequest())
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if (error as? URLError)?.code == .cancelled {
                throw error
            }
            throw SupabaseError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw SupabaseError.unauthorized }
            let body = String(data: data, encoding: .utf8)
            throw SupabaseError.http(status: http.statusCode, body: body)
        }

        return data
    }

    private func refreshForRetry() async throws {
        do {
            _ = try await AuthService.shared.refresh()
        } catch {
            throw SupabaseError.unauthorized
        }
    }

    private func normalizedPath(_ path: String) -> String {
        path.hasPrefix("/") ? path : "/\(path)"
    }
}
