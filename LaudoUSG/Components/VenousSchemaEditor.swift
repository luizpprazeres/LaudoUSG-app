import SwiftUI

/// Editor de cartografia venosa MMII — chips por vista.
/// Decisão de design: chips em vez de tap direto no path SVG (hit-test de path
/// Bezier em mobile é impreciso e propenso a conflitos de gesto). Cada chip mostra
/// shortLabel + cor do status atual; tap abre dialog com os 8 status + "Remover".
@MainActor
struct VenousSchemaEditor: View {
    let side: VenousFinding.Side
    @Binding var findings: [VenousFinding]

    @State private var pickerSegment: VenousSegmentCatalog.Segment? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Marcar status do segmento")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            ForEach(VenousFinding.View.allCases, id: \.self) { view in
                viewSection(view: view)
            }

            Text("Toque em um chip para escolher o status do segmento (ou removê-lo).")
                .font(.system(size: 10))
                .foregroundStyle(AppSurface.textMuted)
                .italic()
        }
        .confirmationDialog(
            pickerTitle,
            isPresented: Binding(
                get: { pickerSegment != nil },
                set: { if !$0 { pickerSegment = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(VenousFinding.Status.allCases) { status in
                Button(status.label) {
                    if let segment = pickerSegment {
                        applyStatus(status, to: segment)
                    }
                    pickerSegment = nil
                }
            }
            if pickerSegment.flatMap({ findingFor($0) }) != nil {
                Button("Remover", role: .destructive) {
                    if let segment = pickerSegment {
                        removeFinding(for: segment)
                    }
                    pickerSegment = nil
                }
            }
            Button("Cancelar", role: .cancel) { pickerSegment = nil }
        } message: {
            if let segment = pickerSegment {
                Text(segment.label)
            }
        }
    }

    private var pickerTitle: String {
        guard let s = pickerSegment else { return "" }
        return s.shortLabel
    }

    private func viewSection(view: VenousFinding.View) -> some View {
        let segments = VenousSegmentCatalog.all.filter { $0.view == view }
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: 4) {
                Text(view.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppSurface.textMuted)
                    .textCase(.uppercase)
                Spacer()
            }
            FlowLayout(spacing: 6) {
                ForEach(segments) { segment in
                    chip(for: segment)
                }
            }
        }
    }

    private func chip(for segment: VenousSegmentCatalog.Segment) -> some View {
        let finding = findingFor(segment)
        let status = finding?.status
        let hasStatus = status != nil
        let color = hasStatus ? Color(hex: status!.colorHex) : AppSurface.textMuted

        return Button {
            Haptics.tap()
            pickerSegment = segment
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(chipText(segment: segment))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppSurface.textPrimary)
                if hasStatus {
                    Text("·")
                        .foregroundStyle(AppSurface.textMuted)
                    Text(status!.label)
                        .font(.system(size: 10))
                        .foregroundStyle(color)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(hasStatus ? color.opacity(0.10) : AppSurface.card)
            )
            .overlay(
                Capsule().stroke(hasStatus ? color.opacity(0.55) : AppSurface.border, lineWidth: 1)
            )
        }
        .accessibilityLabel("\(segment.label)\(hasStatus ? ", \(status!.label)" : "")")
    }

    private func chipText(segment: VenousSegmentCatalog.Segment) -> String {
        // Diferencia segmentos do mesmo vessel por região (ex: VSM coxa prox / coxa média / perna)
        if let region = segment.region, segment.shortLabel == "VSM" {
            switch region {
            case .coxaProximal: return "VSM cx-prox"
            case .coxaMedia: return "VSM cx-méd"
            case .coxaDistal: return "VSM cx-dist"
            case .pernaMedia: return "VSM perna"
            default: return "VSM"
            }
        }
        if segment.shortLabel == "VSP" {
            if segment.id == "vsp-proximal" { return "VSP prox" }
            if segment.id == "vsp-distal" { return "VSP dist" }
        }
        if segment.shortLabel == "Pop" {
            return segment.id == "pop-anterior" ? "Pop (ant)" : "Pop (post)"
        }
        if segment.shortLabel == "Perf" {
            return segment.id == "perfurante-coxa" ? "Perf coxa" : "Perf perna"
        }
        return segment.shortLabel
    }

    // MARK: - State helpers

    private func findingFor(_ segment: VenousSegmentCatalog.Segment) -> VenousFinding? {
        findings.first { $0.segmentId == segment.id && $0.side == side }
    }

    private func applyStatus(_ status: VenousFinding.Status, to segment: VenousSegmentCatalog.Segment) {
        Haptics.success()
        if let idx = findings.firstIndex(where: { $0.segmentId == segment.id && $0.side == side }) {
            findings[idx].status = status
            findings[idx].source = .manual
        } else {
            let new = VenousFinding(
                side: side,
                segmentId: segment.id,
                vessel: segment.vessel,
                view: segment.view,
                region: segment.region,
                status: status,
                source: .manual
            )
            findings.append(new)
        }
    }

    private func removeFinding(for segment: VenousSegmentCatalog.Segment) {
        Haptics.tap()
        findings.removeAll { $0.segmentId == segment.id && $0.side == side }
    }
}
