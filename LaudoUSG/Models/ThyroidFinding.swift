import Foundation

/// Achado nodular no esquema tireoidiano.
/// Espelha `lib/tireoide/parseFindings.ts` da web.
struct ThyroidFinding: Identifiable, Equatable, Hashable {

    /// Posição anatômica (3 buckets verticais: lobo D, istmo central, lobo E).
    enum Side: String, Sendable, CaseIterable, Identifiable {
        case direito
        case esquerdo
        case istmo

        var id: String { rawValue }

        var label: String {
            switch self {
            case .direito: return "Lobo direito"
            case .esquerdo: return "Lobo esquerdo"
            case .istmo: return "Istmo"
            }
        }

        var shortLabel: String {
            switch self {
            case .direito: return "LD"
            case .esquerdo: return "LE"
            case .istmo: return "Istmo"
            }
        }
    }

    /// Terço do lobo (não se aplica ao istmo).
    enum Tercio: String, Sendable, CaseIterable, Identifiable {
        case superior
        case medio
        case inferior

        var id: String { rawValue }

        var label: String {
            switch self {
            case .superior: return "Terço superior"
            case .medio: return "Terço médio"
            case .inferior: return "Terço inferior"
            }
        }

        var shortLabel: String {
            switch self {
            case .superior: return "sup"
            case .medio: return "med"
            case .inferior: return "inf"
            }
        }
    }

    /// Tipo do nódulo. Define forma e preenchimento do marcador (P&B uniforme).
    enum FindingType: String, Sendable, CaseIterable, Identifiable {
        case cystic           // cisto / anecoico — círculo branco com borda preta
        case spongiform       // esponjoso — círculo branco com borda preta tracejada
        case mixed            // misto sólido-cístico — meia bola
        case solid            // sólido — círculo preto preenchido
        case calcification    // calcificação — losango preto pequeno

        var id: String { rawValue }

        var label: String {
            switch self {
            case .cystic: return "Cisto"
            case .spongiform: return "Esponjoso"
            case .mixed: return "Misto"
            case .solid: return "Nódulo sólido"
            case .calcification: return "Calcificação"
            }
        }
    }

    /// Forma do nódulo (afeta o desenho — round/oval/lobulated).
    enum Shape: String, Sendable, CaseIterable, Identifiable {
        case round
        case oval
        case lobulated

        var id: String { rawValue }

        var label: String {
            switch self {
            case .round: return "Arredondado"
            case .oval: return "Oval"
            case .lobulated: return "Lobulado"
            }
        }
    }

    enum Margins: String, Sendable, CaseIterable, Identifiable {
        case regular
        case irregular
        case spiculated

        var id: String { rawValue }

        var label: String {
            switch self {
            case .regular: return "Regulares"
            case .irregular: return "Irregulares"
            case .spiculated: return "Espiculadas"
            }
        }
    }

    enum Echogenicity: String, Sendable, CaseIterable, Identifiable {
        case anechoic
        case hypo
        case iso
        case hyper
        case mixed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .anechoic: return "Anecoico"
            case .hypo: return "Hipoecoico"
            case .iso: return "Isoecoico"
            case .hyper: return "Hiperecoico"
            case .mixed: return "Heterogêneo"
            }
        }
    }

    enum Source: String, Sendable {
        case parsed
        case manual
    }

    let id: String
    var side: Side
    var tercio: Tercio?
    var type: FindingType
    var shape: Shape?
    var sizeMax: Double?            // mm
    var margins: Margins?
    var echogenicity: Echogenicity?
    var tiRads: Int?                // 1-5
    var approximate: Bool
    var source: Source

    init(
        id: String = ThyroidFinding.generateId(),
        side: Side,
        tercio: Tercio? = nil,
        type: FindingType,
        shape: Shape? = nil,
        sizeMax: Double? = nil,
        margins: Margins? = nil,
        echogenicity: Echogenicity? = nil,
        tiRads: Int? = nil,
        approximate: Bool = false,
        source: Source = .manual
    ) {
        self.id = id
        self.side = side
        self.tercio = tercio
        self.type = type
        self.shape = shape
        self.sizeMax = sizeMax
        self.margins = margins
        self.echogenicity = echogenicity
        self.tiRads = tiRads
        self.approximate = approximate
        self.source = source
    }

    static func generateId() -> String {
        UUID().uuidString
    }
}
