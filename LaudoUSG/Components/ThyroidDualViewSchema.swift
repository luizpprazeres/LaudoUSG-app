import SwiftUI

/// As mesmas bases anatômicas v2 da Web. A vista transversa repete o lobo,
/// sem deduzir profundidade que não existe no achado estruturado.
struct ThyroidDualViewSchema: View {
    let findings: [ThyroidFinding]
    var forceWide = false
    var onMove: ((String, ThyroidFinding.Side, ThyroidFinding.Tercio?) -> Void)? = nil

    @State private var draggingId: String?
    @State private var draggingView: Projection?
    @State private var dragPosition: CGPoint?

    enum Projection {
        case frontal
        case transverse
    }

    private struct Layout {
        let compact: Bool

        var width: CGFloat { compact ? 380 : 760 }
        var height: CGFloat { compact ? 700 : 430 }
        var frontalOffset: CGPoint { compact ? CGPoint(x: -10, y: 0) : .zero }
        var transverseOffset: CGPoint { compact ? CGPoint(x: -375, y: 365) : .zero }
        var frontalImage: CGRect { compact ? CGRect(x: 20, y: 38, width: 340, height: 330) : CGRect(x: 30, y: 38, width: 340, height: 330) }
        var transverseImage: CGRect { compact ? CGRect(x: 20, y: 430, width: 340, height: 226) : CGRect(x: 395, y: 65, width: 340, height: 226) }

        func offset(for projection: Projection) -> CGPoint {
            projection == .frontal ? frontalOffset : transverseOffset
        }

        func position(_ point: CGPoint, in projection: Projection) -> CGPoint {
            let offset = offset(for: projection)
            return CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        }

        func original(_ point: CGPoint, in projection: Projection) -> CGPoint {
            let offset = offset(for: projection)
            return CGPoint(x: point.x - offset.x, y: point.y - offset.y)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = Layout(compact: !forceWide && geometry.size.width < 680)
            let scale = min(geometry.size.width / layout.width, geometry.size.height / layout.height)
            let canvasWidth = layout.width * scale
            let canvasHeight = layout.height * scale

            ZStack(alignment: .topLeading) {
                Color.white
                anatomyImage("ThyroidFrontalV2", frame: layout.frontalImage, scale: scale)
                anatomyImage("ThyroidTransverseV2", frame: layout.transverseImage, scale: scale)
                guideLabels(layout: layout, scale: scale)

                ForEach(Array(findings.enumerated()), id: \.element.id) { index, finding in
                    marker(finding, index: index, projection: .frontal, layout: layout, scale: scale)
                    marker(finding, index: index, projection: .transverse, layout: layout, scale: scale)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .offset(x: (geometry.size.width - canvasWidth) / 2, y: (geometry.size.height - canvasHeight) / 2)
            .coordinateSpace(name: "thyroid_dual_view")
        }
        .accessibilityLabel("Esquema tireoidiano nas vistas frontal e transversa")
    }

    private func anatomyImage(_ name: String, frame: CGRect, scale: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: frame.width * scale, height: frame.height * scale)
            .position(x: frame.midX * scale, y: frame.midY * scale)
            .accessibilityHidden(true)
    }

    private func guideLabels(layout: Layout, scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            label("VISTA FRONTAL", at: CGPoint(x: 200, y: 22), size: 14, weight: .bold, scale: scale, offset: layout.frontalOffset)
            label("LOBO DIREITO", at: CGPoint(x: 145, y: layout.compact ? 376 : 386), size: 11, weight: .semibold, scale: scale, offset: layout.frontalOffset)
            label("LOBO ESQUERDO", at: CGPoint(x: 255, y: layout.compact ? 376 : 386), size: 11, weight: .semibold, scale: scale, offset: layout.frontalOffset)
            label("VISTA TRANSVERSA", at: CGPoint(x: 565, y: layout.compact ? 38 : 28), size: 14, weight: .bold, scale: scale, offset: layout.transverseOffset)
            label("DIREITO", at: CGPoint(x: 485, y: 315), size: 10, weight: .semibold, scale: scale, offset: layout.transverseOffset)
            label("ESQUERDO", at: CGPoint(x: 645, y: 315), size: 10, weight: .semibold, scale: scale, offset: layout.transverseOffset)
            if !layout.compact {
                label("Sem inferir profundidade", at: CGPoint(x: 565, y: 346), size: 10, weight: .regular, scale: scale, offset: layout.transverseOffset)
            }
        }
        .allowsHitTesting(false)
    }

    private func label(_ title: String, at point: CGPoint, size: CGFloat, weight: Font.Weight, scale: CGFloat, offset: CGPoint) -> some View {
        Text(title)
            .font(.system(size: size * scale, weight: weight))
            .foregroundStyle(Color(hex: "111827"))
            .position(x: (point.x + offset.x) * scale, y: (point.y + offset.y) * scale)
    }

    private func marker(_ finding: ThyroidFinding, index: Int, projection: Projection, layout: Layout, scale: CGFloat) -> some View {
        let base = markerPosition(finding, projection: projection, layout: layout)
        let position = draggingId == finding.id && draggingView == projection ? dragPosition ?? base : base
        let radius = ThyroidSchemaView.markerRadius(for: finding, in: findings)

        return ZStack {
            Circle().fill(Color.clear).frame(width: 44 * scale, height: 44 * scale).contentShape(Circle())
            ThyroidMarkerView(finding: finding, radius: radius, scale: scale)
            Text("\(index + 1)")
                .font(.system(size: 10 * scale, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))
                .offset(y: -(radius + 13) * scale)
        }
        .frame(width: 44 * scale, height: 44 * scale)
        .position(x: position.x * scale, y: position.y * scale)
        .gesture(onMove == nil ? nil : dragGesture(for: finding, projection: projection, layout: layout, scale: scale))
        .accessibilityLabel("Achado \(index + 1), \(finding.side.label), \(finding.tercio?.label ?? "istmo"), vista \(projection == .frontal ? "frontal" : "transversa")")
        .accessibilityHint(onMove == nil ? "" : "Arraste para reposicionar")
    }

    private func markerPosition(_ finding: ThyroidFinding, projection: Projection, layout: Layout) -> CGPoint {
        let bucket = findings.filter { $0.side == finding.side && (projection == .transverse || $0.tercio == finding.tercio) }
        let index = bucket.firstIndex(where: { $0.id == finding.id }) ?? 0
        let columns = max(1, min(3, bucket.count))
        let column = index % columns
        let row = index / columns
        let displacement = CGFloat(column) - CGFloat(columns - 1) / 2
        let base: CGPoint
        if projection == .frontal {
            let x: CGFloat = finding.side == .direito ? 145 : finding.side == .esquerdo ? 255 : 200
            let y: CGFloat = finding.side == .istmo ? 252 : finding.tercio == .superior ? 188 : finding.tercio == .inferior ? 292 : 240
            base = CGPoint(x: x + displacement * 18, y: y + CGFloat(row) * 18)
        } else {
            let x: CGFloat = finding.side == .direito ? 500 : finding.side == .esquerdo ? 630 : 565
            let y: CGFloat = finding.side == .istmo ? 188 : 178
            base = CGPoint(x: x + displacement * 20, y: y + CGFloat(row) * 19)
        }
        return layout.position(base, in: projection)
    }

    private func dragGesture(for finding: ThyroidFinding, projection: Projection, layout: Layout, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("thyroid_dual_view"))
            .onChanged { value in
                draggingId = finding.id
                draggingView = projection
                dragPosition = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
            }
            .onEnded { value in
                defer {
                    draggingId = nil
                    draggingView = nil
                    dragPosition = nil
                }
                let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                guard let bucket = Self.bucketAt(layout.original(point, in: projection), projection: projection, preservedThird: finding.tercio) else { return }
                guard bucket.side != finding.side || bucket.third != finding.tercio else { return }
                Haptics.success()
                onMove?(finding.id, bucket.side, bucket.third)
            }
    }

    static func bucketAt(_ point: CGPoint, projection: Projection, preservedThird: ThyroidFinding.Tercio?) -> (side: ThyroidFinding.Side, third: ThyroidFinding.Tercio?)? {
        let x = point.x
        let y = point.y
        if projection == .frontal {
            if (176...224).contains(x) && (230...276).contains(y) { return (.istmo, nil) }
            let side: ThyroidFinding.Side = x < 200 ? .direito : .esquerdo
            let cx: CGFloat = side == .direito ? 145 : 255
            guard insideEllipse(x: x, y: y, cx: cx, cy: 240, rx: 46, ry: 94) else { return nil }
            let third: ThyroidFinding.Tercio = y < 216 ? .superior : y > 268 ? .inferior : .medio
            return (side, third)
        }
        if (538...592).contains(x) && (164...208).contains(y) { return (.istmo, nil) }
        let side: ThyroidFinding.Side = x < 565 ? .direito : .esquerdo
        let cx: CGFloat = side == .direito ? 500 : 630
        guard insideEllipse(x: x, y: y, cx: cx, cy: 178, rx: 58, ry: 68) else { return nil }
        return (side, preservedThird ?? .medio)
    }

    private static func insideEllipse(x: CGFloat, y: CGFloat, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> Bool {
        pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1.2
    }
}
