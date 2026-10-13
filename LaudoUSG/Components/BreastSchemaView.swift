import SwiftUI

/// Esquema mamário bilateral sobre o cartograma v5 da web (`apps/web/public/schemas/breast/frontal-v5.svg`),
/// com a MESMA geometria (`breastGeometry.ts`) e os mesmos glifos P&B (`BreastSchema.tsx`).
/// Coordenadas lógicas: 1608 × 1240 (a anatomia ocupa 1608 × 1138; a legenda fica embaixo).
/// Achado: hora no relógio + distância do mamilo (0–6 cm). Arrastar reposiciona e devolve hora/distância.
struct BreastSchemaView: View {
    let findings: [BreastFinding]
    /// Chamado ao soltar um marcador arrastado. `nil` = sem arraste (exportação).
    var onMove: ((String, Int, Double) -> Void)? = nil

    @State private var drag: (id: String, point: CGPoint)?

    static let logicalWidth: CGFloat = 1608
    static let logicalHeight: CGFloat = 1240
    static let anatomyHeight: CGFloat = 1138
    static let cy: CGFloat = 686
    static let rightCx: CGFloat = 435
    static let leftCx: CGFloat = 1208
    static let rx: CGFloat = 300
    static let ry: CGFloat = 325
    static let maxCm: Double = 6
    static let limit: Double = 0.94
    static let ink = Color(hex: "111827")

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.logicalWidth, geo.size.height / Self.logicalHeight)
            let w = Self.logicalWidth * scale, h = Self.logicalHeight * scale
            let positions = Self.positions(for: findings)
            ZStack(alignment: .topLeading) {
                Color.white
                Image("BreastFrontalV5")
                    .resizable()
                    .frame(width: w, height: Self.anatomyHeight * scale)
                Canvas { ctx, _ in
                    ctx.scaleBy(x: scale, y: scale)
                    let maximum = max(1, findings.compactMap(\.sizeMax).max() ?? 1)
                    for (index, f) in findings.enumerated() {
                        let p = (drag?.id == f.id ? drag?.point : nil) ?? positions[f.id] ?? Self.point(for: f)
                        let r = Self.radius(for: f, max: maximum)
                        Self.drawGlyph(f.type, at: p, r: r, in: &ctx)
                        ctx.draw(Text("\(index + 1)").font(.system(size: 22, weight: .bold)).foregroundColor(Self.ink),
                                 at: CGPoint(x: p.x, y: p.y - r - 18))
                    }
                    Self.drawLegend(in: &ctx)
                    if let d = drag, let f = findings.first(where: { $0.id == d.id }) {
                        let pos = Self.position(side: f.side, x: d.point.x, y: d.point.y, centerHour: f.hora ?? 12)
                        let label = "\(pos.hora) h · \(String(format: "%.1f", pos.dist).replacingOccurrences(of: ".", with: ",")) cm do mamilo"
                        let fx = d.point.x + 42 + 320 <= Self.logicalWidth ? d.point.x + 42 : d.point.x - 362
                        let fy = max(18, d.point.y - 98)
                        ctx.fill(Path(roundedRect: CGRect(x: fx, y: fy, width: 320, height: 58), cornerRadius: 12), with: .color(Self.ink))
                        ctx.draw(Text(label).font(.system(size: 25, weight: .bold)).foregroundColor(.white), at: CGPoint(x: fx + 16, y: fy + 29), anchor: .leading)
                    }
                }
                .frame(width: w, height: h)
                .allowsHitTesting(false)

                if onMove != nil {
                    ForEach(findings) { f in
                        let p = (drag?.id == f.id ? drag?.point : nil) ?? positions[f.id] ?? Self.point(for: f)
                        Circle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: 88 * scale + 24, height: 88 * scale + 24)
                            .position(x: p.x * scale, y: p.y * scale)
                            .gesture(
                                DragGesture(minimumDistance: 2)
                                    .onChanged { v in
                                        let raw = CGPoint(x: v.location.x / scale, y: v.location.y / scale)
                                        let pos = Self.position(side: f.side, x: raw.x, y: raw.y, centerHour: f.hora ?? 12)
                                        drag = (f.id, pos.point)
                                    }
                                    .onEnded { v in
                                        let raw = CGPoint(x: v.location.x / scale, y: v.location.y / scale)
                                        let pos = Self.position(side: f.side, x: raw.x, y: raw.y, centerHour: f.hora ?? 12)
                                        drag = nil
                                        onMove?(f.id, pos.hora, pos.dist)
                                    }
                            )
                            .accessibilityLabel("Achado \((findings.firstIndex(of: f) ?? 0) + 1), mama \(f.side.rawValue)")
                    }
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .offset(x: (geo.size.width - w) / 2, y: (geo.size.height - h) / 2)
        }
        .aspectRatio(Self.logicalWidth / Self.logicalHeight, contentMode: .fit)
    }

    // MARK: - Geometria (porta de breastGeometry.ts)

    static func center(_ side: BreastFinding.Side) -> CGFloat { side == .direita ? rightCx : leftCx }

    static func quadrantFallbackHora(_ finding: BreastFinding) -> Int? {
        guard let q = finding.quadrant else { return nil }
        switch (finding.side, q) {
        case (.direita, .qsl): return 10
        case (.direita, .qsm): return 2
        case (.direita, .qil): return 8
        case (.direita, .qim): return 4
        case (.esquerda, .qsl): return 2
        case (.esquerda, .qsm): return 10
        case (.esquerda, .qil): return 4
        case (.esquerda, .qim): return 8
        }
    }

    static func point(for f: BreastFinding) -> CGPoint {
        let hour = Double(f.hora ?? quadrantFallbackHora(f) ?? 12)
        let distance = f.distMamilo ?? 3.3
        let radius = min(max(distance, 0) / maxCm, 1) * limit
        let angle = hour / 12 * .pi * 2 - .pi / 2
        return CGPoint(x: center(f.side) + CGFloat(radius * cos(angle)) * rx, y: cy + CGFloat(radius * sin(angle)) * ry)
    }

    /// Ponto → (ponto limitado à mama, hora, distância). Igual a `breastPositionFromPoint`.
    static func position(side: BreastFinding.Side, x: CGFloat, y: CGFloat, centerHour: Int = 12) -> (point: CGPoint, hora: Int, dist: Double) {
        let cx = center(side)
        let dx = Double(x - cx), dy = Double(y - cy)
        let er = hypot(dx / Double(rx), dy / Double(ry))
        let s = er > limit ? limit / er : 1
        let bounded = CGPoint(x: cx + CGFloat(dx * s), y: cy + CGFloat(dy * s))
        let clock = (atan2(dy / Double(ry), dx / Double(rx)) + .pi / 2 + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        let rounded = Int((clock * 12 / (.pi * 2)).rounded()) % 12
        let hora = er < 0.001 ? centerHour : (rounded == 0 ? 12 : rounded)
        let dist = (min(er / limit, 1) * maxCm * 10).rounded() / 10
        return (bounded, hora, dist)
    }

    /// Achados na mesma hora/distância não se sobrepõem (espalha como a web).
    static func positions(for findings: [BreastFinding]) -> [String: CGPoint] {
        var buckets: [String: [BreastFinding]] = [:]
        var order: [String] = []
        for f in findings {
            let key = "\(f.side.rawValue):\(f.hora.map(String.init) ?? "-"):\(f.distMamilo.map { String($0) } ?? "-")"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(f)
        }
        var out: [String: CGPoint] = [:]
        for key in order {
            for (i, f) in (buckets[key] ?? []).enumerated() {
                let base = point(for: f)
                let off = i == 0 ? CGPoint.zero : CGPoint(x: CGFloat((i % 3) - 1) * 45, y: CGFloat((i + 2) / 3) * 40)
                out[f.id] = position(side: f.side, x: base.x + off.x, y: base.y + off.y).point
            }
        }
        return out
    }

    static func radius(for f: BreastFinding, max: Double) -> CGFloat {
        guard let size = f.sizeMax else { return 20 }
        return 12 + CGFloat(min(size / max, 1)) * 24
    }

    // MARK: - Glifos P&B (iguais à web) e legenda

    static func drawGlyph(_ type: BreastFinding.FindingType, at p: CGPoint, r: CGFloat, in ctx: inout GraphicsContext) {
        switch type {
        case .cyst:
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: rect), with: .color(ink), lineWidth: 2)
        case .calcification:
            for (dx, dy, rr) in [(-0.55, -0.25, 0.28), (0.5, -0.45, 0.22), (0.2, 0.45, 0.3), (-0.45, 0.5, 0.18)] {
                let c = CGPoint(x: p.x + r * dx, y: p.y + r * dy), rad = r * rr
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)), with: .color(ink))
            }
        case .solidLobulated:
            ctx.fill(polygon(48, around: p) { a, _ in r * (1 + 0.22 * sin(4 * a)) }, with: .color(ink))
        case .solidSpiculated:
            ctx.fill(polygon(32, around: p) { _, i in i % 2 == 0 ? r * 1.45 : r * 0.78 }, with: .color(ink))
        case .lymphNode:
            // periferia hipoecoica (preta) com hilo hiperecoico (branco) central
            let outer = CGRect(x: p.x - r * 1.35, y: p.y - r * 0.85, width: r * 2.7, height: r * 1.7)
            ctx.fill(Path(ellipseIn: outer), with: .color(ink))
            let inner = CGRect(x: p.x - r * 0.55, y: p.y - r * 0.35, width: r * 1.1, height: r * 0.7)
            ctx.fill(Path(ellipseIn: inner), with: .color(.white))
        case .solid:
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(ink))
        }
    }

    private static func polygon(_ n: Int, around p: CGPoint, radius: (CGFloat, Int) -> CGFloat) -> Path {
        var path = Path()
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * .pi * 2
            let rr = radius(a, i)
            let pt = CGPoint(x: p.x + rr * cos(a), y: p.y + rr * sin(a))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    static let legend: [(BreastFinding.FindingType, String)] = [
        (.cyst, "Cisto"), (.solid, "Nódulo"), (.solidLobulated, "Lobulado"), (.solidSpiculated, "Espiculado"), (.calcification, "Calcificação"),
    ]

    static func drawLegend(in ctx: inout GraphicsContext) {
        var line = Path()
        line.move(to: CGPoint(x: 96, y: 1148)); line.addLine(to: CGPoint(x: logicalWidth - 96, y: 1148))
        ctx.stroke(line, with: .color(Color(hex: "D1D5DB")), lineWidth: 1.5)
        ctx.draw(Text("LEGENDA").font(.system(size: 19, weight: .bold)).foregroundColor(Color(hex: "374151")), at: CGPoint(x: 98, y: 1181), anchor: .leading)
        for (i, item) in legend.enumerated() {
            let x = 270 + CGFloat(i) * 260
            drawGlyph(item.0, at: CGPoint(x: x, y: 1180), r: 14, in: &ctx)
            ctx.draw(Text(item.1).font(.system(size: 18, weight: .semibold)).foregroundColor(Color(hex: "374151")), at: CGPoint(x: x + 28, y: 1181), anchor: .leading)
        }
    }
}
