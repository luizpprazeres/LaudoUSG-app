import SwiftUI

/// Sheet do esquema mamário.
/// Step 4 — display + editor manual + drag + parser do texto do laudo.
/// Próximo: exporter PDF landscape + gate "só após laudo gerado" (Step 5).
@MainActor
struct BreastSchemaSheet: View {
    var reportText: String? = nil
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var findings: [BreastFinding] = []
    @State private var didAutoImport: Bool = false
    @State private var lastImportCount: Int? = nil
    @State private var shareURL: URL? = nil
    @State private var isExporting: Bool = false

    private var hasReport: Bool {
        !(reportText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Marque os achados focais por lado, tipo, hora e tamanho. Arraste qualquer marcador para reposicionar.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.md)

                BreastSchemaView(findings: findings) { id, hora, distMamilo in
                    moveFinding(id: id, hora: hora, distMamilo: distMamilo)
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

                BreastSchemaEditor(findings: $findings)
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
        .navigationTitle("Esquema mamário")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Auto-import na primeira abertura, se há texto do laudo
            guard !didAutoImport, hasReport, let text = reportText else { return }
            didAutoImport = true
            let parsed = BreastFindingsParser.parse(text)
            if !parsed.isEmpty {
                findings = parsed
                lastImportCount = parsed.count
                scheduleToastHide()
            }
        }
        .sheet(item: Binding(
            get: { shareURL.map(ShareItem.init) },
            set: { shareURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
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
        }
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
            case .pdf: return BreastSchemaExporter.exportPDF(findings: findings)
            case .png: return BreastSchemaExporter.exportPNG(findings: findings)
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
        let parsed = BreastFindingsParser.parse(text)
        // Preserva manuais; substitui parsed
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
                legendItem(symbol: { Circle().fill(Color(hex: "111827")).frame(width: 12, height: 12) }, label: "Nódulo")
                legendItem(symbol: {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color(hex: "111827"), lineWidth: 1.5))
                        .frame(width: 12, height: 12)
                }, label: "Cisto")
                legendItem(symbol: {
                    Rectangle()
                        .fill(Color(hex: "111827"))
                        .frame(width: 10, height: 10)
                        .rotationEffect(.degrees(45))
                }, label: "Calcificação")
            }
            HStack(spacing: Spacing.md) {
                legendItem(symbol: {
                    ZStack {
                        Ellipse()
                            .fill(Color.white)
                            .overlay(Ellipse().stroke(Color(hex: "111827"), lineWidth: 1.5))
                            .frame(width: 18, height: 11)
                        Ellipse()
                            .fill(Color(hex: "111827"))
                            .frame(width: 6, height: 5)
                    }
                }, label: "Linfonodo")
                legendItem(symbol: {
                    LobulatedSampleShape()
                        .fill(Color(hex: "111827"))
                        .frame(width: 14, height: 14)
                }, label: "Lobulado")
            }
            if findings.contains(where: { $0.approximate }) {
                Text("Marcadores semi-transparentes indicam posição aproximada (sem hora precisa no laudo).")
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

    private func moveFinding(id: String, hora: Int, distMamilo: Double) {
        guard let idx = findings.firstIndex(where: { $0.id == id }) else { return }
        findings[idx].hora = hora
        findings[idx].distMamilo = distMamilo
        findings[idx].quadrant = nil
        findings[idx].approximate = false
        findings[idx].source = .manual
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LobulatedSampleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        let amp = r * 0.22
        let steps = 30
        for i in 0...steps {
            let angle = (Double(i) / Double(steps)) * 2 * .pi - .pi / 2
            let radius = r + amp * sin(4 * angle)
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
