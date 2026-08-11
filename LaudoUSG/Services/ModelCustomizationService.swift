import Foundation

/// Personalização do modelo de laudo — projeto `docs/projeto-modelos/` no repo
/// do backend, itens 6 e 7.
///
/// O médico não edita um texto solto: ele emite OPERAÇÕES ancoradas em slots do
/// catálogo. É isso que permite ao backend recusar uma alteração que apagaria
/// um dado obrigatório ou que faria uma redação de normalidade ocupar o lugar
/// de um achado alterado.
///
/// Fluxo: rascunho → publicar. Só o publicado muda os laudos.

// MARK: - Operação

/// Uma alteração sobre o modelo. Modelada como struct de campos opcionais (e
/// não como enum) porque o backend aceita uma união discriminada por `op`, e o
/// Codable sintetizado já omite os opcionais nulos ao codificar — que é
/// exatamente o formato que o schema do backend espera.
struct ReportOperation: Codable, Hashable, Identifiable {
    let op: String
    var slot: String?
    var variant: String?
    var value: String?
    var anchor: String?

    var id: String { "\(op)|\(slot ?? anchor ?? "")|\(value ?? "")" }

    static func removeSlot(_ slot: String) -> ReportOperation {
        ReportOperation(op: "remove_slot", slot: slot)
    }
    static func replacePhrase(slot: String, value: String) -> ReportOperation {
        ReportOperation(op: "replace_phrase", slot: slot, value: value)
    }
    static func appendConclusionItem(_ value: String) -> ReportOperation {
        ReportOperation(op: "append_conclusion_item", value: value)
    }
    static func insertPhraseAfter(anchor: String, value: String) -> ReportOperation {
        ReportOperation(op: "insert_phrase_after", value: value, anchor: anchor)
    }

    /// O slot que esta operação endereça — `anchor` no caso da inserção.
    var alvo: String? { slot ?? anchor }
}

// MARK: - Catálogo

struct CatalogVariant: Codable, Hashable {
    let id: String
    let frase: String?
    let padrao: Bool
    let editavel: Bool
    /// Por que não é editável. Texto pronto para mostrar ao médico.
    let motivo: String?
}

struct CatalogSlot: Codable, Hashable, Identifiable {
    let id: String
    let obrigatorio: Bool
    let placeholdersObrigatorios: [String]
    let condicional: Bool
    let variantes: [CatalogVariant]

    /// A variante que vale quando nenhum achado alterado casa.
    var variantePadrao: CatalogVariant? {
        variantes.first(where: { $0.padrao }) ?? variantes.first
    }
}

struct CatalogHeaders: Codable, Hashable {
    let tecnica: String?
    let corpo: String
    let conclusao: String
}

struct CatalogOrder: Codable, Hashable {
    let nome: String
    let slots: [String]
}

struct ReportCatalog: Codable, Hashable {
    let id: String
    let categoria: String
    let estilo: String
    let versao: Int
    let variaveis: [String]
    let cabecalhos: CatalogHeaders
    let preambulo: String?
    let slots: [CatalogSlot]
    let ordens: [CatalogOrder]
}

// MARK: - Versões e diff

struct CustomizationVersion: Codable, Hashable {
    let id: String
    let versao: Int
    let status: String
    let operations: [ReportOperation]
    let baseCatalogId: String
    let baseVersao: Int
    let note: String?
    let publishedAt: String?
    /// O catálogo-base mudou desde que esta personalização foi escrita.
    let baseDesatualizado: Bool
}

/// Diff por SLOT, não textual — é o que permite mostrar a alteração no ponto,
/// com a frase antiga riscada e a nova embaixo.
struct ModelChange: Codable, Hashable {
    let secao: String   // "corpo" | "conclusao"
    let tipo: String    // "alterada" | "removida" | "acrescentada"
    let slot: String
    let instance: String?
    let antes: String?
    let depois: String?
}

/// O que um ACHADO muda no modelo — calculado pelo backend sobre o modelo DO
/// PRÓPRIO MÉDICO, para que a frase riscada seja a dele e não a do catálogo.
struct ModelVariation: Codable, Hashable, Identifiable {
    let id: String
    let nome: String
    let descricao: String
    let patologico: Bool
    let comparaComNome: String
    let mudancas: [ModelChange]
}

/// Como o laudo fica em cada cenário, com e sem a personalização.
struct ReportPreview: Codable, Hashable, Identifiable {
    let cenario: String
    let nome: String
    let patologico: Bool
    let mudou: Bool
    let mudancas: [ModelChange]
    let laudoPadrao: String
    let laudoPersonalizado: String

    var id: String { cenario }
}

struct CustomizationState: Codable, Hashable {
    let categoria: String
    let estilo: String
    let baseCatalogId: String
    let baseVersao: Int
    let catalogo: ReportCatalog
    let rascunho: CustomizationVersion?
    let publicado: CustomizationVersion?
    let variacoes: [ModelVariation]?
    let previa: [ReportPreview]?
    /// Todas as versões, da mais nova para a mais velha — incluindo as
    /// arquivadas. É o que permite voltar atrás sem perder nada.
    let historico: [CustomizationVersion]?
    /// A publicada está mesmo valendo? Depende das flags do servidor, não de
    /// ter publicado. Ausente em backend anterior a este campo.
    let personalizacaoAtiva: Bool?
}

// MARK: - Erros

/// Recusa do backend com os motivos — é para MOSTRAR ao médico, não engolir.
/// Entender o "não" faz parte de confiar no sistema.
struct CustomizationRefusal: LocalizedError {
    let message: String
    let reasons: [String]
    var errorDescription: String? { message }
}

/// O servidor não conhece este endpoint ainda.
///
/// O app pode ser mais novo que o backend — instalado por USB antes do deploy,
/// ou versão de loja à frente da API. Sem distinguir isto, o médico veria
/// "Erro do servidor (404)" e concluiria que o app está quebrado.
struct FeatureNotDeployed: LocalizedError {
    var errorDescription: String? {
        "Esta função ainda não chegou ao servidor. Ela aparece aqui assim que a próxima atualização do LaudoUSG for publicada."
    }
}

// MARK: - Service

enum ModelCustomizationService {
    private struct RefusalBody: Decodable {
        let error: String?
        let erros: [String]?
    }

    /// Traduz o 422/409 do backend numa recusa com motivos legíveis.
    ///
    /// O `APIError.http` já carrega o corpo; sem isto ele viraria a string crua
    /// "Erro do servidor (422): {...json...}" na cara do médico, em vez de
    /// "esta frase precisa conservar o dado {ig_semanas}".
    private static func traduzir(_ error: Error) -> Error {
        if case APIError.http(let status, _) = error, status == 404 {
            return FeatureNotDeployed()
        }
        guard case APIError.http(let status, let body) = error,
              status == 422 || status == 409,
              let data = body?.data(using: .utf8),
              let corpo = try? JSONDecoder().decode(RefusalBody.self, from: data)
        else { return error }
        return CustomizationRefusal(
            message: corpo.error ?? "Esta alteração não pode valer",
            reasons: corpo.erros ?? []
        )
    }

    private static func comRecusa<T>(_ bloco: () async throws -> T) async throws -> T {
        do { return try await bloco() } catch { throw traduzir(error) }
    }

    /// Categorias com catálogo hoje. A lista real é do backend (404 traz
    /// `pares_suportados`), mas a tela precisa de algo antes da 1ª chamada.
    static let categoriasComModelo: [(code: String, label: String)] = [
        ("OBSTETRICA", "Obstétrico")
    ]

    private static let base = "/api/me/report-customizations"

    private static func path(_ categoria: String, _ sufixo: String = "") -> String {
        "\(base)/\(categoria)\(sufixo)"
    }

    private static func query(_ estilo: String) -> [URLQueryItem] {
        [URLQueryItem(name: "estilo", value: estilo)]
    }

    static func fetch(
        categoria: String,
        estilo: String = "CLASSICO_COMPLETO"
    ) async throws -> CustomizationState {
        // Query SEMPRE em queryItems: `appendingPathComponent` escapa o "?" e
        // o servidor responde 404 — ver o comentário em APIClient.makeURL.
        try await comRecusa {
            try await APIClient.shared.get(
                path(categoria),
                queryItems: query(estilo),
                as: CustomizationState.self
            )
        }
    }

    private struct DraftBody: Encodable {
        let operations: [ReportOperation]
    }
    private struct DraftResponse: Decodable {
        let rascunho: CustomizationVersion
    }

    static func saveDraft(
        categoria: String,
        operations: [ReportOperation],
        estilo: String = "CLASSICO_COMPLETO"
    ) async throws -> CustomizationVersion {
        let body = try JSONEncoder.api.encode(DraftBody(operations: operations))
        let data = try await comRecusa {
            try await APIClient.shared.putRawJSON(
                path(categoria),
                body: body,
                queryItems: query(estilo)
            )
        }
        return try JSONDecoder.api.decode(DraftResponse.self, from: data).rascunho
    }

    static func discardDraft(categoria: String, estilo: String = "CLASSICO_COMPLETO") async throws {
        try await APIClient.shared.delete(path(categoria), queryItems: query(estilo))
    }

    static func publish(categoria: String, estilo: String = "CLASSICO_COMPLETO") async throws {
        _ = try await comRecusa {
            try await APIClient.shared.postRawJSON(
                path(categoria, "/publish"),
                body: Data("{}".utf8),
                queryItems: query(estilo)
            )
        }
    }

    private struct RestoreBody: Encodable { let versao: Int }

    /// Traz uma versão do histórico de volta COMO RASCUNHO — nunca publicando
    /// direto. O catálogo-base pode ter mudado desde então, e uma operação que
    /// valia antes pode apontar para um slot que já não existe. Assim a
    /// validação aparece antes de o laudo mudar.
    static func restore(
        categoria: String,
        versao: Int,
        estilo: String = "CLASSICO_COMPLETO"
    ) async throws {
        let body = try JSONEncoder.api.encode(RestoreBody(versao: versao))
        _ = try await comRecusa {
            try await APIClient.shared.postRawJSON(
                path(categoria, "/restore"),
                body: body,
                queryItems: query(estilo)
            )
        }
    }

    /// Desliga a personalização: os laudos voltam ao modelo padrão. Não apaga
    /// o histórico — a versão continua lá e pode ser restaurada.
    static func turnOff(categoria: String, estilo: String = "CLASSICO_COMPLETO") async throws {
        try await APIClient.shared.delete(path(categoria, "/publish"), queryItems: query(estilo))
    }
}
