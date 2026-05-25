import SwiftUI

/// Sheet do esquema de cartografia venosa (Doppler MMII).
/// Step 1 — apenas display, com toggle entre exemplo e vazio + switcher de perna.
/// Editor (Step 2), parser (Step 4) e exporter (Step 5) virão nas próximas iterações.
@MainActor
struct VenousSchemaSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var side: VenousFinding.Side = .direita
    @State private var findings: [VenousFinding] = VenousSchemaSheet.sampleFindings(.direita)
    @State private var showingSamples: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Cartografia venosa bilateral com 4 vistas anatômicas (anterior · medial · posterior · lateral). Step 1 (preview): apenas visualização — sem editor ainda.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.md)

                Picker("Lado", selection: $side) {
                    Text("MID").tag(VenousFinding.Side.direita)
                    Text("MIE").tag(VenousFinding.Side.esquerda)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .onChange(of: side) { _, newSide in
                    findings = showingSamples ? Self.sampleFindings(newSide) : []
                }

                VenousCartographyView(side: side, findings: findings)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .stroke(AppSurface.border, lineWidth: 1)
                    )
                    .padding(.horizontal, Spacing.md)

                legend
                    .padding(.horizontal, Spacing.md)

                Toggle(isOn: $showingSamples) {
                    Text(showingSamples ? "Mostrando achados de exemplo" : "Cartografia vazia")
                        .font(TextStyle.bodyMedium)
                        .foregroundStyle(AppSurface.textPrimary)
                }
                .tint(BrandColor.primary)
                .padding(.horizontal, Spacing.md)
                .onChange(of: showingSamples) { _, value in
                    findings = value ? Self.sampleFindings(side) : []
                }

                Text("Próximos passos: editor (tap no segmento → escolher status), parser do laudo, exportar PDF (1 página por perna).")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Cartografia venosa")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Legenda de status").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary).textCase(.uppercase)
            FlowLayout(spacing: 10) {
                ForEach(VenousFinding.Status.allCases) { status in
                    HStack(spacing: 6) {
                        Capsule()
                            .stroke(
                                Color(hex: status.colorHex),
                                style: StrokeStyle(lineWidth: status.lineWidth, lineCap: .round, dash: status.dash)
                            )
                            .frame(width: 22, height: 8)
                        Text(status.label)
                            .font(.system(size: 10))
                            .foregroundStyle(AppSurface.textSecondary)
                    }
                }
            }
        }
    }

    static func sampleFindings(_ side: VenousFinding.Side) -> [VenousFinding] {
        [
            VenousFinding(side: side, segmentId: "vfc", vessel: .vfc, view: .anterior, status: .suficiente),
            VenousFinding(side: side, segmentId: "vf",  vessel: .vf,  view: .anterior, status: .suficiente),
            VenousFinding(side: side, segmentId: "vsm-coxa-media", vessel: .vsm, view: .medial, status: .refluxo, refluxSeconds: 1.2),
            VenousFinding(side: side, segmentId: "pop-anterior", vessel: .pop, view: .anterior, status: .tromboseAguda),
            VenousFinding(side: side, segmentId: "vsp-proximal", vessel: .vsp, view: .posterior, status: .tromboseCronica),
            VenousFinding(side: side, segmentId: "vsm-perna", vessel: .vsm, view: .medial, status: .safenectomizada),
        ]
    }
}
