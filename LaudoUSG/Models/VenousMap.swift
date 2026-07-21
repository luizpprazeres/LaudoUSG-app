import Foundation

enum VenousSchemeAsset {
    static let anteriorVersion = "venoso-anterior-1"
    static let fourViewVersion = "venous-4view-1"

    static func isSupported(_ version: String) -> Bool {
        version == anteriorVersion || version == fourViewVersion
    }
}

enum VenousSide: String, Codable, Sendable, CaseIterable, Hashable {
    case direito
    case esquerdo

    var title: String {
        switch self {
        case .direito: return "Membro inferior direito"
        case .esquerdo: return "Membro inferior esquerdo"
        }
    }
}

enum EstadoSegmento: String, Codable, Sendable, CaseIterable, Hashable {
    case normal
    case refluxo
    case tromboseOclusiva = "trombose_oclusiva"
    case tromboseParcial = "trombose_parcial"
    case recanalizada
    case varicosidade

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .refluxo: return "Refluxo"
        case .tromboseOclusiva: return "Trombose oclusiva"
        case .tromboseParcial: return "Trombose parcial"
        case .recanalizada: return "Recanalizada"
        case .varicosidade: return "Varicosidade"
        }
    }
}

struct VenousMapSide: Codable, Sendable, Hashable {
    var segmentos: [String: EstadoSegmento]
}

struct MapaVenosoLados: Codable, Sendable, Hashable {
    var direito: VenousMapSide
    var esquerdo: VenousMapSide
}

struct MapaVenoso: Codable, Sendable, Hashable {
    var lados: MapaVenosoLados
    var lesoes: [VenousMapLesion]
    var perfurantes: [VenousMapPerforator]
    var tvpPresente: Bool
    var anotacoes: [VenousAnnotation]? = nil

    private enum CodingKeys: String, CodingKey {
        case lados
        case lesoes
        case perfurantes
        case tvpPresente = "tvp_presente"
        case anotacoes
    }

    func side(_ side: VenousSide) -> VenousMapSide {
        side == .direito ? lados.direito : lados.esquerdo
    }
}

enum VenousAnnotationType: String, Codable, Sendable, Hashable {
    case calibre
    case perfurante
    case refluxo
}

enum VenousAnnotationTopography: String, Codable, Sendable, Hashable {
    case coxa
    case joelho
    case pernaMedial = "perna_medial"
    case panturrilha
}

struct VenousAnnotation: Codable, Sendable, Hashable {
    let lado: VenousSide
    let tipo: VenousAnnotationType
    let texto: String
    let segmento: String?
    let topografia: VenousAnnotationTopography?

    private enum CodingKeys: String, CodingKey {
        case lado
        case tipo
        case texto
        case segmento
        case topografia
    }
}

struct VenousMapLesion: Codable, Sendable, Hashable, Identifiable {
    var id: String { "\(lado.rawValue)-\(segmento)-\(estado.rawValue)-\(label)" }
    var lado: VenousSide
    var segmento: String
    var estado: EstadoSegmento
    var label: String
    var sub: String?
}

struct VenousMapPerforator: Codable, Sendable, Hashable, Identifiable {
    var id: String { "\(lado.rawValue)-\(topografia)-\(label)" }
    var lado: VenousSide
    var topografia: String
    var label: String
    var sub: String?
}

struct VenousSchemePayload: Decodable, Sendable, Hashable {
    let ts: String?
    let examType: String
    let assetVersion: String
    let map: MapaVenoso

    private enum CodingKeys: String, CodingKey {
        case ts
        case examType = "exam_type"
        case assetVersion = "asset_version"
        case map
    }
}

struct VenousPoint: Decodable, Sendable, Hashable {
    let x: Double
    let y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Double.self)
        y = try container.decode(Double.self)
    }
}

struct VenousCoords: Decodable, Sendable, Hashable {
    let width: Int
    let height: Int
    let direito: [String: [VenousPoint]]
    let esquerdo: [String: [VenousPoint]]

    func points(for side: VenousSide, segment: String) -> [VenousPoint]? {
        switch side {
        case .direito: return direito[segment]
        case .esquerdo: return esquerdo[segment]
        }
    }
}

struct VenousCoords4: Decodable, Sendable, Hashable {
    let width: Int
    let height: Int
    let vistas: [String: [String: [VenousPoint]]]
}
