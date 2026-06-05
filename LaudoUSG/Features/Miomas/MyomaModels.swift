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

/// Localização do mioma na parede uterina.
enum MyomaLocation: String, CaseIterable, Identifiable {
    case anterior = "Anterior"
    case posterior = "Posterior"
    case lateralDireita = "Lateral direita"
    case lateralEsquerda = "Lateral esquerda"
    case fundo = "Fundo"
    case cervical = "Cervical"
    var id: String { rawValue }

    /// Posição canônica na visão TRANSVERSAL (ref 560×400).
    var axPoint: CGPoint {
        switch self {
        case .anterior:        return CGPoint(x: 280, y: 150)
        case .posterior:       return CGPoint(x: 280, y: 252)
        case .lateralDireita:  return CGPoint(x: 420, y: 188)
        case .lateralEsquerda: return CGPoint(x: 140, y: 200)
        case .fundo:           return CGPoint(x: 280, y: 200)
        case .cervical:        return CGPoint(x: 280, y: 320)
        }
    }
}

/// Ecotextura do nódulo (opcional).
enum MyomaEcho: String, CaseIterable, Identifiable {
    case hipoecoica = "Hipoecoica"
    case heterogenea = "Heterogênea"
    case calcificada = "Calcificada"
    case degenerada = "Degenerada"
    var id: String { rawValue }
}

/// Achado de mioma — modelo do editor (Step 2).
struct MyomaFinding: Identifiable {
    let id = UUID()
    var figo: Int = 4
    var sizeMaxMm: Double? = 20
    var localizacao: MyomaLocation = .anterior
    var ecotextura: MyomaEcho? = nil
    /// Override explícito de posição (Step 3 = drag); senão usa o canônico.
    var sagPoint: CGPoint? = nil
    var axPoint: CGPoint? = nil

    var family: FigoFamily { FigoCategory.family(figo) }

    /// Posição na visão LONGITUDINAL — canônica por FIGO (ref 420×520, vertical).
    var canonicalSag: CGPoint { FigoLayout.sagPoint(figo) }
    /// Posição na visão TRANSVERSAL — por localização.
    var canonicalAx: CGPoint { localizacao.axPoint }
}

/// Posições canônicas dos FIGO 0–8 na visão longitudinal (coords do mockup).
enum FigoLayout {
    static func sagPoint(_ figo: Int) -> CGPoint {
        switch figo {
        case 0: return CGPoint(x: 208, y: 236)
        case 1: return CGPoint(x: 176, y: 250)
        case 2: return CGPoint(x: 244, y: 250)
        case 3: return CGPoint(x: 150, y: 300)
        case 4: return CGPoint(x: 272, y: 300)
        case 5: return CGPoint(x: 120, y: 210)
        case 6: return CGPoint(x: 304, y: 168)
        case 7: return CGPoint(x: 360, y: 108)
        default: return CGPoint(x: 232, y: 440)   // 8 — cervical
        }
    }
}

extension MyomaFinding {
    /// Um exemplo de cada FIGO (espelha o mockup aprovado).
    static let exemplos: [MyomaFinding] = (0...8).map { figo in
        let loc: MyomaLocation
        switch figo {
        case 1, 3, 5: loc = .anterior
        case 2, 4, 6: loc = .posterior
        case 7: loc = .lateralDireita
        case 8: loc = .cervical
        default: loc = .fundo
        }
        return MyomaFinding(figo: figo, sizeMaxMm: 18 + Double(figo) * 1.5, localizacao: loc)
    }
}
