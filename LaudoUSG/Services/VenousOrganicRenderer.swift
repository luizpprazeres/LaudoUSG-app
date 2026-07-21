import CoreGraphics
import Foundation
import UIKit

enum VenousOrganicRenderer {
    enum RenderError: Error {
        case missingBaseImage
        case missingCoords
        case invalidImage
        case contextFailed
        case outputFailed
    }

    static func renderImage(
        map: MapaVenoso,
        assetVersion: String = VenousSchemeAsset.anteriorVersion
    ) throws -> UIImage {
        let isFourView = assetVersion == VenousSchemeAsset.fourViewVersion
        let assetName = isFourView ? "Venous4View" : "VenosoLineartVeias"
        guard let base = UIImage(named: assetName)?.cgImage else {
            throw RenderError.missingBaseImage
        }
        let width = base.width
        let height = base.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw RenderError.contextFailed
        }

        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))
        if isFourView {
            let coords = try loadCoords4()
            recolor4(&pixels, width: width, height: height, map: map, coords: coords)
            drawAnnotations4(in: context, map: map, coords: coords)
        } else {
            let coords = try loadCoords()
            recolor(&pixels, width: width, height: height, map: map, coords: coords)
            drawCallouts(in: context, map: map, coords: coords)
        }

        guard let out = context.makeImage() else {
            throw RenderError.outputFailed
        }
        return UIImage(cgImage: out, scale: 1, orientation: .up)
    }

    static func renderPNG(
        map: MapaVenoso,
        assetVersion: String = VenousSchemeAsset.anteriorVersion
    ) throws -> Data {
        guard let png = try renderImage(map: map, assetVersion: assetVersion).pngData() else {
            throw RenderError.outputFailed
        }
        return png
    }

    private static func loadCoords() throws -> VenousCoords {
        guard let url = Bundle.main.url(
            forResource: "venoso-lineart-veias-coords",
            withExtension: "json",
            subdirectory: "Venous"
        ) ?? Bundle.main.url(forResource: "venoso-lineart-veias-coords", withExtension: "json") else {
            throw RenderError.missingCoords
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VenousCoords.self, from: data)
    }

    private static func loadCoords4() throws -> VenousCoords4 {
        guard let url = Bundle.main.url(
            forResource: "coords-4view",
            withExtension: "json",
            subdirectory: "Venous"
        ) ?? Bundle.main.url(forResource: "coords-4view", withExtension: "json") else {
            throw RenderError.missingCoords
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VenousCoords4.self, from: data)
    }

    private static func recolor(
        _ pixels: inout [UInt8],
        width: Int,
        height: Int,
        map: MapaVenoso,
        coords: VenousCoords
    ) {
        for side in VenousSide.allCases {
            let segmentos = map.side(side).segmentos
            for (segment, state) in segmentos {
                guard state != .normal,
                      let rgb = rgb(for: state),
                      let points = coords.points(for: side, segment: segment),
                      points.count >= 2 else {
                    continue
                }
                recolorSegment(
                    &pixels,
                    width: width,
                    height: height,
                    points: points,
                    radius: tubeRadius(for: segment),
                    rgb: rgb
                )
            }
        }
    }

    private static func recolor4(
        _ pixels: inout [UInt8],
        width: Int,
        height: Int,
        map: MapaVenoso,
        coords: VenousCoords4
    ) {
        let lateralSides = lateralVaricosidadeSides(map: map)
        for (cellKey, segments) in coords.vistas {
            guard let rawSide = cellKey.split(separator: "__", maxSplits: 1).first,
                  let side = VenousSide(rawValue: String(rawSide)) else {
                continue
            }
            let states = map.side(side).segmentos
            for (segment, points) in segments where points.count >= 2 {
                let color: (UInt8, UInt8, UInt8)?
                if segment == "tributaria_lateral" {
                    color = lateralSides.contains(side) ? rgb(for: .varicosidade) : nil
                } else if let state = states[segment] {
                    color = rgb(for: state)
                } else {
                    color = nil
                }
                guard let color else { continue }
                recolorSegment(
                    &pixels,
                    width: width,
                    height: height,
                    points: points,
                    radius: tubeRadius(for: segment, base: 13),
                    rgb: color
                )
            }
        }
    }

    private static func lateralVaricosidadeSides(map: MapaVenoso) -> Set<VenousSide> {
        Set(map.lesoes.compactMap { lesion in
            guard lesion.estado == .varicosidade else { return nil }
            let text = "\(lesion.label) \(lesion.sub ?? "")".lowercased()
            return text.contains("lateral") ? lesion.lado : nil
        })
    }

    private static func drawAnnotations4(in context: CGContext, map: MapaVenoso, coords: VenousCoords4) {
        let layout = VenousAnnotations.build(map: map, coords: coords)
        guard !layout.labels.isEmpty else { return }

        let color = UIColor(red: 122 / 255, green: 31 / 255, blue: 43 / 255, alpha: 1)
        let font = UIFont(name: "Caveat-Regular", size: 64)
            ?? UIFont(name: "Caveat", size: 64)
            ?? UIFont.systemFont(ofSize: 64, weight: .bold)

        context.saveGState()
        defer { context.restoreGState() }
        // Flip para y-down (origem no topo, como uma UIView): faz o texto UIKit
        // (NSString.draw) sair EM PÉ neste CGContext bitmap (que é y-up por padrão)
        // e permite usar as coords do layout diretamente (mesmo lugar dos traços).
        context.translateBy(x: 0, y: CGFloat(layout.height))
        context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(3)
        context.setLineCap(.round)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]

        for label in layout.labels {
            let anchor = CGPoint(x: label.anchor.x, y: label.anchor.y)
            let textPosition = CGPoint(x: label.textPos.x, y: label.textPos.y)
            context.beginPath()
            context.move(to: anchor)
            context.addLine(to: textPosition)
            context.strokePath()
            context.fillEllipse(in: CGRect(x: anchor.x - 6, y: anchor.y - 6, width: 12, height: 12))

            let textWidth = (label.texto as NSString).size(withAttributes: attributes).width
            let drawX = label.side == .left ? textPosition.x - textWidth : textPosition.x
            // NSString.draw(at:) usa o canto superior-esquerdo; centra na linha-guia.
            let topY = textPosition.y - font.lineHeight / 2
            (label.texto as NSString).draw(
                at: CGPoint(x: drawX, y: topY),
                withAttributes: attributes
            )
        }
    }

    private static func recolorSegment(
        _ pixels: inout [UInt8],
        width: Int,
        height: Int,
        points: [VenousPoint],
        radius: Double,
        rgb: (UInt8, UInt8, UInt8)
    ) {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return }
        let x0 = max(0, Int(floor(minX - radius - 2)))
        let x1 = min(width - 1, Int(ceil(maxX + radius + 2)))
        let y0 = max(0, Int(floor(minY - radius - 2)))
        let y1 = min(height - 1, Int(ceil(maxY + radius + 2)))

        for y in y0...y1 {
            for x in x0...x1 {
                let i = (y * width + x) * 4
                let r = pixels[i]
                let g = pixels[i + 1]
                let b = pixels[i + 2]
                guard isVeinPixel(r: r, g: g, b: b) else { continue }
                guard distToPolyline(px: Double(x), py: Double(y), points: points) <= radius else { continue }
                pixels[i] = rgb.0
                pixels[i + 1] = rgb.1
                pixels[i + 2] = rgb.2
            }
        }
    }

    private static func isVeinPixel(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        Int(b) - Int(r) > 14 && b > 108 && r < 205
    }

    private static func tubeRadius(for segment: String, base: Double = 17) -> Double {
        segment == "jsf" || segment == "jsp" ? max(10, base - 4) : base
    }

    private static func rgb(for state: EstadoSegmento) -> (UInt8, UInt8, UInt8)? {
        switch state {
        case .normal:
            return nil
        case .refluxo, .varicosidade:
            return (209, 132, 26)
        case .tromboseOclusiva, .recanalizada:
            return (176, 58, 74)
        case .tromboseParcial:
            return (196, 96, 110)
        }
    }

    private struct RGB: Hashable {
        let r: UInt8
        let g: UInt8
        let b: UInt8

        var cgColor: CGColor {
            UIColor(
                red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1
            ).cgColor
        }

        var uiColor: UIColor {
            UIColor(
                red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1
            )
        }
    }

    private struct CalloutRect {
        let x: CGFloat
        let y: CGFloat
        let w: CGFloat
        let h: CGFloat

        var cgRect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
        var minX: CGFloat { x }
        var maxX: CGFloat { x + w }
        var midY: CGFloat { y + h / 2 }
    }

    private enum CalloutSide {
        case left
        case right
    }

    private struct CalloutCard {
        let label: String
        let sub: String
        let estado: EstadoSegmento
        let color: RGB
        let anchor: CGPoint
        let rect: CalloutRect
        let side: CalloutSide
    }

    private struct PendingCallout {
        let label: String
        let sub: String
        let estado: EstadoSegmento
        let color: RGB
        let anchor: CGPoint
        let side: CalloutSide
        let anchorY: CGFloat
    }

    private struct LegendItem {
        let estado: EstadoSegmento
        let color: RGB
        let label: String
    }

    private struct CalloutLayout {
        let width: CGFloat
        let height: CGFloat
        let cards: [CalloutCard]
        let legend: [LegendItem]
    }

    private static func drawCallouts(in context: CGContext, map: MapaVenoso, coords: VenousCoords) {
        let layout = buildCallouts(map: map, coords: coords)
        guard !layout.cards.isEmpty || !layout.legend.isEmpty else { return }

        context.saveGState()
        defer { context.restoreGState() }

        for card in layout.cards {
            drawGuide(for: card, in: context)
        }
        for card in layout.cards {
            drawPill(for: card, in: context)
        }
        drawLegend(layout.legend, width: layout.width, height: layout.height, in: context)
    }

    private static func buildCallouts(map: MapaVenoso, coords: VenousCoords) -> CalloutLayout {
        let width = CGFloat(coords.width)
        let height = CGFloat(coords.height)
        let cardW: CGFloat = 210
        let cardH: CGFloat = 96
        let gap: CGFloat = 14
        let margin: CGFloat = 12
        let legendReserve: CGFloat = 96
        let yMin = margin
        let yMax = height - legendReserve - margin

        var pending: [PendingCallout] = []
        for lesion in map.lesoes {
            guard let points = coords.points(for: lesion.lado, segment: lesion.segmento),
                  !points.isEmpty else {
                continue
            }
            let anchor = midpoint(points)
            let side: CalloutSide = anchor.x < width / 2 ? .left : .right
            pending.append(
                PendingCallout(
                    label: lesion.label,
                    sub: lesion.sub ?? "",
                    estado: lesion.estado,
                    color: colorForCallout(lesion.estado),
                    anchor: anchor,
                    side: side,
                    anchorY: anchor.y
                )
            )
        }

        var cards: [CalloutCard] = []
        for side in [CalloutSide.left, .right] {
            let x = side == .left ? margin : width - margin - cardW
            let group = pending
                .filter { $0.side == side }
                .sorted { $0.anchorY < $1.anchorY }
            var cursor = yMin
            for item in group {
                var y = max(cursor, item.anchorY - cardH / 2)
                if y + cardH > yMax { y = yMax - cardH }
                if y < cursor { y = cursor }
                cards.append(
                    CalloutCard(
                        label: item.label,
                        sub: item.sub,
                        estado: item.estado,
                        color: item.color,
                        anchor: item.anchor,
                        rect: CalloutRect(x: x, y: y, w: cardW, h: cardH),
                        side: item.side
                    )
                )
                cursor = y + cardH + gap
            }
        }

        let present = Set(map.lesoes.map(\.estado))
        let order: [EstadoSegmento] = [
            .tromboseOclusiva,
            .tromboseParcial,
            .recanalizada,
            .refluxo,
            .varicosidade,
        ]
        let legend = order.compactMap { state -> LegendItem? in
            guard present.contains(state) else { return nil }
            return LegendItem(estado: state, color: colorForCallout(state), label: legendLabel(for: state))
        }

        return CalloutLayout(width: width, height: height, cards: cards, legend: legend)
    }

    private static func midpoint(_ points: [VenousPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let point = points[points.count / 2]
        return CGPoint(x: point.x, y: point.y)
    }

    private static func colorForCallout(_ state: EstadoSegmento) -> RGB {
        switch state {
        case .normal:
            return RGB(r: 90, g: 90, b: 90)
        case .refluxo, .varicosidade:
            return RGB(r: 209, g: 132, b: 26)
        case .tromboseOclusiva, .recanalizada:
            return RGB(r: 176, g: 58, b: 74)
        case .tromboseParcial:
            return RGB(r: 196, g: 96, b: 110)
        }
    }

    private static func legendLabel(for state: EstadoSegmento) -> String {
        switch state {
        case .normal:
            return "Normal"
        case .refluxo:
            return "Refluxo"
        case .varicosidade:
            return "Varicosidade"
        case .tromboseOclusiva:
            return "TVP oclusiva"
        case .tromboseParcial:
            return "Trombose parcial"
        case .recanalizada:
            return "Recanalização"
        }
    }

    private static func drawGuide(for card: CalloutCard, in context: CGContext) {
        let startX = card.side == .left ? card.rect.maxX : card.rect.minX
        let start = CGPoint(x: startX, y: card.rect.midY)

        context.saveGState()
        context.setStrokeColor(card.color.cgColor)
        context.setLineWidth(3)
        context.setLineCap(.round)
        context.beginPath()
        context.move(to: start)
        context.addLine(to: card.anchor)
        context.strokePath()

        context.setFillColor(card.color.cgColor)
        context.fillEllipse(in: CGRect(x: card.anchor.x - 5, y: card.anchor.y - 5, width: 10, height: 10))
        context.restoreGState()
    }

    private static func drawPill(for card: CalloutCard, in context: CGContext) {
        let rect = card.rect.cgRect
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 16)

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 3),
            blur: 9,
            color: UIColor.black.withAlphaComponent(0.12).cgColor
        )
        context.setFillColor(UIColor.white.withAlphaComponent(0.96).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.setStrokeColor(UIColor(white: 0.75, alpha: 0.55).cgColor)
        context.setLineWidth(1)
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let padding: CGFloat = 14
        let labelRect = CGRect(x: rect.minX + padding, y: rect.minY + 13, width: rect.width - padding * 2, height: 40)
        let subRect = CGRect(x: rect.minX + padding, y: rect.minY + 52, width: rect.width - padding * 2, height: 32)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left

        let label = NSAttributedString(
            string: card.label,
            attributes: [
                .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                .foregroundColor: card.color.uiColor,
                .paragraphStyle: paragraph,
            ]
        )
        label.draw(with: labelRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

        guard !card.sub.isEmpty else { return }
        let sub = NSAttributedString(
            string: card.sub,
            attributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .regular),
                .foregroundColor: UIColor(white: 0.32, alpha: 1),
                .paragraphStyle: paragraph,
            ]
        )
        sub.draw(with: subRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    private static func drawLegend(
        _ legend: [LegendItem],
        width: CGFloat,
        height: CGFloat,
        in context: CGContext
    ) {
        guard !legend.isEmpty else { return }
        let font = UIFont.systemFont(ofSize: 24, weight: .medium)
        let textColor = UIColor(white: 0.25, alpha: 1)
        let swatch: CGFloat = 18
        let itemGap: CGFloat = 28
        let y = height - 54
        let itemWidths = legend.map { item in
            swatch + 8 + (item.label as NSString).size(withAttributes: [.font: font]).width
        }
        let totalW = itemWidths.reduce(0, +) + itemGap * CGFloat(max(0, legend.count - 1))
        var x = max(12, (width - totalW) / 2)

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        for (index, item) in legend.enumerated() {
            let swatchRect = CGRect(x: x, y: y + 3, width: swatch, height: swatch)
            context.setFillColor(item.color.cgColor)
            context.fill(swatchRect)

            let labelX = x + swatch + 8
            let labelRect = CGRect(x: labelX, y: y - 2, width: itemWidths[index] - swatch - 8, height: 32)
            let label = NSAttributedString(
                string: item.label,
                attributes: [
                    .font: font,
                    .foregroundColor: textColor,
                ]
            )
            label.draw(with: labelRect, options: [.usesLineFragmentOrigin], context: nil)
            x += itemWidths[index] + itemGap
        }
    }

    private static func distToPolyline(px: Double, py: Double, points: [VenousPoint]) -> Double {
        var best = Double.infinity
        for i in 1..<points.count {
            let d = distToSegment(px: px, py: py, a: points[i - 1], b: points[i])
            if d < best { best = d }
        }
        return best
    }

    private static func distToSegment(px: Double, py: Double, a: VenousPoint, b: VenousPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let l2 = dx * dx + dy * dy
        let rawT = l2 == 0 ? 0 : ((px - a.x) * dx + (py - a.y) * dy) / l2
        let t = min(1, max(0, rawT))
        let cx = a.x + t * dx
        let cy = a.y + t * dy
        return hypot(px - cx, py - cy)
    }
}
