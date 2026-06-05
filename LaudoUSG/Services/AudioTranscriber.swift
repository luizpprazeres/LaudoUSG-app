import Foundation

/// Transcrição batch de um arquivo de áudio (Whisper via /api/transcribe).
/// Usado pra transcrever os ditados gravados no Apple Watch.
enum AudioTranscriber {
    private struct Response: Decodable { let transcript: String }

    static func transcribe(fileURL: URL) async throws -> String {
        let result = try await APIClient.shared.postMultipart(
            "/api/transcribe",
            fileURL: fileURL,
            fileName: "recording.m4a",
            fieldName: "audio",
            mimeType: "audio/m4a",
            as: Response.self
        )
        return result.transcript
    }
}
