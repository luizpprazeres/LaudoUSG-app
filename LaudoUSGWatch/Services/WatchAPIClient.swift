import Foundation

enum WatchAPIError: LocalizedError {
    case invalidResponse
    case http(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Resposta inválida do servidor."
        case .http(let status): return "Servidor indisponível (\(status))."
        case .invalidPayload: return "Não foi possível ler a resposta."
        }
    }
}

actor WatchAPIClient {
    static let shared = WatchAPIClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(
            url: APIConfig.apiBaseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        guard let url = components?.url else { throw WatchAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await perform(request)
    }

    func authenticatedGet<T: Decodable>(_ path: String) async throws -> T {
        let token = try await WatchAuthService.shared.accessToken()
        var request = URLRequest(url: APIConfig.apiBaseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func authenticatedMultipart<T: Decodable>(
        _ path: String,
        fileURL: URL,
        fieldName: String,
        mimeType: String
    ) async throws -> T {
        let token = try await WatchAuthService.shared.accessToken()
        let boundary = "----LaudoUSGWatch\(UUID().uuidString)"
        var request = URLRequest(url: APIConfig.apiBaseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"recording.m4a\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        return try await perform(request)
    }

    func authenticatedSSE(_ path: String, body: Data) async throws -> URLSession.AsyncBytes {
        let token = try await WatchAuthService.shared.accessToken()
        var request = URLRequest(url: APIConfig.apiBaseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (bytes, response) = try await session.bytes(for: request)
        try validate(response)
        return bytes
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WatchAPIError.invalidPayload
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw WatchAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WatchAPIError.http(http.statusCode)
        }
    }
}
