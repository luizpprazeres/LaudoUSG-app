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

    static func renderImage(map: MapaVenoso) throws -> UIImage {
        guard let base = UIImage(named: "VenosoLineartVeias")?.cgImage else {
            throw RenderError.missingBaseImage
        }
        let coords = try loadCoords()
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
        recolor(&pixels, width: width, height: height, map: map, coords: coords)

        guard let out = context.makeImage() else {
            throw RenderError.outputFailed
        }
        return UIImage(cgImage: out, scale: 1, orientation: .up)
    }

    static func renderPNG(map: MapaVenoso) throws -> Data {
        guard let png = try renderImage(map: map).pngData() else {
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

    private static func tubeRadius(for segment: String) -> Double {
        segment == "jsf" || segment == "jsp" ? 12 : 17
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
