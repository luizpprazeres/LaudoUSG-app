import Foundation

struct TranscriptionResponse: Decodable {
    let transcript: String
}

enum TranscribeService {
    static func transcribe(fileURL: URL) async throws -> String {
        let response: TranscriptionResponse = try await WatchAPIClient.shared.authenticatedMultipart(
            "/api/transcribe",
            fileURL: fileURL,
            fieldName: "audio",
            mimeType: "audio/m4a"
        )
        let transcript = response.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw TranscriptionError.empty }
        return transcript
    }
}

enum TranscriptionError: LocalizedError {
    case empty

    var errorDescription: String? {
        "Não foi possível reconhecer o ditado."
    }
}
