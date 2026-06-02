import Foundation

struct WatchGenerateRequest: Encodable {
    let rawInput: String
    let categoryHint: String
    let writingStyleId: String
    let source = "watch"
    let autoPushToSala = true

    enum CodingKeys: String, CodingKey {
        case rawInput = "raw_input"
        case categoryHint = "category_hint"
        case writingStyleId = "writing_style_id"
        case source
        case autoPushToSala = "auto_push_to_sala"
    }
}

struct WatchProfileEnvelope: Decodable {
    let profile: WatchProfile
}

struct WatchProfile: Decodable {
    let defaultWritingStyleId: String?

    enum CodingKeys: String, CodingKey {
        case defaultWritingStyleId = "default_writing_style_id"
    }
}

enum GenerateService {
    static func preferredWritingStyleId() async -> String {
        do {
            let envelope: WatchProfileEnvelope =
                try await WatchAPIClient.shared.authenticatedGet("/api/me/profile")
            return envelope.profile.defaultWritingStyleId ?? APIConfig.defaultWritingStyleId
        } catch {
            return APIConfig.defaultWritingStyleId
        }
    }

    static func generate(transcript: String, category: CategoryWatch) async throws -> String {
        let styleId = await preferredWritingStyleId()
        let payload = WatchGenerateRequest(
            rawInput: transcript,
            categoryHint: category.rawValue,
            writingStyleId: styleId
        )
        let body = try JSONEncoder().encode(payload)
        let bytes = try await WatchAPIClient.shared.authenticatedSSE("/api/generate", body: body)
        return try await waitForDone(bytes)
    }

    private static func waitForDone(_ bytes: URLSession.AsyncBytes) async throws -> String {
        // Parser SSE byte-a-byte espelhando o SSEStreamer.swift do iPhone
        // (battle-tested em prod). URLSession.bytes.lines tem fragilidades com
        // CRLF e quebra inconsistente que causavam streamEnded espúrio mesmo
        // após backend completar e laudo aparecer na Sala.
        var frameBytes: [UInt8] = []
        var previousWasNewline = false

        for try await byte in bytes {
            // Ignora CR (`\r` = 13) ANTES de qualquer outra coisa. Resolve
            // a fragilidade do CRLF que o `\r`-trim em lines não cobre por
            // completo (lines split tinha edge cases com double-CRLF entre eventos).
            guard byte != 13 else { continue }

            frameBytes.append(byte)

            if byte == 10 {  // LF
                if previousWasNewline {
                    // Dois LFs consecutivos = fim do frame SSE.
                    frameBytes.removeLast(2)
                    if let reportId = try processFrame(frameBytes) {
                        return reportId
                    }
                    frameBytes.removeAll(keepingCapacity: true)
                    previousWasNewline = false
                } else {
                    previousWasNewline = true
                }
            } else {
                previousWasNewline = false
            }
        }

        // Stream fechou sem `\n\n` final — tenta processar último frame.
        if !frameBytes.isEmpty {
            if let reportId = try processFrame(frameBytes) {
                return reportId
            }
        }
        throw GenerateError.streamEnded
    }

    private static func processFrame(_ frameBytes: [UInt8]) throws -> String? {
        guard let frame = String(bytes: frameBytes, encoding: .utf8) else { return nil }
        let trimmed = frame.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(":") else { return nil }

        // SSE permite múltiplas `data:` lines no mesmo evento — concatena com `\n`.
        let dataLines = frame
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let s = String(line)
                guard s.hasPrefix("data:") else { return nil }
                var value = String(s.dropFirst(5))
                if value.first == " " { value.removeFirst() }
                return value
            }
        guard !dataLines.isEmpty else { return nil }

        let payload = dataLines.joined(separator: "\n")
        return try decodeDone(from: payload)
    }

    private static func decodeDone(from frame: String) throws -> String? {
        guard !frame.isEmpty, let data = frame.data(using: .utf8) else { return nil }
        let object: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            object = decoded
        } catch {
            return nil
        }
        guard let type = object["type"] as? String else {
            return nil
        }
        switch type {
        case "done":
            guard let reportId = object["report_id"] as? String else {
                throw GenerateError.invalidDone
            }
            return reportId
        case "blocked":
            throw GenerateError.blocked(object["reason"] as? String ?? "Laudo bloqueado.")
        case "error":
            throw GenerateError.failed(object["message"] as? String ?? "Falha ao gerar laudo.")
        default:
            return nil
        }
    }
}

enum GenerateError: LocalizedError {
    case streamEnded
    case invalidDone
    case blocked(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .streamEnded: return "A geração terminou sem confirmação."
        case .invalidDone: return "Resposta final inválida."
        case .blocked(let message), .failed(let message): return message
        }
    }
}
