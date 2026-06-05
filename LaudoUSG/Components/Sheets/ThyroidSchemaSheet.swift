import SwiftUI

/// Sheet do esquema tireoidiano.
/// Step 4 — display + editor manual + drag + parser do texto do laudo.
/// Próximo: exporter PDF landscape + gate "só após laudo gerado" (Step 5).
@MainActor
struct ThyroidSchemaSheet: View {
    var reportText: String? = nil
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var findings: [ThyroidFinding] = []
    @State private var didAutoImport: Bool = false
    @State private var lastImportCount: Int? = nil
    @State private var shareURL: URL? = nil
    @State private var isExporting: Bool = false
    @State private var sendingSala: Bool = false
    @State private var salaResult: String? = nil

    private var hasReport: Bool {
        !(reportText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Marque os nódulos por lobo, terço e tipo. Arraste qualquer marcador para reposicionar entre os buckets.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.md)

                ThyroidSchemaView(findings: findings) { id, side, tercio in
                    moveFinding(id: id, side: side, tercio: tercio)
                }
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

                if findings.isEmpty {
                    emptyHint
                        .padding(.horizontal, Spacing.md)
                } else {
                    legend
                        .padding(.horizontal, Spacing.md)
                }

                if hasReport {
                    importButton
                        .padding(.horizontal, Spacing.md)
                }

                ThyroidSchemaEditor(findings: $findings)
                    .padding(.horizontal, Spacing.md)

                exportBar
                    .padding(.horizontal, Spacing.md)

                Text("Esquema didático — posição aproximada. Não substitui o laudo.")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Esquema tireoidiano")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didAutoImport, hasReport, let text = reportText else { return }
            didAutoImport = true
            let parsed = ThyroidFindingsParser.parse(text)
            if !parsed.isEmpty {
                findings = parsed
                lastImportCount = parsed.count
                scheduleToastHide()
            }
        }
        .sheet(item: Binding(
            get: { shareURL.map(ThyroidShareItem.init) },
            set: { shareURL = $0?.url }
        )) { item in
            ThyroidShareSheet(items: [item.url])
        }
    }

    // MARK: - Export

    private var exportBar: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Exportar").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary).textCase(.uppercase)
            HStack(spacing: Spacing.sm) {
                exportButton(title: "PDF (paisagem)", icon: "doc.richtext") {
                    Task { await export(format: .pdf) }
                }
                exportButton(title: "Imagem PNG", icon: "photo") {
                    Task { await export(format: .png) }
                }
            }
            .disabled(isExporting)
            .overlay {
                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm).fill(AppSurface.card)
                        )
                }
            }

            Button {
                Haptics.tap()
                Task { await sendToSala() }
            } label: {
                HStack(spacing: 6) {
                    if sendingSala { ProgressView().controlSize(.small).tint(.white) }
                    else { Image(systemName: "paperplane.fill").font(.system(size: 13, weight: .semibold)) }
                    Text(sendingSala ? "Enviando…" : "Enviar p/ Sala").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(BrandColor.primary))
            }
            .disabled(sendingSala || findings.isEmpty)
            if let salaResult { Text(salaResult).font(.caption2).foregroundStyle(AppSurface.textSecondary) }
        }
    }

    private func sendToSala() async {
        sendingSala = true; salaResult = nil
        defer { sendingSala = false }
        let pngURL = ThyroidSchemaExporter.exportPNG(findings: findings)
        let pdfURL = ThyroidSchemaExporter.exportPDF(findings: findings)
        let ok = await SalaSchemaUploader.upload(
            pngURL: pngURL, pdfURL: pdfURL, examType: "TIREOIDE", examLabel: "Tireoide — esquema", reportId: nil
        )
        if ok { Haptics.success() }
        salaResult = ok ? "Enviado pra Sala ✓" : "Falha ao enviar. Tente de novo."
    }

    private func exportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
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
    }

    private enum ExportFormat { case pdf, png }

    private func export(format: ExportFormat) async {
        isExporting = true
        defer { isExporting = false }
        let url: URL? = await Task.detached { @MainActor in
            switch format {
            case .pdf: return ThyroidSchemaExporter.exportPDF(findings: findings)
            case .png: return ThyroidSchemaExporter.exportPNG(findings: findings)
            }
        }.value
        guard let url else { return }
        Haptics.success()
        shareURL = url
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
        let parsed = ThyroidFindingsParser.parse(text)
        let manuals = findings.filter { $0.source == .manual }
        withAnimation(.snappy) {
            findings = parsed + manuals
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
                 ? "\(count) achado\(count == 1 ? "" : "s") importado\(count == 1 ? "" : "s") do laudo"
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
                 ? "Use os botões abaixo para adicionar manualmente, ou toque em \"Importar achados do laudo\"."
                 : "Use os botões abaixo para adicionar achados ao esquema.")
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
            Text("Legenda").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary).textCase(.uppercase)
            HStack(spacing: Spacing.md) {
                legendItem(symbol: { Circle().fill(Color(hex: "111827")).frame(width: 12, height: 12) }, label: "Sólido")
                legendItem(symbol: {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color(hex: "111827"), lineWidth: 1.5))
                        .frame(width: 12, height: 12)
                }, label: "Cisto")
                legendItem(symbol: {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color(hex: "111827"), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])))
                        .frame(width: 12, height: 12)
                }, label: "Esponjoso")
            }
            HStack(spacing: Spacing.md) {
                legendItem(symbol: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "111827"))
                            .opacity(0.85)
                            .mask(
                                HStack(spacing: 0) {
                                    Rectangle()
                                    Color.clear
                                }
                            )
                        Circle()
                            .stroke(Color(hex: "111827"), lineWidth: 1.5)
                    }
                    .frame(width: 12, height: 12)
                }, label: "Misto")
                legendItem(symbol: {
                    LosangoSampleShape()
                        .fill(Color(hex: "111827"))
                        .frame(width: 12, height: 12)
                }, label: "Calcificação")
            }
            if findings.contains(where: { $0.approximate }) {
                Text("Marcadores semi-transparentes indicam posição aproximada (sem terço identificado no laudo).")
                    .font(.system(size: 10))
                    .foregroundStyle(AppSurface.textMuted)
                    .italic()
                    .padding(.top, 4)
            }
        }
    }

    private func legendItem<S: View>(@ViewBuilder symbol: () -> S, label: String) -> some View {
        HStack(spacing: 6) {
            symbol()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private func moveFinding(id: String, side: ThyroidFinding.Side, tercio: ThyroidFinding.Tercio?) {
        guard let idx = findings.firstIndex(where: { $0.id == id }) else { return }
        findings[idx].side = side
        findings[idx].tercio = tercio
        findings[idx].approximate = false
        findings[idx].source = .manual
    }
}

private struct ThyroidShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ThyroidShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LosangoSampleShape: Shape {
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
