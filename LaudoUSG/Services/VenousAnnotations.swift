import Foundation

struct VenousAnnotationLabel: Sendable, Hashable {
    enum Side: String, Sendable, Hashable {
        case left
        case right
    }

    let id: String
    let texto: String
    let tipo: VenousAnnotationType
    let anchor: VenousPoint
    let textPos: VenousPoint
    let side: Side
}

struct VenousAnnotationLayout: Sendable, Hashable {
    let width: Int
    let height: Int
    let labels: [VenousAnnotationLabel]
}

enum VenousAnnotations {
    private enum View: String, CaseIterable {
        case lateral
        case anterior
        case medial
        case posterior
    }

    private struct Pending {
        let id: String
        let texto: String
        let tipo: VenousAnnotationType
        let anchor: VenousPoint
        let textPos: VenousPoint
        let side: VenousAnnotationLabel.Side
        let cellColumn: Int
        let cellRow: Int
    }

    private static let viewBySegment: [String: View] = [
        "safena_magna": .medial,
        "safena_parva": .posterior,
        "safena_acessoria_anterior": .anterior,
    ]

    private static let topographyFraction: [VenousAnnotationTopography: Double] = [
        .coxa: 0.2,
        .joelho: 0.48,
        .pernaMedial: 0.66,
        .panturrilha: 0.8,
    ]

    static func build(
        map: MapaVenoso,
        coords: VenousCoords4,
        textWidth: Double = 180,
        lineHeight: Double = 46,
        margin: Double = 12,
        minGap: Double = 26
    ) -> VenousAnnotationLayout {
        let columnWidth = Double(coords.width) / 4
        let rowHeight = Double(coords.height) / 2
        var pending: [Pending] = []

        for (index, annotation) in (map.anotacoes ?? []).enumerated() {
            guard let key = cellKey(for: annotation),
                  let cell = coords.vistas[key] else {
                continue
            }
            let segment = annotation.segmento ?? "safena_parva"
            guard let points = cell[segment] ?? cell.values.first,
                  !points.isEmpty else {
                continue
            }

            let anchor: VenousPoint
            if let topography = annotation.topografia,
               let fraction = topographyFraction[topography] {
                anchor = point(atYFraction: fraction, in: points)
            } else {
                anchor = points[points.count / 2]
            }

            guard let rawView = key.split(separator: "__", maxSplits: 1).last,
                  let view = View(rawValue: String(rawView)),
                  let column = View.allCases.firstIndex(of: view) else {
                continue
            }
            let row = annotation.lado == .direito ? 0 : 1
            let cellX0 = Double(column) * columnWidth
            let cellX1 = cellX0 + columnWidth
            let roomRight = cellX1 - anchor.x
            let roomLeft = anchor.x - cellX0
            let side: VenousAnnotationLabel.Side = roomRight >= roomLeft ? .right : .left
            let nearX = side == .right
                ? max(anchor.x + minGap, cellX1 - margin - textWidth)
                : min(anchor.x - minGap, cellX0 + margin + textWidth)

            pending.append(
                Pending(
                    id: "ann-\(index)",
                    texto: annotation.texto,
                    tipo: annotation.tipo,
                    anchor: anchor,
                    textPos: VenousPoint(x: nearX, y: anchor.y),
                    side: side,
                    cellColumn: column,
                    cellRow: row
                )
            )
        }

        var groups: [String: [Pending]] = [:]
        for item in pending {
            let key = "\(item.cellColumn)_\(item.cellRow)_\(item.side.rawValue)"
            groups[key, default: []].append(item)
        }

        var labels: [VenousAnnotationLabel] = []
        for group in groups.values {
            let sorted = group.sorted { $0.textPos.y < $1.textPos.y }
            guard let first = sorted.first else { continue }
            let rowTop = Double(first.cellRow) * rowHeight + margin
            let rowBottom = Double(first.cellRow + 1) * rowHeight - margin
            var cursor = rowTop
            for item in sorted {
                var y = max(cursor, item.textPos.y - lineHeight / 2)
                if y + lineHeight > rowBottom {
                    y = rowBottom - lineHeight
                }
                labels.append(
                    VenousAnnotationLabel(
                        id: item.id,
                        texto: item.texto,
                        tipo: item.tipo,
                        anchor: item.anchor,
                        textPos: VenousPoint(x: item.textPos.x, y: y + lineHeight / 2),
                        side: item.side
                    )
                )
                cursor = y + lineHeight
            }
        }

        return VenousAnnotationLayout(width: coords.width, height: coords.height, labels: labels)
    }

    private static func cellKey(for annotation: VenousAnnotation) -> String? {
        let view: View?
        if let segment = annotation.segmento {
            view = viewBySegment[segment]
        } else if annotation.topografia != nil {
            view = .posterior
        } else {
            view = nil
        }
        guard let view else { return nil }
        return "\(annotation.lado.rawValue)__\(view.rawValue)"
    }

    private static func point(atYFraction fraction: Double, in points: [VenousPoint]) -> VenousPoint {
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let targetY = minY + (maxY - minY) * fraction
        return points.min { abs($0.y - targetY) < abs($1.y - targetY) } ?? points[0]
    }
}
