import Foundation

/// Edição incremental de laudo (POST /api/edit). O interpretador reescreve o laudo
/// satisfazendo SÓ o ajuste pedido; um diff-guard determinístico no servidor barra
/// over-edit. `accepted=false` → devolve o texto proposto + motivo (o app confirma).
struct EditReportRequest: Encodable {
    let reportId: String
    let instruction: String
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
