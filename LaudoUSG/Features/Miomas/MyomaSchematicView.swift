import SwiftUI

enum UterusView: String, CaseIterable {
    case longitudinal = "Longitudinal"
    case transversal = "Transversal"
}

/// Esquema visual de miomas (FIGO 0–8) em 2 visões — porte SwiftUI do mockup
/// aprovado. Step 1: renderiza com achados hardcoded (Step 2 = editor manual).
struct MyomaSchematicView: View {
    var findings: [MyomaFinding] = MyomaFinding.exemplos
    @State private var view: UterusView = .longitudinal

    var body: some View {
        VStack(spacing: 14) {
            Picker("Visão", selection: $view) {
                ForEach(UterusView.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Canvas { ctx, size in
                if view == .longitudinal {
                    drawSagittal(ctx, size)
                } else {
                    drawAxial(ctx, size)
                }
            }
            .aspectRatio(view == .longitudinal ? 500.0 / 320.0 : 560.0 / 420.0, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "E3DDD1"), lineWidth: 1)
            )
        }
    }

    // MARK: - Cores

    private let cream = Color(hex: "FBF7EE")
    private let creamLine = Color(hex: "B9A98C")
    private let cavityFill = Color(hex: "E7F4EE")
    private let cavityLine = Color(hex: "0F9B6E")

    // MARK: - Longitudinal (pera vertical aprovada, rotacionada -90°)

    private func drawSagittal(_ ctx: GraphicsContext, _ size: CGSize) {
        // ref vertical 420×520; rotacionado vira 520×420
        let s = min(size.width / 520, size.height / 420) * 0.9
        let t = CGAffineTransform.identity
            .translatedBy(x: size.width / 2, y: size.height / 2)
            .scaledBy(x: s, y: s)
            .rotated(by: -.pi / 2)
            .translatedBy(x: -210, y: -266)

        // miométrio — pera original
        var pear = Path()
        pear.move(to: pt(210, 46))
        pear.addCurve(to: pt(92, 166), control1: pt(150, 46), control2: pt(96, 86))
        pear.addCurve(to: pt(120, 286), control1: pt(90, 214), control2: pt(104, 250))
        pear.addCurve(to: pt(176, 408), control1: pt(150, 352), control2: pt(168, 372))
        pear.addLine(to: pt(176, 470))
        pear.addCurve(to: pt(244, 470), control1: pt(176, 486), control2: pt(244, 486))
        pear.addLine(to: pt(244, 408))
        pear.addCurve(to: pt(300, 286), control1: pt(252, 372), control2: pt(270, 352))
        pear.addCurve(to: pt(328, 166), control1: pt(316, 250), control2: pt(330, 214))
        pear.addCurve(to: pt(210, 46), control1: pt(324, 86), control2: pt(270, 46))
        pear.closeSubpath()
        let pearS = pear.applying(t)
        ctx.fill(pearS, with: .color(cream))
        ctx.stroke(pearS, with: .color(creamLine), lineWidth: 2.4 * s)

        // endométrio — taco de baseball único
        var bat = Path()
        bat.move(to: pt(178, 116))
        bat.addCurve(to: pt(242, 116), control1: pt(196, 104), control2: pt(224, 104))
        bat.addCurve(to: pt(226, 196), control1: pt(248, 146), control2: pt(240, 172))
        bat.addCurve(to: pt(218, 226), control1: pt(221, 205), control2: pt(219, 214))
        bat.addCurve(to: pt(215, 432), control1: pt(217, 290), control2: pt(216, 370))
        bat.addCurve(to: pt(210, 450), control1: pt(215, 442), control2: pt(213, 448))
        bat.addCurve(to: pt(205, 432), control1: pt(207, 448), control2: pt(205, 442))
        bat.addCurve(to: pt(202, 226), control1: pt(204, 370), control2: pt(203, 290))
        bat.addCurve(to: pt(194, 196), control1: pt(201, 214), control2: pt(199, 205))
        bat.addCurve(to: pt(178, 116), control1: pt(180, 172), control2: pt(172, 146))
        bat.closeSubpath()
        let batS = bat.applying(t)
        ctx.fill(batS, with: .color(cavityFill))
        ctx.stroke(batS, with: .color(cavityLine), lineWidth: 1.6 * s)

        // marcadores
        for f in findings {
            if let p = f.sagPoint {
                drawMarker(ctx, f, p.applying(t), s)
            }
        }
    }

    // MARK: - Transversal (disco + linha endometrial)

    private func drawAxial(_ ctx: GraphicsContext, _ size: CGSize) {
        let s = min(size.width / 560, size.height / 400) * 0.92
        let t = CGAffineTransform.identity
            .translatedBy(x: size.width / 2, y: size.height / 2)
            .scaledBy(x: s, y: s)
            .translatedBy(x: -280, y: -200)

        let disc = Path(ellipseIn: CGRect(x: 80, y: 50, width: 400, height: 300)).applying(t)
        ctx.fill(disc, with: .color(cream))
        ctx.stroke(disc, with: .color(creamLine), lineWidth: 2.4 * s)

        var lens = Path()
        lens.move(to: pt(192, 196))
        lens.addCurve(to: pt(368, 196), control1: pt(236, 188), control2: pt(324, 188))
        lens.addCurve(to: pt(192, 196), control1: pt(324, 212), control2: pt(236, 212))
        lens.closeSubpath()
        let lensS = lens.applying(t)
        ctx.fill(lensS, with: .color(cavityFill))
        ctx.stroke(lensS, with: .color(cavityLine), lineWidth: 1.6 * s)

        for f in findings {
            if let p = f.axPoint {
                drawMarker(ctx, f, p.applying(t), s)
            }
        }
    }

    // MARK: - Helpers

    private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private func drawMarker(_ ctx: GraphicsContext, _ f: MyomaFinding, _ center: CGPoint, _ s: CGFloat) {
        // raio proporcional ao maior eixo (decisão: tamanho do marcador = maior eixo)
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

/// Tela com o esquema + legenda FIGO (Step 1 — debug / validação no device).
struct MyomaSchematicScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MyomaSchematicView()

                Text("Classificação FIGO (leiomioma)")
                    .font(TextStyle.bodyLargeMedium)
                    .padding(.top, 4)

                ForEach([FigoFamily.submucoso, .intramural, .subseroso, .outros], id: \.titulo) { fam in
                    Text(fam.titulo.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(fam.color)
                        .padding(.top, 6)
                    ForEach(FigoCategory.all.filter { $0.family == fam }, id: \.id) { c in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(c.figo)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(c.family.color))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.titulo).font(.system(size: 14, weight: .semibold))
                                Text(c.descricao).font(.system(size: 12.5)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Esquema de miomas (FIGO)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { MyomaSchematicScreen() }
}
