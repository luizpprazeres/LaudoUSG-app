import Foundation

struct UserPreferences: Codable, Sendable, Equatable {
    var weightFormula: WeightFormula = .hadlock4_1985
    var percentileSource: PercentileSource = .intergrowth21st
    var transcriptionEngine: TranscriptionEngine = .laudousg

    static let `default` = UserPreferences()
}

/// Qual motor transcreve o ditado ao vivo.
///
/// A escolha é do usuário, mas não é neutra — cada um ganha e perde em coisas
/// diferentes, e o subtítulo na tela precisa dizer isso sem jargão:
///
/// - **LaudoUSG** (nuvem): recebe o glossário médico por categoria de exame, então
///   acerta mais jargão (medido: 84% vs 68% sem glossário). Precisa de internet.
/// - **Nativa** (Apple, no aparelho): funciona sem internet, o áudio nunca sai do
///   iPhone. Mas não aceita glossário, e formata número de forma inconsistente
///   ("37 semanas" numa frase, "seis semanas" na outra) porque não tem equivalente
///   ao `numerals=true` do Deepgram.
///
/// Só existe a partir do iOS 26 — antes disso o `SpeechTranscriber` da Apple não
/// existe. Ver `isAvailableOnThisDevice`.
enum TranscriptionEngine: String, Codable, Sendable, CaseIterable {
    case laudousg = "laudousg"
    case nativa = "nativa"

    var displayName: String {
        switch self {
        case .laudousg: "Transcrição LaudoUSG"
        case .nativa: "Transcrição nativa"
        }
    }

    var subtitle: String {
        switch self {
        case .laudousg:
            "Reconhece melhor os termos médicos. Precisa de internet."
        case .nativa:
            "Funciona sem internet e o áudio não sai do iPhone. Pode errar mais termos médicos e números."
        }
    }

    /// `nil` quando o motor está disponível; texto do impedimento quando não está.
    var unavailableReason: String? {
        switch self {
        case .laudousg:
            return nil
        case .nativa:
            if #available(iOS 26.0, *) { return nil }
            return "Disponível a partir do iOS 26"
        }
    }

    var isAvailableOnThisDevice: Bool { unavailableReason == nil }

    /// O que a UI usa de fato. Blinda o caso de alguém ter escolhido "nativa" e
    /// depois voltar para um iOS mais antigo (ou restaurar backup em outro aparelho):
    /// a preferência continua salva, mas o app não tenta usar o que não existe.
    var effective: TranscriptionEngine {
        isAvailableOnThisDevice ? self : .laudousg
    }
}
