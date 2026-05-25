import Foundation

/// Achado em segmento venoso no esquema de cartografia MMII.
/// Espelha `VenousSegmentFinding` da web (`lib/vascular/venousCartography.ts`).
struct VenousFinding: Identifiable, Equatable, Hashable {

    enum Side: String, Sendable, CaseIterable, Identifiable {
        case direita
        case esquerda

        var id: String { rawValue }

        var label: String {
            self == .direita ? "Membro inferior direito" : "Membro inferior esquerdo"
        }

        var shortLabel: String { self == .direita ? "D" : "E" }
    }

    enum Vessel: String, Sendable, CaseIterable {
        case vfc       // Veia femoral comum
        case vf        // Veia femoral
        case vfp       // Veia femoral profunda
        case pop       // Veia poplítea
        case vtp       // Veias tibiais posteriores
        case vfib      // Veias fibulares
        case vsm       // Veia safena magna
        case vsp       // Veia safena parva
        case jsf       // Junção safeno-femoral
        case jsp       // Junção safeno-poplítea
        case perfurante
        case colateral

        var label: String {
            switch self {
            case .vfc: return "Veia femoral comum"
            case .vf: return "Veia femoral"
            case .vfp: return "Veia femoral profunda"
            case .pop: return "Veia poplítea"
            case .vtp: return "Veias tibiais posteriores"
            case .vfib: return "Veias fibulares"
            case .vsm: return "Veia safena magna"
            case .vsp: return "Veia safena parva"
            case .jsf: return "Junção safeno-femoral"
            case .jsp: return "Junção safeno-poplítea"
            case .perfurante: return "Perfurante"
            case .colateral: return "Colateral / varicosidade"
            }
        }
    }

    enum View: String, Sendable, CaseIterable {
        case anterior, medial, posterior, lateral

        var label: String {
            switch self {
            case .anterior: return "Anterior"
            case .medial: return "Medial"
            case .posterior: return "Posterior"
            case .lateral: return "Lateral"
            }
        }
    }

    enum Region: String, Sendable, CaseIterable {
        case coxaProximal = "coxa_proximal"
        case coxaMedia = "coxa_media"
        case coxaDistal = "coxa_distal"
        case joelho
        case pernaProximal = "perna_proximal"
        case pernaMedia = "perna_media"
        case pernaDistal = "perna_distal"
        case tornozelo

        var label: String {
            switch self {
            case .coxaProximal: return "Coxa proximal"
            case .coxaMedia: return "Coxa média"
            case .coxaDistal: return "Coxa distal"
            case .joelho: return "Joelho"
            case .pernaProximal: return "Perna proximal"
            case .pernaMedia: return "Perna média"
            case .pernaDistal: return "Perna distal"
            case .tornozelo: return "Tornozelo"
            }
        }
    }

    /// Status venoso — define cor/dash/espessura do segmento na cartografia.
    enum Status: String, Sendable, CaseIterable, Identifiable {
        case suficiente
        case refluxo
        case tromboseAguda = "trombose_aguda"
        case tromboseCronica = "trombose_cronica"
        case sequelaTvp = "sequela_tvp"
        case parcialRecanalizada = "parcial_recanalizada"
        case safenectomizada
        case extrafascial

        var id: String { rawValue }

        var label: String {
            switch self {
            case .suficiente: return "Suficiente"
            case .refluxo: return "Refluxo"
            case .tromboseAguda: return "Trombose aguda"
            case .tromboseCronica: return "Trombose crônica"
            case .sequelaTvp: return "Sequela de TVP"
            case .parcialRecanalizada: return "Parcial recanalizada"
            case .safenectomizada: return "Safenectomizada"
            case .extrafascial: return "Extrafascial"
            }
        }

        /// Cor clínica (hex sem #) — mantida idêntica à web.
        var colorHex: String {
            switch self {
            case .suficiente: return "2563EB"           // blue-600
            case .refluxo: return "DC2626"              // red-600
            case .tromboseAguda: return "1E3A8A"        // blue-900
            case .tromboseCronica: return "1E40AF"      // blue-800
            case .sequelaTvp: return "7C3AED"           // purple-600
            case .parcialRecanalizada: return "075985"  // sky-800
            case .safenectomizada: return "6B7280"      // gray-500
            case .extrafascial: return "0284C7"         // sky-600
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .suficiente: return 3
            case .refluxo: return 3.5
            case .tromboseAguda: return 5
            case .tromboseCronica: return 4
            case .sequelaTvp: return 4
            case .parcialRecanalizada: return 4
            case .safenectomizada: return 3
            case .extrafascial: return 3
            }
        }

        var dash: [CGFloat] {
            switch self {
            case .suficiente: return []
            case .refluxo: return []
            case .tromboseAguda: return []
            case .tromboseCronica: return [5, 3]
            case .sequelaTvp: return [6, 3]
            case .parcialRecanalizada: return [2, 3]
            case .safenectomizada: return [7, 4]
            case .extrafascial: return [1, 3]
            }
        }
    }

    enum ThrombusOcclusion: String, Sendable {
        case parcial, total
    }

    enum Source: String, Sendable {
        case parsed, manual
    }

    let id: String
    var side: Side
    var segmentId: String       // referencia VenousSegment.id
    var vessel: Vessel
    var view: View
    var region: Region?
    var status: Status
    var refluxSeconds: Double?
    var diameterMm: Double?
    var thrombusOcclusion: ThrombusOcclusion?
    var compressible: Bool?
    var source: Source

    init(
        id: String = VenousFinding.generateId(),
        side: Side,
        segmentId: String,
        vessel: Vessel,
        view: View,
        region: Region? = nil,
        status: Status,
        refluxSeconds: Double? = nil,
        diameterMm: Double? = nil,
        thrombusOcclusion: ThrombusOcclusion? = nil,
        compressible: Bool? = nil,
        source: Source = .manual
    ) {
        self.id = id
        self.side = side
        self.segmentId = segmentId
        self.vessel = vessel
        self.view = view
        self.region = region
        self.status = status
        self.refluxSeconds = refluxSeconds
        self.diameterMm = diameterMm
        self.thrombusOcclusion = thrombusOcclusion
        self.compressible = compressible
        self.source = source
    }

    static func generateId() -> String { UUID().uuidString }
}
