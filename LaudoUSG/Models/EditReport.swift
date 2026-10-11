import Foundation

/// Edição incremental de laudo pronto (`POST /api/edit`).
///
/// O servidor reescreve o laudo armazenado satisfazendo SÓ o ajuste pedido e um
/// diff-guard determinístico barra edição ampla. Contrato em
/// `laudousgmobile-def/packages/shared/src/schemas/edit.ts`.
///
/// Dois fatos do contrato que a UI precisa respeitar:
/// - `accepted: true` → o servidor JÁ gravou o texto editado no report.
/// - `accepted: false` → nada foi gravado e `edited_text` volta IGUAL ao texto-base
///   (não é a proposta). A proposta do modelo só existe em `changed_lines`. Por isso
///   não há "aplicar mesmo assim": a versão antiga do botão aplicava o texto-base e
///   não fazia nada.
enum AdjustTarget: String, CaseIterable, Identifiable, Equatable {
    case body
    case conclusion
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .body: return "Corpo"
        case .conclusion: return "Conclusão"
        case .both: return "Corpo e conclusão"
        }
    }
}

/// Escolha da UI. "Automático" resolve pelo que o médico disse — a v1 obrigava a
/// escolher num seletor de três segmentos antes de falar, e o padrão "Corpo"
/// barrava ajustes que tocavam a conclusão.
enum AdjustTargetChoice: String, CaseIterable, Identifiable, Equatable {
    case automatic
    case body
    case conclusion
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "Automático"
        case .body: return AdjustTarget.body.label
        case .conclusion: return AdjustTarget.conclusion.label
        case .both: return AdjustTarget.both.label
        }
    }

    func resolve(for instruction: String) -> AdjustTarget {
        switch self {
        case .body: return .body
        case .conclusion: return .conclusion
        case .both: return .both
        case .automatic: return Self.inferTarget(from: instruction)
        }
    }

    /// "na conclusão…" → conclusão; menciona conclusão E corpo/achados → ambos;
    /// o resto → corpo (o backend já ajusta a conclusão normal num acréscimo).
    static func inferTarget(from instruction: String) -> AdjustTarget {
        let text = instruction.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
        let mentionsConclusion = text.contains("conclusao") || text.contains("impressao")
        guard mentionsConclusion else { return .body }
        let mentionsBody = text.contains("corpo") || text.contains("achados") || text.contains("descricao")
        return mentionsBody ? .both : .conclusion
    }
}

struct EditReportRequest: Encodable, Equatable {
    let reportId: String
    let instruction: String
    let target: String
}

struct EditReportChangedLine: Decodable, Equatable {
    let line: Int
    let before: String?
    let after: String?
    let section: String
}

struct EditReportResponse: Decodable, Equatable {
    let editedText: String
    let changedLines: [EditReportChangedLine]
    let accepted: Bool
    let reason: String?
}

/// Recusa do diff-guard traduzida para o médico. O `reason` do servidor é curto e
/// técnico ("edição ampla — confirme"); o "confirme" não tem o que confirmar no app.
struct AdjustRejection: Equatable {
    let title: String
    let message: String
    /// Alvo mais amplo que provavelmente resolve numa nova tentativa.
    let retryTarget: AdjustTarget?
    let retryLabel: String?

    static let intactNotice = "Seu laudo não foi alterado."

    static func from(reason: String?, target: AdjustTarget) -> AdjustRejection {
        let raw = (reason ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))

        if raw.contains("sem alteracao") {
            return AdjustRejection(
                title: "O pedido não mudou nada",
                message: "Tente dizer de outro jeito, citando a frase, o órgão ou a medida.",
                retryTarget: nil,
                retryLabel: nil
            )
        }
        if raw.contains("conclusao normal") {
            return AdjustRejection(
                title: "A conclusão ficaria contraditória",
                message: "O achado entrou no corpo, mas a conclusão continuou dizendo que o exame é normal. Para não deixar o laudo se contradizendo, nada foi aplicado.",
                retryTarget: .both,
                retryLabel: "Tentar ajustando a conclusão também"
            )
        }
        if raw.contains("edicao ampla") {
            return AdjustRejection(
                title: "Mudança grande demais",
                message: "Para atender o pedido seriam alteradas mais de 3 linhas. Por segurança, faça um ajuste por vez.",
                retryTarget: nil,
                retryLabel: nil
            )
        }
        if raw.contains("fora da conclusao") {
            return AdjustRejection(
                title: "O corpo do laudo também mudaria",
                message: "O ajuste foi pedido na conclusão, mas mexia também no corpo do laudo.",
                retryTarget: .both,
                retryLabel: "Permitir mexer no corpo"
            )
        }
        if raw.contains("na conclusao") {
            return AdjustRejection(
                title: "A conclusão também mudaria",
                message: "O ajuste foi pedido no corpo do laudo, mas mexia também na conclusão.",
                retryTarget: .both,
                retryLabel: "Permitir mexer na conclusão"
            )
        }
        let fallback = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return AdjustRejection(
            title: "O ajuste não foi aplicado",
            message: fallback.isEmpty ? "O servidor recusou o ajuste." : "Motivo: \(fallback).",
            retryTarget: target == .both ? nil : .both,
            retryLabel: target == .both ? nil : "Tentar com corpo e conclusão"
        )
    }
}
