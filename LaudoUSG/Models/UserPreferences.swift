import Foundation

struct UserPreferences: Codable, Sendable, Equatable {
    var weightFormula: WeightFormula = .hadlock4_1985
    var percentileSource: PercentileSource = .intergrowth21st
    var transcriptionEngine: TranscriptionEngine = .laudousg

    /// Bancada de comparação de modelo: manda `mode: "experimental"` e o backend
    /// troca o writer para o provider alternativo, em QUALQUER categoria.
    ///
    /// Substitui a antiga categoria TESTE. Categoria era o gatilho errado — para
    /// comparar provider você quer o exame real (tireoide, obstétrico), não uma
    /// categoria sem contrato clínico.
    ///
    /// Só aparece com `AppExperiments.developerToolsUnlocked`, e o servidor
    /// ainda restringe a `TESTE_ALLOWED_USER_ID`.
    var experimentalModel: Bool = false

    static let `default` = UserPreferences()
}

extension UserPreferences {
    /// Decodificação TOLERANTE a chave ausente.
    ///
    /// O `init(from:)` sintetizado pelo Swift **ignora os valores default** das
    /// propriedades e lança `keyNotFound` quando a chave não está no JSON. Como o
    /// `PreferencesStore` decodifica com `try?` e cai em `.default` no erro,
    /// acrescentar um campo aqui apagaria SILENCIOSAMENTE todas as preferências já
    /// salvas do usuário — quem tinha escolhido Hadlock voltaria para Intergrowth
    /// sem aviso, só por ter atualizado o app.
    ///
    /// Com `decodeIfPresent`, JSON antigo continua sendo lido e o campo novo
    /// assume o default. Vale para os dois lados: uma build antiga também aguenta
    /// o JSON de uma build nova, porque simplesmente ignora o que não conhece.
    ///
    /// **Ao adicionar um campo, acrescente a linha correspondente aqui.**
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = UserPreferences.default
        self.weightFormula =
            try container.decodeIfPresent(WeightFormula.self, forKey: .weightFormula)
            ?? fallback.weightFormula
        self.percentileSource =
            try container.decodeIfPresent(PercentileSource.self, forKey: .percentileSource)
            ?? fallback.percentileSource
        self.transcriptionEngine =
            try container.decodeIfPresent(TranscriptionEngine.self, forKey: .transcriptionEngine)
            ?? fallback.transcriptionEngine
        self.experimentalModel =
            try container.decodeIfPresent(Bool.self, forKey: .experimentalModel)
            ?? fallback.experimentalModel
    }
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
