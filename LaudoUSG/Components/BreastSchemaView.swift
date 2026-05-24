import SwiftUI

/// Esquema mamário (bilateral) com marcadores por tipo, hora e distância do mamilo.
/// Porta `components/mamas/BreastSchemaDisplay.tsx` da web — desenho puro nesta etapa.
///
/// Coordenadas lógicas: 640 × 310 (mesmo viewBox da web). A view escala
/// proporcionalmente ao tamanho disponível mantendo aspect ratio 640/310.
struct BreastSchemaView: View {
    let findings: [BreastFinding]
    /// Callback chamado ao soltar um marcador arrastado. Quando `nil`, marcadores não são arrastáveis.
    var onMove: ((String, Int, Double) -> Void)? = nil

    @State private var draggingId: String? = nil
    @State private var dragPosLogical: CGPoint? = nil

    private var isDraggable: Bool { onMove != nil }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.logicalWidth, geo.size.height / Self.logicalHeight)
            let canvasW = Self.logicalWidth * scale
            let canvasH = Self.logicalHeight * scale
            let offsetX = (geo.size.width - canvasW) / 2
            let offsetY = (geo.size.height - canvasH) / 2

            ZStack(alignment: .topLeading) {
                Color.white

                // Títulos
                title("MAMA DIREITA", at: CGPoint(x: Self.rightCx, y: 18), scale: scale)
                title("MAMA ESQUERDA", at: CGPoint(x: Self.leftCx, y: 18), scale: scale)

                // Linha central tracejada
                centralDivider(scale: scale, canvasH: canvasH)

                // Outline mama direita
                BreastOutline(center: CGPoint(x: Self.rightCx, y: Self.cy), side: .direita, scale: scale)
                // Outline mama esquerda
                BreastOutline(center: CGPoint(x: Self.leftCx, y: Self.cy), side: .esquerda, scale: scale)

                // Marcadores — durante drag, posição vai pro dragPosLogical do arrastado,
                // os demais usam spread sem o arrastado pra não pularem
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
                        .position(x: 320 * scale, y: 300 * scale)
                }
            }
            .frame(width: canvasW, height: canvasH, alignment: .topLeading)
            .offset(x: offsetX, y: offsetY)
            .coordinateSpace(name: Self.coordinateSpace)
        }
        .aspectRatio(Self.logicalWidth / Self.logicalHeight, contentMode: .fit)
    }

    @ViewBuilder
    private func markerWithGesture(finding: BreastFinding, pos: CGPoint, scale: CGFloat) -> some View {
        let isDragging = draggingId == finding.id
        let radius = Self.markerRadius(for: finding, in: findings)

        ZStack {
            // Halo durante drag
            if isDragging {
                Circle()
                    .stroke(Color(hex: "6366F1"), lineWidth: 1.5)
                    .frame(width: (radius * 2 + 10) * scale, height: (radius * 2 + 10) * scale)
                    .opacity(0.7)
            }
            // Tap area ampliada (16 lógicos de raio = 32 lógicos de diâmetro)
            Circle()
                .fill(Color.clear)
                .frame(width: 32 * scale, height: 32 * scale)
                .contentShape(Circle())
            // Marker
            BreastMarkerView(
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

    private func dragGesture(for finding: BreastFinding, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                if draggingId == nil { Haptics.tap() }
                draggingId = finding.id
                dragPosLogical = CGPoint(
                    x: value.location.x / scale,
                    y: value.location.y / scale
                )
            }
            .onEnded { value in
                let logical = CGPoint(
                    x: value.location.x / scale,
                    y: value.location.y / scale
                )
                let result = Self.xyToFinding(x: Double(logical.x), y: Double(logical.y), side: finding.side)
                Haptics.success()
                onMove?(finding.id, result.hora, result.distMamilo)
                draggingId = nil
                dragPosLogical = nil
            }
    }

    /// Calcula posições lógicas dos marcadores. Durante drag, exclui o arrastado do spread
    /// pra ele não pular, e sobrescreve sua posição pelo `dragPosLogical`.
    private func computePositions() -> [String: CGPoint] {
        let dragId = draggingId
        let others = dragId == nil ? findings : findings.filter { $0.id != dragId }
        var positions = Self.spreadOverlapping(findings: others)
        if let id = dragId, let pos = dragPosLogical {
            positions[id] = pos
        }
        return positions
    }

    // MARK: - Subviews

    private func title(_ text: String, at point: CGPoint, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11 * scale, weight: .bold, design: .default))
            .foregroundStyle(Color(hex: "374151"))
            .position(x: point.x * scale, y: point.y * scale)
    }

    private func centralDivider(scale: CGFloat, canvasH: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 320 * scale, y: 20 * scale))
            path.addLine(to: CGPoint(x: 320 * scale, y: 300 * scale))
        }
        .stroke(Color(hex: "E5E7EB"), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
    }

    // MARK: - Geometry constants (logical 640×310)

    static let logicalWidth: CGFloat = 640
    static let logicalHeight: CGFloat = 310
    static let rightCx: CGFloat = 168
    static let leftCx: CGFloat = 472
    static let cy: CGFloat = 165
    static let rx: CGFloat = 108
    static let ry: CGFloat = 111
    static let clockRadius: CGFloat = 108
    static let labelRadius: CGFloat = 130
    static let maxDistCm: Double = 6
    static let markerMaxRadius: CGFloat = 14
    static let markerMinRadius: CGFloat = 5
    static let coordinateSpace: String = "breast_schema"

    // MARK: - Coordinate math

    static func horaToAngle(_ hora: Int) -> Double {
        (Double(hora) / 12.0) * 2 * .pi - .pi / 2
    }

    static func quadrantFallbackHora(_ finding: BreastFinding) -> Int {
        guard let q = finding.quadrant else { return 6 }
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

    /// Converte coordenadas lógicas (xy) de volta para hora + distância do mamilo,
    /// dado o lado da mama. Espelha `xyToFinding` da web.
    static func xyToFinding(x: Double, y: Double, side: BreastFinding.Side) -> (hora: Int, distMamilo: Double) {
        let cx = Double(side == .direita ? rightCx : leftCx)
        let cyVal = Double(cy)
        let dx = x - cx
        let dy = y - cyVal
        let angle = atan2(dy, dx)
        let adjustedAngle = angle + .pi / 2
        let normalized = adjustedAngle < 0 ? adjustedAngle + 2 * .pi : adjustedAngle
        var hora = Int(round((normalized / (2 * .pi)) * 12))
        if hora == 0 { hora = 12 }
        if hora > 12 { hora = 12 }
        if hora < 1 { hora = 1 }
        let dist = sqrt(dx * dx + dy * dy)
        let distCm = (dist / Double(clockRadius)) * maxDistCm
        let clamped = min(distCm, maxDistCm)
        let rounded = (clamped * 10).rounded() / 10
        return (hora: hora, distMamilo: rounded)
    }

    /// Converte um finding para coordenadas lógicas (640×310).
    static func findingToXY(_ finding: BreastFinding) -> CGPoint {
        let cx = finding.side == .direita ? rightCx : leftCx
        let hora = finding.hora ?? quadrantFallbackHora(finding)
        let angle = horaToAngle(hora)
        let distFraction: Double
        if let d = finding.distMamilo {
            distFraction = min(d / maxDistCm, 0.95)
        } else {
            distFraction = 0.55
        }
        let r = distFraction * Double(clockRadius)
        return CGPoint(
            x: cx + CGFloat(r * cos(angle)),
            y: cy + CGFloat(r * sin(angle))
        )
    }

    /// Raio do marcador proporcional ao maior sizeMax do conjunto.
    static func markerRadius(for finding: BreastFinding, in all: [BreastFinding]) -> CGFloat {
        let maxSize = max(all.compactMap { $0.sizeMax }.max() ?? 1, 1)
        let ratio = (finding.sizeMax ?? 1) / maxSize
        return markerMinRadius + CGFloat(ratio) * (markerMaxRadius - markerMinRadius)
    }

    /// Aplica spread anti-sobreposição entre marcadores próximos.
    /// Posições em coordenadas lógicas (640×310).
    static func spreadOverlapping(findings: [BreastFinding]) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        for f in findings {
            positions[f.id] = findingToXY(f)
        }
        for i in 0..<findings.count {
            for j in (i + 1)..<findings.count {
                let a = findings[i]
                let b = findings[j]
                guard let posA = positions[a.id], let posB = positions[b.id] else { continue }
                let dx = posB.x - posA.x
                let dy = posB.y - posA.y
                let dist = sqrt(dx * dx + dy * dy)
                let minDist = markerRadius(for: b, in: findings) * 2.5
                if dist < minDist {
                    let angle = atan2(dy, dx) + .pi / 6
                    let pushDist = minDist
                    positions[b.id] = CGPoint(
                        x: posA.x + pushDist * cos(angle),
                        y: posA.y + pushDist * sin(angle)
                    )
                }
            }
        }
        return positions
    }
}

// MARK: - Breast outline (elipse + mamilo + cruz + horas + quadrantes)

private struct BreastOutline: View {
    let center: CGPoint
    let side: BreastFinding.Side
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Elipse externa
            Ellipse()
                .fill(Color.white)
                .frame(width: BreastSchemaView.rx * 2 * scale, height: BreastSchemaView.ry * 2 * scale)
                .overlay(
                    Ellipse().stroke(Color(hex: "111827"), lineWidth: 2)
                )
                .position(x: center.x * scale, y: center.y * scale)

            // Cruz tracejada (eixos horizontal e vertical)
            Path { path in
                let cx = center.x * scale
                let cy = center.y * scale
                let rx = BreastSchemaView.rx * scale
                let ry = BreastSchemaView.ry * scale
                path.move(to: CGPoint(x: cx - rx, y: cy))
                path.addLine(to: CGPoint(x: cx + rx, y: cy))
                path.move(to: CGPoint(x: cx, y: cy - ry))
                path.addLine(to: CGPoint(x: cx, y: cy + ry))
            }
            .stroke(Color(hex: "374151"), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))

            // Mamilo (areola + papila)
            Circle()
                .fill(Color.white)
                .frame(width: 40 * scale, height: 40 * scale)
                .overlay(Circle().stroke(Color(hex: "111827"), lineWidth: 2))
                .position(x: center.x * scale, y: center.y * scale)
            Circle()
                .fill(Color(hex: "111827"))
                .frame(width: 14 * scale, height: 14 * scale)
                .position(x: center.x * scale, y: center.y * scale)

            // Números das horas (1-12)
            ForEach(1...12, id: \.self) { h in
                let angle = BreastSchemaView.horaToAngle(h)
                let lx = center.x + BreastSchemaView.labelRadius * CGFloat(cos(angle))
                let ly = center.y + BreastSchemaView.labelRadius * CGFloat(sin(angle))
                Text(String(format: "%02d", h))
                    .font(.system(size: 9 * scale, weight: .regular))
                    .foregroundStyle(Color(hex: "6B7280"))
                    .position(x: lx * scale, y: ly * scale)
            }

            // Quadrantes (QSL, QSM, QIL, QIM)
            ForEach(quadrantLabels, id: \.label) { q in
                Text(q.label)
                    .font(.system(size: 7 * scale, weight: .regular))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                    .position(x: q.x * scale, y: q.y * scale)
            }
        }
    }

    private var quadrantLabels: [(label: String, x: CGFloat, y: CGFloat)] {
        let qOffset: CGFloat = 54
        let cx = center.x
        let cy = center.y
        if side == .direita {
            return [
                ("Q.S.L.", cx - qOffset, cy - qOffset),
                ("Q.S.M.", cx + qOffset, cy - qOffset),
                ("Q.I.L.", cx - qOffset, cy + qOffset),
                ("Q.I.M.", cx + qOffset, cy + qOffset),
            ]
        } else {
            return [
                ("Q.S.M.", cx - qOffset, cy - qOffset),
                ("Q.S.L.", cx + qOffset, cy - qOffset),
                ("Q.I.M.", cx - qOffset, cy + qOffset),
                ("Q.I.L.", cx + qOffset, cy + qOffset),
            ]
        }
    }
}

// MARK: - Marker por tipo

private struct BreastMarkerView: View {
    let finding: BreastFinding
    let radius: CGFloat
    let scale: CGFloat

    var body: some View {
        let r = radius * scale
        let ink = Color(hex: "111827")
        let opacity: Double = finding.approximate ? 0.5 : 1.0

        Group {
            switch finding.type {
            case .calcification:
                Rectangle()
                    .fill(ink)
                    .frame(width: r * 1.4, height: r * 1.4)
                    .rotationEffect(.degrees(45))

            case .cyst:
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(ink, lineWidth: 1.5))
                    .frame(width: r * 2, height: r * 2)

            case .lymphNode:
                ZStack {
                    Ellipse()
                        .fill(Color.white)
                        .overlay(Ellipse().stroke(ink, lineWidth: 1.5))
                        .frame(width: r * 3, height: r * 1.7)
                    Ellipse()
                        .fill(ink)
                        .frame(width: r * 1.1, height: r * 0.9)
                }

            case .solidLobulated:
                LobulatedShape(lobes: 4, amplitude: 0.22)
                    .fill(ink)
                    .frame(width: r * 2, height: r * 2)

            case .solid:
                Circle()
                    .fill(ink)
                    .frame(width: r * 2, height: r * 2)
            }
        }
        .opacity(opacity)
    }
}

private struct LobulatedShape: Shape {
    let lobes: Int
    let amplitude: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        let amp = r * amplitude
        let steps = 60

        for i in 0...steps {
            let angle = (Double(i) / Double(steps)) * 2 * .pi - .pi / 2
            let radius = r + amp * sin(Double(lobes) * angle)
            let x = cx + radius * CGFloat(cos(angle))
            let y = cy + radius * CGFloat(sin(angle))
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("Vazio") {
    BreastSchemaView(findings: [])
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("Achados de exemplo") {
    BreastSchemaView(findings: [
        BreastFinding(side: .direita, type: .solid, hora: 2, sizeMax: 8, distMamilo: 3),
        BreastFinding(side: .direita, type: .cyst, hora: 10, sizeMax: 12, distMamilo: 4),
        BreastFinding(side: .esquerda, type: .calcification, hora: 12, sizeMax: 4, distMamilo: 2),
        BreastFinding(side: .esquerda, type: .lymphNode, hora: 11, sizeMax: 6, distMamilo: 5),
        BreastFinding(side: .esquerda, type: .solidLobulated, hora: 7, sizeMax: 15, distMamilo: 3.5),
    ])
    .padding()
    .background(Color.gray.opacity(0.1))
}
