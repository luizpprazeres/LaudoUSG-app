import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case http(status: Int, body: String?)
    case decoding(Error)
    case transport(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Resposta inválida do servidor."
        case .http(let status, let body):
            if let body, !body.isEmpty {
                return "Erro do servidor (\(status)): \(body)"
            }
            return "Erro do servidor (\(status))."
        case .decoding(let error): return "Falha ao ler resposta: \(error.localizedDescription)"
        case .transport(let error): return "Erro de conexão: \(error.localizedDescription)"
        case .unauthorized: return "Sessão expirada. Faça login novamente."
        }
    }
}

actor APIClient {
    static let shared = APIClient()

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

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        let url = AppConfig.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { request.httpBody = body }
        return request
    }

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let data = try await performWithRefresh {
            makeRequest(path: path)
        }
        return try decode(data)
    }

    func patchRaw(_ path: String, body: Data) async throws -> Data {
        try await performWithRefresh {
            makeRequest(path: path, method: "PATCH", body: body)
        }
    }

    func delete(_ path: String) async throws {
        _ = try await performWithRefresh {
            makeRequest(path: path, method: "DELETE")
        }
    }

    func postRawJSON(_ path: String, body: Data) async throws -> Data {
        try await performWithRefresh {
            makeRequest(path: path, method: "POST", body: body)
        }
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        let encoded = try JSONEncoder.api.encode(body)
        let data = try await performWithRefresh {
            makeRequest(path: path, method: "POST", body: encoded)
        }
        return try decode(data)
    }

    func postMultipart<T: Decodable>(
        _ path: String,
        fileURL: URL,
        fileName: String,
        fieldName: String,
        mimeType: String,
        as type: T.Type
    ) async throws -> T {
        let data = try await performWithRefresh {
            try makeMultipartRequest(
                path,
                fileURL: fileURL,
                fileName: fileName,
                fieldName: fieldName,
                mimeType: mimeType
            )
        }
        return try decode(data)
    }

    func streamSSE(path: String, body: Data) async throws -> URLSession.AsyncBytes {
        try await streamWithRefresh {
            var request = makeRequest(path: path, method: "POST", body: body)
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            return request
        }
    }

    private func makeMultipartRequest(
        _ path: String,
        fileURL: URL,
        fileName: String,
        fieldName: String,
        mimeType: String
    ) throws -> URLRequest {
        let boundary = "----LaudoUSGBoundary\(UUID().uuidString)"
        let url = AppConfig.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        return request
    }

    private func performWithRefresh(_ makeRequest: () throws -> URLRequest) async throws -> Data {
        do {
            return try await perform(makeRequest())
        } catch APIError.unauthorized {
            try await refreshForRetry()
            return try await perform(makeRequest())
        }
    }

    private func streamWithRefresh(_ makeRequest: () throws -> URLRequest) async throws -> URLSession.AsyncBytes {
        do {
            return try await stream(makeRequest())
        } catch APIError.unauthorized {
            try await refreshForRetry()
            return try await stream(makeRequest())
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func stream(_ request: URLRequest) async throws -> URLSession.AsyncBytes {
        do {
            let (stream, response) = try await session.bytes(for: request)
            try validate(response: response, data: nil)
            return stream
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func refreshForRetry() async throws {
        do {
            _ = try await AuthService.shared.refresh()
        } catch {
            throw APIError.unauthorized
        }
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            let body = data.flatMap { String(data: $0, encoding: .utf8) }
            throw APIError.http(status: http.statusCode, body: body)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.apiWithFractionalSeconds.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.api.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Data inválida: \(value)"
            )
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension ISO8601DateFormatter {
    static let api: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let apiWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
