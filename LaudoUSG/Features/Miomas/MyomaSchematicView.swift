import SwiftUI

enum UterusView: String, CaseIterable {
    case longitudinal = "Longitudinal"
    case transversal = "Transversal"
}

/// Esquema de miomas com toggle entre visões + DRAG dos marcadores (Step 3).
struct MyomaSchematicView: View {
    @Binding var findings: [MyomaFinding]
    @State private var view: UterusView = .longitudinal
    @State private var draggingIndex: Int? = nil

    var body: some View {
        VStack(spacing: 10) {
            Picker("Visão", selection: $view) {
                ForEach(UterusView.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            GeometryReader { geo in
                Canvas { ctx, size in
                    if view == .longitudinal {
                        MyomaCanvasRenderer.drawSagittal(ctx, size, findings)
                    } else {
                        MyomaCanvasRenderer.drawAxial(ctx, size, findings)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(size: geo.size))
            }
            .aspectRatio(
                view == .longitudinal ? MyomaCanvasRenderer.sagAspect : MyomaCanvasRenderer.axAspect,
                contentMode: .fit
            )
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "E3DDD1"), lineWidth: 1)
            )

            Text("Arraste os marcadores pra ajustar a posição.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Drag

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let t = transform(size)
                if draggingIndex == nil {
                    draggingIndex = hitTest(value.startLocation, t: t, size: size)
                }
                guard let i = draggingIndex, i < findings.count else { return }
                let design = value.location.applying(t.inverted())
                if view == .longitudinal {
                    findings[i].sagPoint = design
                } else {
                    findings[i].axPoint = design
                }
            }
            .onEnded { _ in draggingIndex = nil }
    }

    private func transform(_ size: CGSize) -> CGAffineTransform {
        view == .longitudinal ? MyomaCanvasRenderer.sagTransform(size) : MyomaCanvasRenderer.axTransform(size)
    }

    /// Marcador mais próximo do toque (dentro de um limiar proporcional à escala).
    private func hitTest(_ loc: CGPoint, t: CGAffineTransform, size: CGSize) -> Int? {
        let scale = view == .longitudinal ? MyomaCanvasRenderer.sagScale(size) : MyomaCanvasRenderer.axScale(size)
        var best: Int? = nil
        var bestDist: CGFloat = 26 * scale + 14   // raio do marcador + folga
        for (i, f) in findings.enumerated() {
            let dp = view == .longitudinal ? (f.sagPoint ?? f.canonicalSag) : (f.axPoint ?? f.canonicalAx)
            let screen = dp.applying(t)
            let d = hypot(screen.x - loc.x, screen.y - loc.y)
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }
}
