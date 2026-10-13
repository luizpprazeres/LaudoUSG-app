import Foundation

/// Uma palavra final do motor de transcrição com a confiança dele (0–1) e o início em segundos.
struct AsrWord: Codable, Sendable, Hashable {
    let w: String
    let c: Double
    let s: Double?
}

/// O que o motor devolveu ANTES da edição do médico (estudo de transcrição de 12/10/2026, opção B).
/// Vai no `/api/generate` como `asr_original`; o servidor só grava com a flag ligada.
struct AsrOriginalPayload: Codable, Sendable, Hashable {
    let provedor: String
    let modelo: String?
    let texto: String
    let palavras: [AsrWord]?
}

/// Acumula as gravações de um mesmo laudo (o médico pode gravar mais de uma vez).
/// Zera junto com o texto dos achados.
struct AsrCaptureBuffer: Sendable, Hashable {
    private(set) var texto: String = ""
    private(set) var palavras: [AsrWord] = []
    private(set) var provedor: String?

    var isEmpty: Bool { texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    mutating func append(text: String, words: [AsrWord], provider: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        texto += (texto.isEmpty ? "" : "\n") + t
        palavras += words
        // Motores diferentes no mesmo laudo: marca como "outro" (a confiança não é comparável).
        provedor = (provedor == nil || provedor == provider) ? provider : "outro"
    }

    mutating func reset() { self = AsrCaptureBuffer() }

    /// Palavras que o motor ouviu com pouca certeza (< 0,65), sem repetição, até 8.
    /// Só as que dizem algo: com 3+ letras ou com número.
    var uncertainWords: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for p in palavras where p.c < 0.65 {
            let w = p.w.trimmingCharacters(in: .punctuationCharacters)
            guard w.count >= 3 || w.rangeOfCharacter(from: .decimalDigits) != nil else { continue }
            if seen.insert(w.lowercased()).inserted { out.append(w) }
            if out.count == 8 { break }
        }
        return out
    }

    /// Nil quando não houve ditado (texto digitado ou colado não é captura de voz).
    var payload: AsrOriginalPayload? {
        guard !isEmpty, let provedor else { return nil }
        return AsrOriginalPayload(
            provedor: provedor,
            modelo: provedor == "deepgram" ? "nova-3" : nil,
            texto: texto,
            palavras: palavras.isEmpty ? nil : Array(palavras.prefix(8_000))
        )
    }
}
