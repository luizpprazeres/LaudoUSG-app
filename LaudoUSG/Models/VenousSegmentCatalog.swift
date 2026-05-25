import SwiftUI

/// Catálogo dos 18 segmentos venosos pré-definidos, com paths Bezier portados
/// fielmente de `components/vascular/VenousCartographyDisplay.tsx` da web.
///
/// Cada segmento tem path em coordenadas lógicas (760×700 do SVG da web),
/// construído a partir do `x` base da vista (anterior=50, medial=235, posterior=420, lateral=605).
enum VenousSegmentCatalog {

    struct Segment: Identifiable, Hashable {
        let id: String
        let vessel: VenousFinding.Vessel
        let view: VenousFinding.View
        let region: VenousFinding.Region?
        let label: String
        let shortLabel: String
    }

    static let all: [Segment] = [
        .init(id: "vfc", vessel: .vfc, view: .anterior, region: .coxaProximal,
              label: "Veia femoral comum", shortLabel: "VFC"),
        .init(id: "vf", vessel: .vf, view: .anterior, region: .coxaMedia,
              label: "Veia femoral", shortLabel: "VF"),
        .init(id: "vfp", vessel: .vfp, view: .anterior, region: .coxaProximal,
              label: "Veia femoral profunda", shortLabel: "VFP"),
        .init(id: "pop-anterior", vessel: .pop, view: .anterior, region: .joelho,
              label: "Veia poplítea (anterior)", shortLabel: "Pop"),
        .init(id: "vtp", vessel: .vtp, view: .anterior, region: .pernaMedia,
              label: "Veias tibiais posteriores", shortLabel: "VTP"),
        .init(id: "vfib", vessel: .vfib, view: .anterior, region: .pernaMedia,
              label: "Veias fibulares", shortLabel: "VFib"),
        .init(id: "jsf", vessel: .jsf, view: .medial, region: .coxaProximal,
              label: "Junção safeno-femoral", shortLabel: "JSF"),
        .init(id: "vsm-coxa-proximal", vessel: .vsm, view: .medial, region: .coxaProximal,
              label: "Safena magna — coxa proximal", shortLabel: "VSM"),
        .init(id: "vsm-coxa-media", vessel: .vsm, view: .medial, region: .coxaMedia,
              label: "Safena magna — coxa média", shortLabel: "VSM"),
        .init(id: "vsm-coxa-distal", vessel: .vsm, view: .medial, region: .coxaDistal,
              label: "Safena magna — coxa distal/joelho", shortLabel: "VSM"),
        .init(id: "vsm-perna", vessel: .vsm, view: .medial, region: .pernaMedia,
              label: "Safena magna — perna", shortLabel: "VSM"),
        .init(id: "pop-posterior", vessel: .pop, view: .posterior, region: .joelho,
              label: "Veia poplítea", shortLabel: "Pop"),
        .init(id: "jsp", vessel: .jsp, view: .posterior, region: .joelho,
              label: "Junção safeno-poplítea", shortLabel: "JSP"),
        .init(id: "vsp-proximal", vessel: .vsp, view: .posterior, region: .pernaProximal,
              label: "Safena parva — perna proximal", shortLabel: "VSP"),
        .init(id: "vsp-distal", vessel: .vsp, view: .posterior, region: .pernaDistal,
              label: "Safena parva — perna distal", shortLabel: "VSP"),
        .init(id: "gastrocnemias", vessel: .colateral, view: .posterior, region: .pernaMedia,
              label: "Veias gastrocnêmias/colaterais", shortLabel: "Gastr"),
        .init(id: "perfurante-coxa", vessel: .perfurante, view: .medial, region: .coxaMedia,
              label: "Perfurante de coxa", shortLabel: "Perf"),
        .init(id: "perfurante-perna", vessel: .perfurante, view: .medial, region: .pernaMedia,
              label: "Perfurante de perna", shortLabel: "Perf"),
    ]

    static func segment(id: String) -> Segment? {
        all.first { $0.id == id }
    }

    /// Constrói o path Bezier do segmento em coordenadas lógicas (760×700).
    /// Espelha as funções de `SEGMENT_PATHS` da web (`x` é o offset da vista).
    static func path(for segmentId: String) -> Path? {
        guard let segment = segment(id: segmentId) else { return nil }
        let x = viewBaseX(for: segment.view)
        var p = Path()

        switch segmentId {
        case "vfc":
            p.move(to: CGPoint(x: x + 58, y: 76))
            p.addCurve(to: CGPoint(x: x + 70, y: 176),
                       control1: CGPoint(x: x + 72, y: 98),
                       control2: CGPoint(x: x + 76, y: 132))
        case "vf":
            p.move(to: CGPoint(x: x + 70, y: 170))
            p.addCurve(to: CGPoint(x: x + 58, y: 318),
                       control1: CGPoint(x: x + 72, y: 220),
                       control2: CGPoint(x: x + 68, y: 262))
        case "vfp":
            p.move(to: CGPoint(x: x + 58, y: 95))
            p.addCurve(to: CGPoint(x: x + 25, y: 176),
                       control1: CGPoint(x: x + 38, y: 115),
                       control2: CGPoint(x: x + 28, y: 146))
        case "pop-anterior":
            p.move(to: CGPoint(x: x + 58, y: 318))
            p.addCurve(to: CGPoint(x: x + 58, y: 374),
                       control1: CGPoint(x: x + 55, y: 340),
                       control2: CGPoint(x: x + 55, y: 356))
        case "vtp":
            p.move(to: CGPoint(x: x + 54, y: 374))
            p.addCurve(to: CGPoint(x: x + 50, y: 545),
                       control1: CGPoint(x: x + 44, y: 430),
                       control2: CGPoint(x: x + 44, y: 488))
        case "vfib":
            p.move(to: CGPoint(x: x + 66, y: 374))
            p.addCurve(to: CGPoint(x: x + 68, y: 545),
                       control1: CGPoint(x: x + 78, y: 430),
                       control2: CGPoint(x: x + 76, y: 488))
        case "jsf":
            p.move(to: CGPoint(x: x + 54, y: 84))
            p.addLine(to: CGPoint(x: x + 72, y: 84))
        case "vsm-coxa-proximal":
            p.move(to: CGPoint(x: x + 55, y: 90))
            p.addCurve(to: CGPoint(x: x + 70, y: 205),
                       control1: CGPoint(x: x + 65, y: 125),
                       control2: CGPoint(x: x + 70, y: 165))
        case "vsm-coxa-media":
            p.move(to: CGPoint(x: x + 70, y: 198))
            p.addCurve(to: CGPoint(x: x + 64, y: 320),
                       control1: CGPoint(x: x + 72, y: 240),
                       control2: CGPoint(x: x + 70, y: 278))
        case "vsm-coxa-distal":
            p.move(to: CGPoint(x: x + 64, y: 318))
            p.addCurve(to: CGPoint(x: x + 62, y: 420),
                       control1: CGPoint(x: x + 58, y: 358),
                       control2: CGPoint(x: x + 57, y: 390))
        case "vsm-perna":
            p.move(to: CGPoint(x: x + 62, y: 420))
            p.addCurve(to: CGPoint(x: x + 62, y: 550),
                       control1: CGPoint(x: x + 66, y: 465),
                       control2: CGPoint(x: x + 66, y: 512))
        case "pop-posterior":
            p.move(to: CGPoint(x: x + 60, y: 312))
            p.addCurve(to: CGPoint(x: x + 60, y: 392),
                       control1: CGPoint(x: x + 60, y: 342),
                       control2: CGPoint(x: x + 60, y: 368))
        case "jsp":
            p.move(to: CGPoint(x: x + 48, y: 326))
            p.addCurve(to: CGPoint(x: x + 76, y: 328),
                       control1: CGPoint(x: x + 58, y: 318),
                       control2: CGPoint(x: x + 68, y: 318))
        case "vsp-proximal":
            p.move(to: CGPoint(x: x + 60, y: 390))
            p.addCurve(to: CGPoint(x: x + 60, y: 482),
                       control1: CGPoint(x: x + 62, y: 422),
                       control2: CGPoint(x: x + 62, y: 452))
        case "vsp-distal":
            p.move(to: CGPoint(x: x + 60, y: 480))
            p.addCurve(to: CGPoint(x: x + 58, y: 560),
                       control1: CGPoint(x: x + 60, y: 508),
                       control2: CGPoint(x: x + 60, y: 536))
        case "gastrocnemias":
            // Path duplo (2 ramos)
            p.move(to: CGPoint(x: x + 44, y: 390))
            p.addCurve(to: CGPoint(x: x + 48, y: 500),
                       control1: CGPoint(x: x + 34, y: 430),
                       control2: CGPoint(x: x + 38, y: 468))
            p.move(to: CGPoint(x: x + 76, y: 390))
            p.addCurve(to: CGPoint(x: x + 72, y: 500),
                       control1: CGPoint(x: x + 88, y: 430),
                       control2: CGPoint(x: x + 84, y: 468))
        case "perfurante-coxa":
            p.move(to: CGPoint(x: x + 44, y: 220))
            p.addLine(to: CGPoint(x: x + 72, y: 220))
        case "perfurante-perna":
            p.move(to: CGPoint(x: x + 42, y: 430))
            p.addLine(to: CGPoint(x: x + 70, y: 430))
        default:
            return nil
        }
        return p
    }

    static func viewBaseX(for view: VenousFinding.View) -> CGFloat {
        switch view {
        case .anterior: return 50
        case .medial: return 235
        case .posterior: return 420
        case .lateral: return 605
        }
    }

    /// Posição central aproximada do segmento (em coords lógicas) — útil pra labels/tooltips.
    static func centerPoint(for segmentId: String) -> CGPoint? {
        guard let path = path(for: segmentId) else { return nil }
        let bbox = path.boundingRect
        return CGPoint(x: bbox.midX, y: bbox.midY)
    }
}
