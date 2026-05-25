import SwiftUI

/// Cartografia venosa (Doppler MMII) — 1 perna por vez, 4 vistas paralelas.
/// Espelha `components/vascular/VenousCartographyDisplay.tsx` da web.
///
/// Coordenadas lógicas: 760 × 700 (mesmo viewBox da web).
/// Cores clínicas semânticas mantidas (refluxo=vermelho, trombose=azul escuro, etc.).
struct VenousCartographyView: View {
    let side: VenousFinding.Side
    let findings: [VenousFinding]

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.logicalWidth, geo.size.height / Self.logicalHeight)
            let canvasW = Self.logicalWidth * scale
            let canvasH = Self.logicalHeight * scale
            let offsetX = (geo.size.width - canvasW) / 2
            let offsetY = (geo.size.height - canvasH) / 2

            ZStack(alignment: .topLeading) {
                Color.white

                // Título superior
                Text(side.label.uppercased())
                    .font(.system(size: 18 * scale, weight: .heavy, design: .default))
                    .tracking(2)
                    .foregroundStyle(Color(hex: "111827"))
                    .position(x: 380 * scale, y: 28 * scale)

                // 4 vistas (anterior, medial, posterior, lateral)
                ForEach(VenousFinding.View.allCases, id: \.self) { view in
                    let xBase = VenousSegmentCatalog.viewBaseX(for: view)
                    Text(view.label)
                        .font(.system(size: 11 * scale, weight: .bold))
                        .foregroundStyle(Color(hex: "4B5563"))
                        .position(x: (xBase + 62) * scale, y: 58 * scale)
                    LegOutlineShape(xBase: xBase, isSide: view == .medial || view == .lateral, isMedial: view == .medial, isPosterior: view == .posterior)
                        .stroke(Color(hex: "111827"), lineWidth: 1.4)
                        .frame(width: canvasW, height: canvasH)
                }

                // Linhas horizontais de referência (alturas anatômicas)
                Path { path in
                    let heights: [(y: CGFloat, isMajor: Bool)] = [
                        (120, false), (250, false), (380, true), (520, false), (620, true)
                    ]
                    for h in heights {
                        path.move(to: CGPoint(x: 24 * scale, y: h.y * scale))
                        path.addLine(to: CGPoint(x: 736 * scale, y: h.y * scale))
                    }
                }
                .stroke(Color(hex: "E5E7EB"), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                // Segmentos com cor por status — usa todos os 18 default como cinza claro de fundo,
                // depois sobrepõe os com findings explícitos
                ForEach(VenousSegmentCatalog.all) { segment in
                    if let path = VenousSegmentCatalog.path(for: segment.id) {
                        let finding = findings.first { $0.segmentId == segment.id }
                        let status = finding?.status
                        SegmentPathShape(path: path)
                            .stroke(
                                Color(hex: status?.colorHex ?? "D1D5DB"),
                                style: StrokeStyle(
                                    lineWidth: (status?.lineWidth ?? 2) * scale,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    dash: (status?.dash ?? []).map { $0 * scale }
                                )
                            )
                            .frame(width: canvasW, height: canvasH)
                            .opacity(status == nil ? 0.45 : 1.0)
                    }
                }

                // Labels dos vasos principais
                vesselLabels(scale: scale)
            }
            .frame(width: canvasW, height: canvasH, alignment: .topLeading)
            .offset(x: offsetX, y: offsetY)
        }
        .aspectRatio(Self.logicalWidth / Self.logicalHeight, contentMode: .fit)
    }

    private func vesselLabels(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            label("JSF", x: 292, y: 86, scale: scale)
            label("VSM", x: 312, y: 214, scale: scale)
            label("JSP", x: 492, y: 330, scale: scale)
            label("VSP", x: 498, y: 438, scale: scale)
            label("VFC", x: 98, y: 168, scale: scale)
            label("VF",  x: 103, y: 286, scale: scale)
            label("Pop", x: 481, y: 360, scale: scale)
        }
    }

    private func label(_ text: String, x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10 * scale, weight: .semibold))
            .foregroundStyle(Color(hex: "111827"))
            .position(x: x * scale, y: y * scale)
    }

    // MARK: - Logical constants

    static let logicalWidth: CGFloat = 760
    static let logicalHeight: CGFloat = 700
}

/// Wrapper de `Path` SwiftUI pra usar como `Shape` (pra suportar `.stroke` direto).
private struct SegmentPathShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path {
        // O path já vem em coords lógicas relativas a (0,0) e a frame externa controla escala.
        let scaleX = rect.width / VenousCartographyView.logicalWidth
        let scaleY = rect.height / VenousCartographyView.logicalHeight
        return path.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}

/// Contorno simplificado de perna — front view (anterior/posterior) ou side view (medial/lateral).
/// Paths portados de `LegOutline` da web.
private struct LegOutlineShape: Shape {
    let xBase: CGFloat
    let isSide: Bool
    let isMedial: Bool
    let isPosterior: Bool

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / VenousCartographyView.logicalWidth
        let scaleY = rect.height / VenousCartographyView.logicalHeight
        let x = xBase

        var p = Path()

        if isSide {
            // Side view (medial/lateral): perfil
            p.move(to: CGPoint(x: x + 30, y: 55))
            p.addCurve(to: CGPoint(x: x + 112, y: 118),
                       control1: CGPoint(x: x + 86, y: 50),
                       control2: CGPoint(x: x + 108, y: 58))
            p.addCurve(to: CGPoint(x: x + 86, y: 315),
                       control1: CGPoint(x: x + 118, y: 178),
                       control2: CGPoint(x: x + 96, y: 246))
            p.addCurve(to: CGPoint(x: x + 80, y: 555),
                       control1: CGPoint(x: x + 78, y: 376),
                       control2: CGPoint(x: x + 94, y: 478))
            p.addCurve(to: CGPoint(x: x + 25, y: 574),
                       control1: CGPoint(x: x + 75, y: 580),
                       control2: CGPoint(x: x + 44, y: 588))
            p.addCurve(to: CGPoint(x: x + 42, y: 466),
                       control1: CGPoint(x: x + 48, y: 552),
                       control2: CGPoint(x: x + 44, y: 514))
            p.addCurve(to: CGPoint(x: x + 42, y: 286),
                       control1: CGPoint(x: x + 38, y: 385),
                       control2: CGPoint(x: x + 36, y: 335))
            p.addCurve(to: CGPoint(x: x + 24, y: 116),
                       control1: CGPoint(x: x + 48, y: 238),
                       control2: CGPoint(x: x + 28, y: 176))
            p.addCurve(to: CGPoint(x: x + 30, y: 55),
                       control1: CGPoint(x: x + 22, y: 88),
                       control2: CGPoint(x: x + 24, y: 68))
            p.closeSubpath()

            // Pé (orientação muda por medial/lateral)
            let footDir: CGFloat = isMedial ? -1 : 1
            p.move(to: CGPoint(x: x + 72, y: 555))
            p.addCurve(to: CGPoint(x: x + 28 * footDir + 72, y: 592),
                       control1: CGPoint(x: x + 98 * footDir + 72, y: 570),
                       control2: CGPoint(x: x + 108 * footDir + 72, y: 592))
        } else {
            // Front view (anterior/posterior): vista frontal de perna+coxa
            p.move(to: CGPoint(x: x + 28, y: 55))
            p.addCurve(to: CGPoint(x: x + 104, y: 55),
                       control1: CGPoint(x: x + 52, y: 64),
                       control2: CGPoint(x: x + 78, y: 64))
            p.addCurve(to: CGPoint(x: x + 84, y: 286),
                       control1: CGPoint(x: x + 110, y: 128),
                       control2: CGPoint(x: x + 102, y: 210))
            p.addCurve(to: CGPoint(x: x + 76, y: 372),
                       control1: CGPoint(x: x + 78, y: 314),
                       control2: CGPoint(x: x + 84, y: 344))
            p.addCurve(to: CGPoint(x: x + 84, y: 552),
                       control1: CGPoint(x: x + 70, y: 402),
                       control2: CGPoint(x: x + 78, y: 500))
            p.addCurve(to: CGPoint(x: x + 28, y: 552),
                       control1: CGPoint(x: x + 70, y: 570),
                       control2: CGPoint(x: x + 42, y: 570))
            p.addCurve(to: CGPoint(x: x + 36, y: 372),
                       control1: CGPoint(x: x + 34, y: 500),
                       control2: CGPoint(x: x + 42, y: 402))
            p.addCurve(to: CGPoint(x: x + 28, y: 286),
                       control1: CGPoint(x: x + 28, y: 344),
                       control2: CGPoint(x: x + 34, y: 314))
            p.addCurve(to: CGPoint(x: x + 28, y: 55),
                       control1: CGPoint(x: x + 10, y: 210),
                       control2: CGPoint(x: x + 2, y: 128))
            p.closeSubpath()

            // Pé
            p.move(to: CGPoint(x: x + 22, y: 575))
            p.addCurve(to: CGPoint(x: x + 96, y: 575),
                       control1: CGPoint(x: x + 40, y: 590),
                       control2: CGPoint(x: x + 78, y: 590))
        }

        return p.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}

// MARK: - Previews

#Preview("Vazio - direito") {
    VenousCartographyView(side: .direita, findings: [])
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("Com achados") {
    VenousCartographyView(
        side: .direita,
        findings: [
            VenousFinding(side: .direita, segmentId: "vfc", vessel: .vfc, view: .anterior, status: .suficiente),
            VenousFinding(side: .direita, segmentId: "vsm-coxa-media", vessel: .vsm, view: .medial, status: .refluxo, refluxSeconds: 1.2),
            VenousFinding(side: .direita, segmentId: "pop-anterior", vessel: .pop, view: .anterior, status: .tromboseAguda),
            VenousFinding(side: .direita, segmentId: "vsp-proximal", vessel: .vsp, view: .posterior, status: .tromboseCronica),
            VenousFinding(side: .direita, segmentId: "vsm-perna", vessel: .vsm, view: .medial, status: .safenectomizada),
        ]
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
