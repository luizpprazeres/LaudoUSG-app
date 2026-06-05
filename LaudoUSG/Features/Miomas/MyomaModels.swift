import SwiftUI

/// Família FIGO — agrupa as 9 categorias por tipo/cor (igual ao mockup aprovado).
enum FigoFamily {
    case submucoso    // 0, 1, 2
    case intramural   // 3, 4
    case subseroso    // 5, 6, 7
    case outros       // 8

    var color: Color {
        switch self {
        case .submucoso:  return Color(hex: "E0584A")
        case .intramural: return Color(hex: "D8932B")
        case .subseroso:  return Color(hex: "7B59C6")
        case .outros:     return Color(hex: "3D8BBF")
        }
    }
    var titulo: String {
        switch self {
        case .submucoso:  return "Submucosos"
        case .intramural: return "Intramurais"
        case .subseroso:  return "Subserosos"
        case .outros:     return "Outros"
        }
    }
}

/// Categoria FIGO PALM-COEIN (parte L — leiomioma), 0–8.
struct FigoCategory: Identifiable {
    let figo: Int
    let family: FigoFamily
    let titulo: String
    let descricao: String
    var id: Int { figo }

    static let all: [FigoCategory] = [
        .init(figo: 0, family: .submucoso,  titulo: "Pediculado intracavitário", descricao: "Dentro da cavidade, com haste"),
        .init(figo: 1, family: .submucoso,  titulo: "< 50% intramural",          descricao: "Faz contato com o endométrio"),
        .init(figo: 2, family: .submucoso,  titulo: "≥ 50% intramural",          descricao: "Faz contato com o endométrio"),
        .init(figo: 3, family: .intramural, titulo: "Contato com endométrio",    descricao: "100% intramural, toca a cavidade"),
        .init(figo: 4, family: .intramural, titulo: "Intramural puro",           descricao: "Sem tocar endométrio nem serosa"),
        .init(figo: 5, family: .subseroso,  titulo: "≥ 50% intramural",          descricao: "Faz contato com a serosa"),
        .init(figo: 6, family: .subseroso,  titulo: "< 50% intramural",          descricao: "Faz contato com a serosa"),
        .init(figo: 7, family: .subseroso,  titulo: "Pediculado externo",        descricao: "Externo, com haste"),
        .init(figo: 8, family: .outros,     titulo: "Localização atípica",       descricao: "Cervical, ligamento largo, parasitário"),
    ]

    static func family(_ figo: Int) -> FigoFamily {
        all.first { $0.figo == figo }?.family ?? .outros
    }
}

/// Achado de mioma. Step 1 usa exemplos hardcoded (Step 2 = editor manual).
struct MyomaFinding: Identifiable {
    let id = UUID()
    var figo: Int
    var sizeMaxMm: Double?      // maior eixo → tamanho do marcador
    /// Posição no frame de DESIGN de cada visão (mesmas coords do mockup).
    var sagPoint: CGPoint?      // longitudinal — ref 420×520 (vertical, antes da rotação)
    var axPoint: CGPoint?       // transversal — ref 560×400

    var family: FigoFamily { FigoCategory.family(figo) }
}

extension MyomaFinding {
    /// Um exemplo de cada FIGO (espelha o mockup aprovado).
    static let exemplos: [MyomaFinding] = [
        .init(figo: 0, sizeMaxMm: 14, sagPoint: CGPoint(x: 208, y: 236), axPoint: nil),
        .init(figo: 1, sizeMaxMm: 22, sagPoint: CGPoint(x: 176, y: 250), axPoint: CGPoint(x: 280, y: 150)),
        .init(figo: 2, sizeMaxMm: 24, sagPoint: CGPoint(x: 244, y: 250), axPoint: nil),
        .init(figo: 3, sizeMaxMm: 30, sagPoint: CGPoint(x: 150, y: 300), axPoint: CGPoint(x: 280, y: 252)),
        .init(figo: 4, sizeMaxMm: 30, sagPoint: CGPoint(x: 272, y: 300), axPoint: CGPoint(x: 140, y: 200)),
        .init(figo: 5, sizeMaxMm: 26, sagPoint: CGPoint(x: 120, y: 210), axPoint: nil),
        .init(figo: 6, sizeMaxMm: 26, sagPoint: CGPoint(x: 304, y: 168), axPoint: CGPoint(x: 420, y: 178)),
        .init(figo: 7, sizeMaxMm: 18, sagPoint: CGPoint(x: 360, y: 108), axPoint: CGPoint(x: 514, y: 262)),
        .init(figo: 8, sizeMaxMm: 16, sagPoint: CGPoint(x: 232, y: 440), axPoint: nil),
    ]
}
