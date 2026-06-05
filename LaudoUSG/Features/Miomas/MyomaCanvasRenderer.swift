import SwiftUI

/// Desenho dos 2 esquemas de mioma num `GraphicsContext` (Canvas). Compartilhado
/// entre o esquema interativo (`MyomaSchematicView`) e o layout de exportação
/// (`MyomaExportLayout`). Coords idênticas ao mockup HTML aprovado.
enum MyomaCanvasRenderer {
    static let cream = Color(hex: "FBF7EE")
    static let creamLine = Color(hex: "B9A98C")
    static let cavityFill = Color(hex: "E7F4EE")
    static let cavityLine = Color(hex: "0F9B6E")

    static let sagAspect: CGFloat = 500.0 / 320.0
    static let axAspect: CGFloat = 560.0 / 420.0

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    // Transform design→tela (compartilhado entre o draw e o drag/hit-test).
    static func sagScale(_ size: CGSize) -> CGFloat { min(size.width / 520, size.height / 420) * 0.9 }
    static func axScale(_ size: CGSize) -> CGFloat { min(size.width / 560, size.height / 400) * 0.92 }

    static func sagTransform(_ size: CGSize) -> CGAffineTransform {
        CGAffineTransform.identity
            .translatedBy(x: size.width / 2, y: size.height / 2)
            .scaledBy(x: sagScale(size), y: sagScale(size))
            .rotated(by: -.pi / 2)
            .translatedBy(x: -210, y: -266)
    }
    static func axTransform(_ size: CGSize) -> CGAffineTransform {
        CGAffineTransform.identity
            .translatedBy(x: size.width / 2, y: size.height / 2)
            .scaledBy(x: axScale(size), y: axScale(size))
            .translatedBy(x: -280, y: -200)
    }

    // MARK: - Longitudinal (pera vertical aprovada, rotacionada -90°)

    static func drawSagittal(_ ctx: GraphicsContext, _ size: CGSize, _ findings: [MyomaFinding]) {
        let s = sagScale(size)
        let t = sagTransform(size)

        var pear = Path()
        pear.move(to: p(210, 46))
        pear.addCurve(to: p(92, 166), control1: p(150, 46), control2: p(96, 86))
        pear.addCurve(to: p(120, 286), control1: p(90, 214), control2: p(104, 250))
        pear.addCurve(to: p(176, 408), control1: p(150, 352), control2: p(168, 372))
        pear.addLine(to: p(176, 470))
        pear.addCurve(to: p(244, 470), control1: p(176, 486), control2: p(244, 486))
        pear.addLine(to: p(244, 408))
        pear.addCurve(to: p(300, 286), control1: p(252, 372), control2: p(270, 352))
        pear.addCurve(to: p(328, 166), control1: p(316, 250), control2: p(330, 214))
        pear.addCurve(to: p(210, 46), control1: p(324, 86), control2: p(270, 46))
        pear.closeSubpath()
        let pearS = pear.applying(t)
        ctx.fill(pearS, with: .color(cream))
        ctx.stroke(pearS, with: .color(creamLine), lineWidth: 2.4 * s)

        var bat = Path()
        bat.move(to: p(178, 116))
        bat.addCurve(to: p(242, 116), control1: p(196, 104), control2: p(224, 104))
        bat.addCurve(to: p(226, 196), control1: p(248, 146), control2: p(240, 172))
        bat.addCurve(to: p(218, 226), control1: p(221, 205), control2: p(219, 214))
        bat.addCurve(to: p(215, 432), control1: p(217, 290), control2: p(216, 370))
        bat.addCurve(to: p(210, 450), control1: p(215, 442), control2: p(213, 448))
        bat.addCurve(to: p(205, 432), control1: p(207, 448), control2: p(205, 442))
        bat.addCurve(to: p(202, 226), control1: p(204, 370), control2: p(203, 290))
        bat.addCurve(to: p(194, 196), control1: p(201, 214), control2: p(199, 205))
        bat.addCurve(to: p(178, 116), control1: p(180, 172), control2: p(172, 146))
        bat.closeSubpath()
        let batS = bat.applying(t)
        ctx.fill(batS, with: .color(cavityFill))
        ctx.stroke(batS, with: .color(cavityLine), lineWidth: 1.6 * s)

        let pts = spread(findings.map { $0.sagPoint ?? $0.canonicalSag })
        for (f, dp) in zip(findings, pts) { drawMarker(ctx, f, dp.applying(t), s) }
    }

    // MARK: - Transversal (disco + linha endometrial)

    static func drawAxial(_ ctx: GraphicsContext, _ size: CGSize, _ findings: [MyomaFinding]) {
        let s = axScale(size)
        let t = axTransform(size)

        let disc = Path(ellipseIn: CGRect(x: 80, y: 50, width: 400, height: 300)).applying(t)
        ctx.fill(disc, with: .color(cream))
        ctx.stroke(disc, with: .color(creamLine), lineWidth: 2.4 * s)

        var lens = Path()
        lens.move(to: p(192, 196))
        lens.addCurve(to: p(368, 196), control1: p(236, 188), control2: p(324, 188))
        lens.addCurve(to: p(192, 196), control1: p(324, 212), control2: p(236, 212))
        lens.closeSubpath()
        let lensS = lens.applying(t)
        ctx.fill(lensS, with: .color(cavityFill))
        ctx.stroke(lensS, with: .color(cavityLine), lineWidth: 1.6 * s)

        let pts = spread(findings.map { $0.axPoint ?? $0.canonicalAx })
        for (f, dp) in zip(findings, pts) { drawMarker(ctx, f, dp.applying(t), s) }
    }

    /// Espalha marcadores que cairiam no mesmo ponto (espiral curta).
    private static func spread(_ points: [CGPoint]) -> [CGPoint] {
        var placed: [CGPoint] = []
        var out: [CGPoint] = []
        for p in points {
            var q = p
            var k = 0
            while placed.contains(where: { hypot($0.x - q.x, $0.y - q.y) < 26 }) {
                k += 1
                let ang = Double(k) * 1.9
                q = CGPoint(x: p.x + CGFloat(cos(ang)) * 30, y: p.y + CGFloat(sin(ang)) * 22)
            }
            placed.append(q); out.append(q)
        }
        return out
    }

    private static func drawMarker(_ ctx: GraphicsContext, _ f: MyomaFinding, _ center: CGPoint, _ s: CGFloat) {
        let r = (11 + (f.sizeMaxMm ?? 18) * 0.28) * s
        let rect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
        ctx.fill(Path(ellipseIn: rect), with: .color(f.family.color))
        ctx.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1.6 * s)
        ctx.draw(
            Text("\(f.figo)").font(.system(size: r * 0.92, weight: .bold)).foregroundColor(.white),
            at: center
        )
    }
}

/// Canvas de uma visão (reusável).
struct SagittalCanvasView: View {
    var findings: [MyomaFinding]
    var body: some View {
        Canvas { ctx, size in MyomaCanvasRenderer.drawSagittal(ctx, size, findings) }
            .aspectRatio(MyomaCanvasRenderer.sagAspect, contentMode: .fit)
    }
}

struct AxialCanvasView: View {
    var findings: [MyomaFinding]
    var body: some View {
        Canvas { ctx, size in MyomaCanvasRenderer.drawAxial(ctx, size, findings) }
            .aspectRatio(MyomaCanvasRenderer.axAspect, contentMode: .fit)
    }
}
