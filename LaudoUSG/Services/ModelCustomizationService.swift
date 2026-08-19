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
    /// Como esta variante SAI no laudo, renderizada de um achado de exemplo.
    /// É o que dá texto às que o motor monta — sem isto elas apareciam vazias.
    let corpoExemplo: String?
    let conclusaoExemplo: String?
}

struct CatalogSlot: Codable, Hashable, Identifiable {
    let id: String
    let obrigatorio: Bool
    /// Pode sair do modelo?
    ///
    /// NÃO é `!obrigatorio`: os slots de achado são condicionais — só aparecem
    /// quando o médico dita o achado — e mesmo assim não podem ser removidos,
    /// porque removê-los apagaria a patologia do laudo. O servidor recusa a
    /// operação; sem este campo a tela oferecia o botão e o erro só chegava
    /// depois. Opcional para tolerar um backend anterior ao campo.
    let removivel: Bool?
    let placeholdersObrigatorios: [String]
    let condicional: Bool
    let variantes: [CatalogVariant]

    /// Só é removível quando o servidor não disse o contrário.
    var podeSerRemovido: Bool { !obrigatorio && removivel != false }

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

// MARK: - O modelo como LINHAS

/// Um dado do exame dentro de uma frase.
///
/// O servidor unifica as duas formas que existem por baixo — `{dbp}` no
/// catálogo escrito, `____` no modelo derivado — e manda as duas como isto. A
/// tela desenha um chip com `rotulo`; o médico nunca vê a forma crua.
struct DadoDaFrase: Codable, Hashable {
    /// O que inserir na redação para trazer o dado de volta.
    let marcador: String
    let rotulo: String
    /// A redação precisa conservá-lo? Sem este campo o app deixaria apagar
    /// uma medida e só descobriria no 422 do servidor.
    let obrigatorio: Bool
}

/// Uma linha do modelo, na ordem e na seção em que sai no laudo.
///
/// Substitui o que a tela montava sozinha a partir de `slots` + `ordens` — que
/// não carregava seção nem condicionalidade, e por isso a Biblioteca aparecia
/// sem COMENTÁRIOS, sem CONCLUSÃO, e com um descolamento placentário no meio
/// do exame normal.
struct LinhaDoModelo: Codable, Hashable, Identifiable {
    /// "tecnica" | "corpo" | "conclusao"
    let secao: String
    let slot: String
    let variante: String
    let frase: String
    let editavel: Bool
    let motivo: String?
    let obrigatorio: Bool
    let removivel: Bool
    let placeholdersObrigatorios: [String]
    let dados: [DadoDaFrase]

    var id: String { "\(secao)|\(slot)|\(variante)" }
}

/// Um cenário do modelo — "Gestação padrão", "Segundo trimestre"…
struct ModeloProjetado: Codable, Hashable, Identifiable {
    let nome: String
    let linhas: [LinhaDoModelo]
    var id: String { nome }
}

/// Um achado CONDICIONAL — só sai no laudo quando ditado.
///
/// Vem à parte do modelo de propósito: no exame de rotina ele não está, mas o
/// médico precisa vê-lo e poder reescrevê-lo.
struct AchadoProjetado: Codable, Hashable, Identifiable {
    let slot: String
    let removivel: Bool
    let variantes: [CatalogVariant]
    var id: String { slot }
}

struct ReportCatalog: Codable, Hashable {
    let id: String
    let categoria: String
    let estilo: String
    let versao: Int
    let variaveis: [String]
    /// Como cada dado se chama PARA O MÉDICO.
    ///
    /// Sem isto a tela mostrava o nome da variável, e nome de variável é de
    /// programador: `{apresentacao}{dorso_sufixo}{polo_sufixo}` aparecia como
    /// "apresentacaodorso sufixopolo sufixo". Opcional para tolerar um backend
    /// anterior ao campo.
    let rotulosVariaveis: [String: String]?
    let cabecalhos: CatalogHeaders
    let preambulo: String?
    let slots: [CatalogSlot]
    let ordens: [CatalogOrder]
    /// O modelo como LINHAS, por cenário. É o que a tela deve desenhar;
    /// `slots`/`ordens` ficam por compatibilidade com backend antigo.
    let modelos: [ModeloProjetado]?
    /// Os achados condicionais, fora do modelo de rotina.
    let achados: [AchadoProjetado]?
    // Sem CodingKeys pelo mesmo motivo de CategoriaDaBiblioteca: o decoder já
    // converte `rotulos_variaveis` → `rotulosVariaveis`. Aqui o campo é
    // opcional, então o mapeamento errado não lançava — só fazia os rótulos
    // chegarem sempre nulos, e a tela caía no nome cru da variável.
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
    /// Uma categoria que a Biblioteca mostra.
    struct CategoriaDaBiblioteca: Codable, Hashable, Identifiable {
        let categoria: String
        let rotulo: String
        /// O modelo vem do renderer (só normalidade) ou de catálogo escrito
        /// (com as variantes de achado)? A tela usa para não prometer o que a
        /// categoria não tem.
        let derivado: Bool
        /// Esta categoria já aplica a redação do médico nos laudos?
        let personalizacaoAtiva: Bool

        var id: String { categoria }

        /**
         ⚠️ SEM `CodingKeys`, e isto é deliberado.

         `JSONDecoder.api` usa `.convertFromSnakeCase` (APIClient.swift), então
         `personalizacao_ativa` do JSON JÁ CHEGA como `personalizacaoAtiva`. Um
         `CodingKeys` mapeando para a forma snake procura uma chave que não
         existe mais, o decode lança `keyNotFound`, e como esta struct é usada
         dentro de um `catch` que devolve fallback, o erro some: a tela ficava
         com uma categoria só e o seletor não aparecia. Foi exatamente isso que
         aconteceu — e o `catch` silencioso escondeu por dois deploys.
         */
    }

    private struct ListaBody: Decodable { let categorias: [CategoriaDaBiblioteca] }

    /// Enquanto o servidor não responder, é isto que a tela mostra — e era isto
    /// que ela tinha CRAVADO, motivo de o médico só ver o modelo obstétrico por
    /// mais que o backend passasse a servir as outras doze.
    static let categoriasFallback: [CategoriaDaBiblioteca] = [
        .init(categoria: "OBSTETRICA", rotulo: "Obstétrica", derivado: false, personalizacaoAtiva: false)
    ]

    /// As categorias da Biblioteca, do servidor. `nil` = a consulta FALHOU.
    ///
    /// Devolver `nil` em vez do fallback é o que permite ao chamador distinguir
    /// "o servidor respondeu isto" de "não consegui perguntar" — e tentar de
    /// novo depois. Devolvendo o fallback direto, quem chama não tem como saber
    /// que a lista é provisória, e uma falha na primeira tentativa congela uma
    /// categoria só pelo resto da sessão (achado do Codex, 16/08).
    static func categorias() async -> [CategoriaDaBiblioteca]? {
        do {
            let r = try await APIClient.shared.get(base, as: ListaBody.self)
            return r.categorias.isEmpty ? nil : r.categorias
        } catch {
            // O fallback é certo (a tela não pode ficar vazia), mas engolir o
            // motivo não é: um erro de DECODE aqui é indistinguível de "o
            // servidor ainda não tem a rota", e o sintoma é o mesmo — o
            // seletor some. Foi o que atrasou este diagnóstico.
            print("[Biblioteca] falha ao listar categorias, usando fallback: \(error)")
            return nil
        }
    }

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
