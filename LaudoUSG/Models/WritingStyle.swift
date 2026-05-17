import Foundation

struct WritingStyleRecord: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let slug: String
    let label: String
    let description: String?
    let isDefault: Bool
    let categoryCode: String?
}

enum WritingStyle: String, CaseIterable, Identifiable, Codable {
    case tradicional = "tradicional"
    case estruturado = "estruturado"
    case livre = "livre"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tradicional: return "Tradicional"
        case .estruturado: return "Estruturado"
        case .livre: return "Livre"
        }
    }

    var description: String {
        switch self {
        case .tradicional: return "Texto corrido, médico-pra-médico."
        case .estruturado: return "Tópicos, listas e medidas em destaque."
        case .livre: return "Sem template — usa exatamente o que você ditou."
        }
    }
}
