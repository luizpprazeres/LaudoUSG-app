import Foundation

/// Achado focal no esquema mamário.
/// Espelha o modelo `BreastFinding` da web (`lib/mamas/parseFindings.ts`).
struct BreastFinding: Identifiable, Equatable, Hashable {
    enum Side: String, Sendable, CaseIterable, Identifiable {
        case direita
        case esquerda

        var id: String { rawValue }
        var label: String { self == .direita ? "Direita" : "Esquerda" }
        var shortLabel: String { self == .direita ? "D" : "E" }
    }

    /// Tipo do achado — define a forma do marcador no SVG.
    enum FindingType: String, Sendable, CaseIterable, Identifiable {
        case solid              // nódulo sólido (círculo preto)
        case solidLobulated     // nódulo lobulado (path com 4 lóbulos)
        case cyst               // cisto (círculo branco com borda)
        case lymphNode          // linfonodo (elipse com núcleo)
        case calcification      // calcificação (quadrado rotacionado 45°)

        var id: String { rawValue }

        var label: String {
            switch self {
            case .solid: return "Nódulo"
            case .solidLobulated: return "Nódulo lobulado"
            case .cyst: return "Cisto"
            case .lymphNode: return "Linfonodo"
            case .calcification: return "Calcificação"
            }
        }
    }

    enum Quadrant: String, Sendable {
        case qsm  // Superior medial
        case qsl  // Superior lateral
        case qim  // Inferior medial
        case qil  // Inferior lateral
    }

    enum Source: String, Sendable {
        case parsed
        case manual
    }

    let id: String
    var side: Side
    var type: FindingType
    var hora: Int?            // 1-12 (posição no relógio mamário)
    var quadrant: Quadrant?   // fallback quando não há hora
    var sizeMax: Double?      // mm (eixo maior)
    var distMamilo: Double?   // cm (distância do mamilo, 0-6)
    var approximate: Bool
    var source: Source

    init(
        id: String = BreastFinding.generateId(),
        side: Side,
        type: FindingType,
        hora: Int? = nil,
        quadrant: Quadrant? = nil,
        sizeMax: Double? = nil,
        distMamilo: Double? = nil,
        approximate: Bool = false,
        source: Source = .manual
    ) {
        self.id = id
        self.side = side
        self.type = type
        self.hora = hora
        self.quadrant = quadrant
        self.sizeMax = sizeMax
        self.distMamilo = distMamilo
        self.approximate = approximate
        self.source = source
    }

    static func generateId() -> String {
        UUID().uuidString
    }
}
