import Foundation

/// Edição incremental de laudo (POST /api/edit). O interpretador reescreve o laudo
/// satisfazendo SÓ o ajuste pedido; um diff-guard determinístico no servidor barra
/// over-edit. `accepted=false` → devolve o texto proposto + motivo (o app confirma).
/// Onde aplicar o ajuste: corpo do laudo / conclusão / ambos.
enum AdjustTarget: String, CaseIterable, Identifiable {
    case body
    case conclusion
    case both

    var id: String { rawValue }
    var label: String {
        switch self {
        case .body: return "Corpo"
        case .conclusion: return "Conclusão"
        case .both: return "Ambos"
        }
    }
}

struct EditReportRequest: Encodable {
    let reportId: String
    let instruction: String
    let target: String
}

struct EditReportChangedLine: Decodable, Identifiable {
    var id: Int { line }
    let line: Int
    let before: String?
    let after: String?
    let section: String
}

struct EditReportResponse: Decodable {
    let editedText: String
    let changedLines: [EditReportChangedLine]
    let accepted: Bool
    let reason: String?
}
