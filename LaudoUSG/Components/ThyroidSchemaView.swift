import SwiftUI

/// Esquema tireoidiano com 2 lobos + istmo + cartilagem tireoide + traqueia.
/// Step 1 — desenho puro P&B uniformizado com `BreastSchemaView`.
/// Coordenadas lógicas: 480 × 480 (mesmo viewBox da web `ThyroidSchemaDisplay.tsx`).
struct ThyroidSchemaView: View {
    let findings: [ThyroidFinding]
    /// Callback chamado ao soltar um marcador arrastado num bucket válido.
    /// Quando `nil`, marcadores não são arrastáveis.
    var onMove: ((String, ThyroidFinding.Side, ThyroidFinding.Tercio?) -> Void)? = nil

    @State private var draggingId: String? = nil
    @State private var dragPosLogical: CGPoint? = nil
    @State private var hoverBucket: (side: ThyroidFinding.Side, tercio: ThyroidFinding.Tercio?)? = nil

    private var isDraggable: Bool { onMove != nil }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.logicalSide, geo.size.height / Self.logicalSide)
            let canvas = Self.logicalSide * scale
            let offsetX = (geo.size.width - canvas) / 2
            let offsetY = (geo.size.height - canvas) / 2

            ZStack(alignment: .topLeading) {
                Color.white

                // Traqueia (primeiro no z-order — passa atrás do istmo, levemente transparente)
                tracheaGroup(scale: scale)

                // Cartilagem tireoide (escudo no topo, sobreposta à traqueia)
                CartilageShape()
                    .fill(Color(hex: "F8FAFC"))
                    .overlay(CartilageShape().stroke(Color(hex: "111827"), lineWidth: 1.5))
                    .frame(width: canvas, height: canvas)
                CartilageDetailShape()
                    .stroke(Color(hex: "4B5563"), lineWidth: 1)
                    .frame(width: canvas, height: canvas)
                label("cartilagem tireoide", x: 240, y: 32, size: 9, weight: .regular, color: Color(hex: "6B7280"), scale: scale)

                // Linhas tracejadas dos terços (atrás dos lobos, mas dentro do contorno)
                tercioGuides(scale: scale)

                // Lobo direito
                RightLobeShape()
                    .fill(Color.white)
                    .overlay(RightLobeShape().stroke(Color(hex: "111827"), lineWidth: 1.5))
                    .frame(width: canvas, height: canvas)

                // Lobo esquerdo
                LeftLobeShape()
                    .fill(Color.white)
                    .overlay(LeftLobeShape().stroke(Color(hex: "111827"), lineWidth: 1.5))
                    .frame(width: canvas, height: canvas)

                // Istmo (retângulo arredondado entre lobos — cobre a traqueia)
                RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                            .stroke(Color(hex: "111827"), lineWidth: 1.5)
                    )
                    .frame(width: Self.isthmusW * scale, height: Self.isthmusH * scale)
                    .position(x: Self.isthmusCx * scale, y: Self.isthmusCy * scale)

                // Rótulos (acima do topo dos lobos)
                label("Lobo Direito", x: Self.rightLobeCx, y: Self.lobeLabelY, size: 11, weight: .semibold, color: Color(hex: "111827"), scale: scale)
                label("Lobo Esquerdo", x: Self.leftLobeCx, y: Self.lobeLabelY, size: 11, weight: .semibold, color: Color(hex: "111827"), scale: scale)
                label("ISTMO", x: Self.isthmusCx, y: Self.isthmusCy + 4, size: 9, weight: .medium, color: Color(hex: "374151"), scale: scale)
                label("traqueia", x: Self.tracheaCx, y: Self.tracheaBaseLineY + 14, size: 8, weight: .regular, color: Color(hex: "6B7280"), scale: scale)

                // Rótulos de terço (ao lado do lobo direito)
                label("sup", x: Self.rightLobeCx - 78, y: Self.tercioSup + 3, size: 8, weight: .regular, color: Color(hex: "9CA3AF"), scale: scale)
                label("med", x: Self.rightLobeCx - 78, y: Self.tercioMed + 3, size: 8, weight: .regular, color: Color(hex: "9CA3AF"), scale: scale)
                label("inf", x: Self.rightLobeCx - 78, y: Self.tercioInf + 3, size: 8, weight: .regular, color: Color(hex: "9CA3AF"), scale: scale)

                // Highlight do bucket destino durante drag
                if let bucket = hoverBucket {
                    bucketHighlight(side: bucket.side, tercio: bucket.tercio, scale: scale)
                }

                // Marcadores
                let positions = computePositions()
                ForEach(findings) { finding in
                    if let pos = positions[finding.id] {
                        markerWithGesture(finding: finding, pos: pos, scale: scale)
                    }
                }

                if isDraggable && !findings.isEmpty && draggingId == nil {
                    Text("Arraste os marcadores para reposicionar")
                        .font(.system(size: 7.5 * scale))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                        .position(x: 240 * scale, y: 470 * scale)
                }
            }
            .frame(width: canvas, height: canvas, alignment: .topLeading)
            .offset(x: offsetX, y: offsetY)
            .coordinateSpace(name: Self.coordinateSpace)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func markerWithGesture(finding: ThyroidFinding, pos: CGPoint, scale: CGFloat) -> some View {
        let isDragging = draggingId == finding.id
        let radius = Self.markerRadius(for: finding, in: findings)

        ZStack {
            if isDragging {
                Circle()
                    .stroke(Color(hex: "6366F1"), lineWidth: 1.5)
                    .frame(width: (radius * 2 + 10) * scale, height: (radius * 2 + 10) * scale)
                    .opacity(0.7)
            }
            // Hit area expandida
            Circle()
                .fill(Color.clear)
                .frame(width: 36 * scale, height: 36 * scale)
                .contentShape(Circle())
            ThyroidMarkerView(
                finding: finding,
                radius: radius,
                scale: scale
            )
        }
        .scaleEffect(isDragging ? 1.25 : 1.0)
        .animation(isDragging ? nil : .snappy(duration: 0.15), value: isDragging)
        .position(x: pos.x * scale, y: pos.y * scale)
        .gesture(isDraggable ? dragGesture(for: finding, scale: scale) : nil)
    }

    private func dragGesture(for finding: ThyroidFinding, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                if draggingId == nil { Haptics.tap() }
                draggingId = finding.id
                let logical = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                dragPosLogical = logical
                hoverBucket = Self.bucketAt(x: logical.x, y: logical.y)
            }
            .onEnded { value in
                let logical = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                defer {
                    draggingId = nil
                    dragPosLogical = nil
                    hoverBucket = nil
                }
                // Snap pro bucket destino. Se ponto fora dos lobos/istmo → mantém posição original.
                guard let bucket = Self.bucketAt(x: logical.x, y: logical.y) else { return }
                let changed = bucket.side != finding.side || bucket.tercio != finding.tercio
                guard changed else { return }
                Haptics.success()
                onMove?(finding.id, bucket.side, bucket.tercio)
            }
    }

    /// Posições lógicas dos marcadores. Durante drag, exclui o arrastado do spread
    /// e usa `dragPosLogical` direto pra ele.
    private func computePositions() -> [String: CGPoint] {
        let dragId = draggingId
        let others = dragId == nil ? findings : findings.filter { $0.id != dragId }
        var positions = Self.spreadOverlapping(findings: others)
        if let id = dragId, let pos = dragPosLogical {
            positions[id] = pos
        }
        return positions
    }

    /// Overlay sutil destacando o bucket destino enquanto o usuário arrasta.
    @ViewBuilder
    private func bucketHighlight(side: ThyroidFinding.Side, tercio: ThyroidFinding.Tercio?, scale: CGFloat) -> some View {
        let highlight = Color(hex: "6366F1").opacity(0.12)
        switch side {
        case .istmo:
            RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                .fill(highlight)
                .frame(width: (Self.isthmusW + 4) * scale, height: (Self.isthmusH + 4) * scale)
                .position(x: Self.isthmusCx * scale, y: Self.isthmusCy * scale)
        case .direito, .esquerdo:
            let cx = side == .direito ? Self.rightLobeCx : Self.leftLobeCx
            let yCenter: CGFloat = {
                switch tercio {
                case .superior: return (Self.tercioSup + Self.tercioLineUpper) / 2
                case .medio, .none: return (Self.tercioLineUpper + Self.tercioLineLower) / 2
                case .inferior: return (Self.tercioLineLower + 365) / 2
                }
            }()
            let h: CGFloat = {
                switch tercio {
                case .superior: return Self.tercioLineUpper - 152
                case .medio, .none: return Self.tercioLineLower - Self.tercioLineUpper
                case .inferior: return 365 - Self.tercioLineLower
                }
            }()
            Ellipse()
                .fill(highlight)
                .frame(width: 110 * scale, height: h * scale)
                .position(x: cx * scale, y: yCenter * scale)
        }
    }

    // MARK: - Subviews

    private func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: Font.Weight, color: Color, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size * scale, weight: weight, design: .default))
            .foregroundStyle(color)
            .position(x: x * scale, y: y * scale)
    }

    private func tercioGuides(scale: CGFloat) -> some View {
        Path { path in
            // Lobo D
            let leftStartX = (Self.rightLobeCx - 38) * scale
            let leftEndX = (Self.rightLobeCx + 38) * scale
            // Lobo E
            let rightStartX = (Self.leftLobeCx - 38) * scale
            let rightEndX = (Self.leftLobeCx + 38) * scale
            let upper = Self.tercioLineUpper * scale
            let lower = Self.tercioLineLower * scale

            path.move(to: CGPoint(x: leftStartX, y: upper))
            path.addLine(to: CGPoint(x: leftEndX, y: upper))
            path.move(to: CGPoint(x: leftStartX, y: lower))
            path.addLine(to: CGPoint(x: leftEndX, y: lower))

            path.move(to: CGPoint(x: rightStartX, y: upper))
            path.addLine(to: CGPoint(x: rightEndX, y: upper))
            path.move(to: CGPoint(x: rightStartX, y: lower))
            path.addLine(to: CGPoint(x: rightEndX, y: lower))
        }
        .stroke(Color(hex: "9CA3AF"), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
    }

    private func tracheaGroup(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Tubo da traqueia — contínuo, levemente transparente. Vai passar atrás dos
            // lobos e do istmo (renderizado antes deles no ZStack pai).
            RoundedRectangle(cornerRadius: Self.tracheaCorner * scale, style: .continuous)
                .fill(Color(hex: "F8FAFC").opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: Self.tracheaCorner * scale, style: .continuous)
                        .stroke(Color(hex: "94A3B8").opacity(0.55), lineWidth: 1.2)
                )
                .frame(width: Self.tracheaW * scale, height: Self.tracheaH * scale)
                .position(x: Self.tracheaCx * scale, y: (Self.tracheaY + Self.tracheaH / 2) * scale)

            // Anéis cartilaginosos ao longo de toda a extensão da traqueia.
            Path { path in
                for ringY in Self.tracheaRings {
                    path.move(to: CGPoint(x: (Self.tracheaX + 4) * scale, y: ringY * scale))
                    path.addLine(to: CGPoint(x: (Self.tracheaX + Self.tracheaW - 4) * scale, y: ringY * scale))
                }
            }
            .stroke(Color(hex: "94A3B8").opacity(0.45), lineWidth: 0.9)
        }
    }

    // MARK: - Geometry constants (logical 480×480)

    static let logicalSide: CGFloat = 480
    static let rightLobeCx: CGFloat = 130
    static let leftLobeCx: CGFloat = 350
    static let lobeCy: CGFloat = 250
    static let isthmusX: CGFloat = 198
    static let isthmusY: CGFloat = 240
    static let isthmusW: CGFloat = 84
    static let isthmusH: CGFloat = 40
    static let isthmusCx: CGFloat = 240
    static let isthmusCy: CGFloat = 260

    // Traqueia: contínua de logo abaixo da cartilagem até a base (passa atrás do istmo)
    static let tracheaX: CGFloat = 218
    static let tracheaY: CGFloat = 152
    static let tracheaW: CGFloat = 44
    static let tracheaH: CGFloat = 295
    static let tracheaCx: CGFloat = 240
    static let tracheaCorner: CGFloat = 4
    static let tracheaBaseLineY: CGFloat = tracheaY + tracheaH
    static let tracheaRings: [CGFloat] = [180, 210, 308, 338, 368, 398, 425]
    static let lobeLabelY: CGFloat = 138

    static let tercioSup: CGFloat = 195
    static let tercioMed: CGFloat = 250
    static let tercioInf: CGFloat = 320
    static let tercioLineUpper: CGFloat = 222
    static let tercioLineLower: CGFloat = 295

    static let markerMinRadius: CGFloat = 5
    static let markerMaxRadius: CGFloat = 13
    static let markerDefaultRadius: CGFloat = 8
    static let spreadStep: CGFloat = 20
    static let coordinateSpace: String = "thyroid_schema"

    // MARK: - Position math

    static func tercioY(_ tercio: ThyroidFinding.Tercio?) -> CGFloat {
        switch tercio {
        case .superior: return tercioSup
        case .inferior: return tercioInf
        case .medio, .none: return tercioMed
        }
    }

    static func sideCx(_ side: ThyroidFinding.Side) -> CGFloat {
        switch side {
        case .direito: return rightLobeCx
        case .esquerdo: return leftLobeCx
        case .istmo: return isthmusCx
        }
    }

    /// Posição base (sem spread) — centro do bucket lobo+terço ou istmo.
    static func findingToXY(_ f: ThyroidFinding) -> CGPoint {
        if f.side == .istmo {
            return CGPoint(x: isthmusCx, y: isthmusCy)
        }
        return CGPoint(x: sideCx(f.side), y: tercioY(f.tercio))
    }

    /// Hit-test inverso: dado um ponto em coords lógicas, retorna (side, tercio) do bucket
    /// mais próximo — usado pelo drag pra fazer snap. Retorna nil se ponto está fora dos lobos/istmo.
    static func bucketAt(x: CGFloat, y: CGFloat) -> (side: ThyroidFinding.Side, tercio: ThyroidFinding.Tercio?)? {
        // Istmo
        if x >= isthmusX, x <= isthmusX + isthmusW,
           y >= isthmusY, y <= isthmusY + isthmusH {
            return (.istmo, nil)
        }

        let rxLobe: CGFloat = 60
        let ryLobe: CGFloat = 110

        // Lobo D
        let dx1 = (x - rightLobeCx) / rxLobe
        let dy1 = (y - lobeCy) / ryLobe
        if dx1 * dx1 + dy1 * dy1 <= 1.05 {
            return (.direito, classifyTercio(y: y))
        }

        // Lobo E
        let dx2 = (x - leftLobeCx) / rxLobe
        let dy2 = (y - lobeCy) / ryLobe
        if dx2 * dx2 + dy2 * dy2 <= 1.05 {
            return (.esquerdo, classifyTercio(y: y))
        }

        return nil
    }

    private static func classifyTercio(y: CGFloat) -> ThyroidFinding.Tercio {
        if y < tercioLineUpper { return .superior }
        if y > tercioLineLower { return .inferior }
        return .medio
    }

    /// Raio do marcador proporcional ao maior sizeMax.
    static func markerRadius(for finding: ThyroidFinding, in all: [ThyroidFinding]) -> CGFloat {
        let maxSize = max(all.compactMap { $0.sizeMax }.max() ?? 0, 1)
        guard let s = finding.sizeMax, s > 0 else { return markerDefaultRadius }
        let ratio = min(s / maxSize, 1)
        return markerMinRadius + CGFloat(ratio) * (markerMaxRadius - markerMinRadius)
    }

    /// Honeycomb spread: bucketiza por (side, tercio) e espalha dentro do bucket.
    static func spreadOverlapping(findings: [ThyroidFinding]) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        var buckets: [String: [ThyroidFinding]] = [:]

        for f in findings {
            let key = "\(f.side.rawValue)-\(f.tercio?.rawValue ?? "nil")"
            buckets[key, default: []].append(f)
        }

        for (_, group) in buckets {
            let n = group.count
            for (idx, f) in group.enumerated() {
                let base = findingToXY(f)
                let offset = spreadInBucket(n: n, idx: idx, step: spreadStep)
                positions[f.id] = CGPoint(x: base.x + offset.dx, y: base.y + offset.dy)
            }
        }

        return positions
    }

    private static func spreadInBucket(n: Int, idx: Int, step: CGFloat) -> (dx: CGFloat, dy: CGFloat) {
        if n == 1 { return (0, 0) }
        if n <= 3 {
            let dx = (CGFloat(idx) - CGFloat(n - 1) / 2) * step
            return (dx, 0)
        }
        let cols = Int(ceil(Double(n) / 2))
        let row = idx / cols
        let col = idx % cols
        let rowOffset = CGFloat(row % 2) * (step / 2)
        let dx = (CGFloat(col) - CGFloat(cols - 1) / 2) * step + rowOffset
        let dy = (CGFloat(row) - 0.5) * step * 0.85
        return (dx, dy)
    }
}

// MARK: - Anatomy shapes (paths Bezier do SVG da web)

/// Cartilagem tireoide (escudo no topo).
private struct CartilageShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / ThyroidSchemaView.logicalSide
        var p = Path()
        p.move(to: CGPoint(x: 195 * s, y: 60 * s))
        p.addLine(to: CGPoint(x: 215 * s, y: 50 * s))
        p.addLine(to: CGPoint(x: 240 * s, y: 75 * s))
        p.addLine(to: CGPoint(x: 265 * s, y: 50 * s))
        p.addLine(to: CGPoint(x: 285 * s, y: 60 * s))
        p.addLine(to: CGPoint(x: 295 * s, y: 95 * s))
        p.addLine(to: CGPoint(x: 295 * s, y: 135 * s))
        p.addLine(to: CGPoint(x: 185 * s, y: 135 * s))
        p.addLine(to: CGPoint(x: 185 * s, y: 95 * s))
        p.closeSubpath()
        return p
    }
}

/// Detalhe da cartilagem (linhas curvas internas).
private struct CartilageDetailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / ThyroidSchemaView.logicalSide
        var p = Path()
        p.move(to: CGPoint(x: 215 * s, y: 85 * s))
        p.addQuadCurve(to: CGPoint(x: 265 * s, y: 85 * s), control: CGPoint(x: 240 * s, y: 95 * s))
        p.move(to: CGPoint(x: 210 * s, y: 110 * s))
        p.addQuadCurve(to: CGPoint(x: 270 * s, y: 110 * s), control: CGPoint(x: 240 * s, y: 120 * s))
        return p
    }
}

/// Lobo direito (Bezier path da web).
private struct RightLobeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / ThyroidSchemaView.logicalSide
        var p = Path()
        p.move(to: CGPoint(x: 158 * s, y: 152 * s))
        p.addCurve(to: CGPoint(x: 78 * s, y: 200 * s),
                   control1: CGPoint(x: 130 * s, y: 148 * s),
                   control2: CGPoint(x: 95 * s, y: 168 * s))
        p.addCurve(to: CGPoint(x: 80 * s, y: 320 * s),
                   control1: CGPoint(x: 62 * s, y: 235 * s),
                   control2: CGPoint(x: 62 * s, y: 285 * s))
        p.addCurve(to: CGPoint(x: 168 * s, y: 365 * s),
                   control1: CGPoint(x: 100 * s, y: 355 * s),
                   control2: CGPoint(x: 138 * s, y: 372 * s))
        p.addCurve(to: CGPoint(x: 198 * s, y: 308 * s),
                   control1: CGPoint(x: 188 * s, y: 360 * s),
                   control2: CGPoint(x: 198 * s, y: 340 * s))
        p.addLine(to: CGPoint(x: 198 * s, y: 230 * s))
        p.addCurve(to: CGPoint(x: 178 * s, y: 156 * s),
                   control1: CGPoint(x: 200 * s, y: 198 * s),
                   control2: CGPoint(x: 192 * s, y: 168 * s))
        p.addCurve(to: CGPoint(x: 158 * s, y: 152 * s),
                   control1: CGPoint(x: 170 * s, y: 150 * s),
                   control2: CGPoint(x: 164 * s, y: 150 * s))
        p.closeSubpath()
        return p
    }
}

/// Lobo esquerdo (espelhado em torno de x=240).
private struct LeftLobeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / ThyroidSchemaView.logicalSide
        var p = Path()
        p.move(to: CGPoint(x: 322 * s, y: 152 * s))
        p.addCurve(to: CGPoint(x: 402 * s, y: 200 * s),
                   control1: CGPoint(x: 350 * s, y: 148 * s),
                   control2: CGPoint(x: 385 * s, y: 168 * s))
        p.addCurve(to: CGPoint(x: 400 * s, y: 320 * s),
                   control1: CGPoint(x: 418 * s, y: 235 * s),
                   control2: CGPoint(x: 418 * s, y: 285 * s))
        p.addCurve(to: CGPoint(x: 312 * s, y: 365 * s),
                   control1: CGPoint(x: 380 * s, y: 355 * s),
                   control2: CGPoint(x: 342 * s, y: 372 * s))
        p.addCurve(to: CGPoint(x: 282 * s, y: 308 * s),
                   control1: CGPoint(x: 292 * s, y: 360 * s),
                   control2: CGPoint(x: 282 * s, y: 340 * s))
        p.addLine(to: CGPoint(x: 282 * s, y: 230 * s))
        p.addCurve(to: CGPoint(x: 302 * s, y: 156 * s),
                   control1: CGPoint(x: 280 * s, y: 198 * s),
                   control2: CGPoint(x: 288 * s, y: 168 * s))
        p.addCurve(to: CGPoint(x: 322 * s, y: 152 * s),
                   control1: CGPoint(x: 310 * s, y: 150 * s),
                   control2: CGPoint(x: 316 * s, y: 150 * s))
        p.closeSubpath()
        return p
    }
}

// MARK: - Marcadores (P&B uniformizado com mama)

private struct ThyroidMarkerView: View {
    let finding: ThyroidFinding
    let radius: CGFloat
    let scale: CGFloat

    var body: some View {
        let r = radius * scale
        let ink = Color(hex: "111827")
        let opacity: Double = finding.approximate ? 0.55 : 1.0
        let isOval = finding.shape == .oval
        let isLobulated = finding.shape == .lobulated

        Group {
            switch finding.type {
            case .calcification:
                LosangoShape()
                    .fill(ink)
                    .frame(width: max(r * 1.5, 8), height: max(r * 1.5, 8))

            case .cystic:
                shapedMarker(filled: false, stroke: ink, dashed: false, isOval: isOval, isLobulated: isLobulated, r: r)

            case .spongiform:
                shapedMarker(filled: false, stroke: ink, dashed: true, isOval: isOval, isLobulated: isLobulated, r: r)

            case .mixed:
                MixedMarker(rx: isOval ? r * 1.35 : r, ry: isOval ? r * 0.75 : r, ink: ink)
                    .frame(width: (isOval ? r * 1.35 : r) * 2, height: (isOval ? r * 0.75 : r) * 2)

            case .solid:
                shapedMarker(filled: true, stroke: ink, dashed: false, isOval: isOval, isLobulated: isLobulated, r: r)
            }
        }
        .opacity(opacity)
    }

    @ViewBuilder
    private func shapedMarker(filled: Bool, stroke: Color, dashed: Bool, isOval: Bool, isLobulated: Bool, r: CGFloat) -> some View {
        let rx = isOval ? r * 1.35 : r
        let ry = isOval ? r * 0.75 : r
        let dashStyle = StrokeStyle(lineWidth: 2, dash: dashed ? [2, 2] : [])
        if isLobulated {
            LobulatedShape5()
                .fill(filled ? stroke : Color.white)
                .overlay(LobulatedShape5().stroke(stroke, style: dashStyle))
                .frame(width: r * 2, height: r * 2)
        } else {
            if filled {
                Ellipse()
                    .fill(stroke)
                    .frame(width: rx * 2, height: ry * 2)
            } else {
                Ellipse()
                    .fill(Color.white)
                    .overlay(Ellipse().stroke(stroke, style: dashStyle))
                    .frame(width: rx * 2, height: ry * 2)
            }
        }
    }
}

private struct MixedMarker: View {
    let rx: CGFloat
    let ry: CGFloat
    let ink: Color

    var body: some View {
        ZStack {
            // Elipse preenchida com mask de metade esquerda — funciona pra qualquer aspect ratio.
            Ellipse()
                .fill(ink)
                .opacity(0.85)
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()       // metade esquerda visível
                        Color.clear       // metade direita invisível
                    }
                )
            // Contorno completo
            Ellipse()
                .stroke(ink, lineWidth: 2)
        }
    }
}

private struct LosangoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let w = rect.width / 2
        let h = rect.height / 2
        p.move(to: CGPoint(x: cx, y: cy - h))
        p.addLine(to: CGPoint(x: cx + w, y: cy))
        p.addLine(to: CGPoint(x: cx, y: cy + h))
        p.addLine(to: CGPoint(x: cx - w, y: cy))
        p.closeSubpath()
        return p
    }
}

private struct LobulatedShape5: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        let amplitude = r * 0.28
        let steps = 60
        for i in 0...steps {
            let angle = (Double(i) / Double(steps)) * 2 * .pi
            let rad = r + amplitude * sin(5 * angle)
            let x = cx + rad * CGFloat(cos(angle))
            let y = cy + rad * CGFloat(sin(angle))
            if i == 0 {
                p.move(to: CGPoint(x: x, y: y))
            } else {
                p.addLine(to: CGPoint(x: x, y: y))
            }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Previews

#Preview("Vazio") {
    ThyroidSchemaView(findings: [])
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("Achados de exemplo") {
    ThyroidSchemaView(findings: [
        ThyroidFinding(side: .direito, tercio: .superior, type: .cystic, sizeMax: 8),
        ThyroidFinding(side: .direito, tercio: .medio, type: .solid, sizeMax: 12),
        ThyroidFinding(side: .esquerdo, tercio: .superior, type: .spongiform, shape: .lobulated, sizeMax: 6),
        ThyroidFinding(side: .esquerdo, tercio: .inferior, type: .mixed, shape: .oval, sizeMax: 15),
        ThyroidFinding(side: .istmo, tercio: nil, type: .calcification, sizeMax: 3),
    ])
    .padding()
    .background(Color.gray.opacity(0.1))
}
