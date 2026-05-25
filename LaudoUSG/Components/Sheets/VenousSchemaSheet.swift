import SwiftUI

/// Sheet do esquema de cartografia venosa (Doppler MMII).
/// Step 4 — display + editor + parser regex PT do laudo.
/// Próximo: exporter PDF (1 página por perna) + gate pós-laudo (Step 5).
@MainActor
struct VenousSchemaSheet: View {
    var reportText: String? = nil
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var side: VenousFinding.Side = .direita
    @State private var allFindings: [VenousFinding] = []
    @State private var didAutoImport: Bool = false
    @State private var lastImportCount: Int? = nil

    private var currentSideFindings: [VenousFinding] {
        allFindings.filter { $0.side == side }
    }

    private var hasReport: Bool {
        !(reportText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Cartografia venosa bilateral com 4 vistas anatômicas. Toque nos chips abaixo do esquema para marcar o status de cada segmento.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.md)

                Picker("Lado", selection: $side) {
                    Text("Membro inferior D").tag(VenousFinding.Side.direita)
                    Text("Membro inferior E").tag(VenousFinding.Side.esquerda)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)

                VenousCartographyView(side: side, findings: currentSideFindings)
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

                if let count = lastImportCount {
                    importToast(count: count)
                        .padding(.horizontal, Spacing.md)
                        .transition(.opacity)
                }

                if currentSideFindings.isEmpty {
                    emptyHint
                        .padding(.horizontal, Spacing.md)
                }

                if hasReport {
                    importButton
                        .padding(.horizontal, Spacing.md)
                }

                VenousSchemaEditor(side: side, findings: $allFindings)
                    .padding(.horizontal, Spacing.md)

                legend
                    .padding(.horizontal, Spacing.md)

                Text("Próximo passo: exportar PDF (1 página por perna).")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Cartografia venosa")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didAutoImport, hasReport, let text = reportText else { return }
            didAutoImport = true
            let parsed = VenousFindingsParser.parse(text)
            if !parsed.isEmpty {
                allFindings = parsed
                lastImportCount = parsed.count
                // Vai pra perna que tem mais findings se a default (direita) não tiver
                if parsed.filter({ $0.side == .direita }).isEmpty,
                   !parsed.filter({ $0.side == .esquerda }).isEmpty {
                    side = .esquerda
                }
                scheduleToastHide()
            }
        }
    }

    private var importButton: some View {
        Button {
            Haptics.tap()
            reimport()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                Text("Importar achados do laudo")
                    .font(TextStyle.bodyMedium)
            }
            .foregroundStyle(BrandColor.primaryDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(BrandColor.primary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(BrandColor.primary.opacity(0.4), lineWidth: 1)
            )
        }
        .accessibilityLabel("Importar achados do texto do laudo")
    }

    private func reimport() {
        guard let text = reportText else { return }
        let parsed = VenousFindingsParser.parse(text)
        let manuals = allFindings.filter { $0.source == .manual }
        withAnimation(.snappy) {
            allFindings = parsed + manuals
            lastImportCount = parsed.count
        }
        scheduleToastHide()
    }

    private func scheduleToastHide() {
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            await MainActor.run {
                withAnimation(.snappy) { lastImportCount = nil }
            }
        }
    }

    private func importToast(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: count > 0 ? "checkmark.circle.fill" : "info.circle")
                .foregroundStyle(count > 0 ? SemanticColor.successText : AppSurface.textMuted)
            Text(count > 0
                 ? "\(count) segmento\(count == 1 ? "" : "s") importado\(count == 1 ? "" : "s") do laudo"
                 : "Nenhum achado identificado no texto")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(AppSurface.muted)
        )
    }

    private var emptyHint: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "hand.tap")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppSurface.textMuted)
            Text(hasReport
                 ? "Esta perna ainda não tem achados marcados. Toque \"Importar achados do laudo\" ou use os chips abaixo."
                 : "Esta perna ainda não tem achados marcados. Toque nos chips abaixo para começar.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(AppSurface.muted)
        )
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
}
