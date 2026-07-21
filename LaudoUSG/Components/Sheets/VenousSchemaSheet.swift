import SwiftUI

/// Sheet do esquema de cartografia venosa (Doppler MMII).
/// Step 4 — display + editor + parser regex PT do laudo.
/// Próximo: exporter PDF (1 página por perna) + gate pós-laudo (Step 5).
@MainActor
struct VenousSchemaSheet: View {
    var reportText: String? = nil
    var scheme: VenousSchemePayload? = nil
    var reportId: String? = nil
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var renderedImage: UIImage?
    @State private var renderError: String?
    @State private var shareURL: URL?
    @State private var isExporting = false
    @State private var sendingSala = false
    @State private var salaResult: String?

    private var hasReport: Bool {
        !(reportText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var map: MapaVenoso? { scheme?.map }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Cartografia venosa orgânica gerada a partir do mapa estruturado do backend.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.md)

                organicPreview
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

                if let scheme {
                    schemeSummary(scheme)
                        .padding(.horizontal, Spacing.md)
                }

                if map == nil {
                    emptyHint
                        .padding(.horizontal, Spacing.md)
                }

                if let map {
                    lesionsList(map)
                        .padding(.horizontal, Spacing.md)
                }

                exportBar
                    .padding(.horizontal, Spacing.md)

                legend
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
        .navigationTitle("Cartografia venosa")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scheme?.assetVersion) {
            await render()
        }
        .sheet(item: Binding(
            get: { shareURL.map(VenousShareItem.init) },
            set: { shareURL = $0?.url }
        )) { item in
            VenousShareSheet(items: [item.url])
        }
    }

    private var organicPreview: some View {
        Group {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .background(Color.white)
            } else if let renderError {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SemanticColor.warningText)
                    Text(renderError)
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 320)
            }
        }
    }

    private var emptyHint: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppSurface.textMuted)
            Text(hasReport
                 ? "Nenhum mapa venoso estruturado chegou do backend para este laudo."
                 : "Gere um laudo venoso para receber o mapa estruturado do backend.")
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
                legendItem("Refluxo / varicosidade", color: Color(red: 209/255, green: 132/255, blue: 26/255))
                legendItem("Trombose oclusiva", color: Color(red: 176/255, green: 58/255, blue: 74/255))
                legendItem("Trombose parcial", color: Color(red: 196/255, green: 96/255, blue: 110/255))
                legendItem("Recanalizada", color: Color(red: 176/255, green: 58/255, blue: 74/255))
            }
        }
    }

    private var exportBar: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Exportar").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary).textCase(.uppercase)
            HStack(spacing: Spacing.sm) {
                exportButton(title: "PDF", icon: "doc.richtext") {
                    Task { await export(format: .pdf) }
                }
                exportButton(title: "PNG", icon: "photo") {
                    Task { await export(format: .png) }
                }
            }
            .disabled(map == nil || isExporting)

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
            .disabled(sendingSala || map == nil)
            if let salaResult { Text(salaResult).font(.caption2).foregroundStyle(AppSurface.textSecondary) }
        }
    }

    private func schemeSummary(_ scheme: VenousSchemePayload) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: VenousSchemeAsset.isSupported(scheme.assetVersion) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(VenousSchemeAsset.isSupported(scheme.assetVersion) ? SemanticColor.successText : SemanticColor.warningText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mapa estruturado recebido")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textPrimary)
                Text("asset_version: \(scheme.assetVersion)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppSurface.textMuted)
            }
            Spacer()
        }
        .padding(Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(AppSurface.muted))
    }

    private func lesionsList(_ map: MapaVenoso) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Achados do mapa").font(TextStyle.captionMedium).foregroundStyle(AppSurface.textSecondary).textCase(.uppercase)
            if map.lesoes.isEmpty && map.perfurantes.isEmpty {
                Text(map.tvpPresente ? "TVP presente no mapa estruturado." : "Sem lesões listadas no payload.")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textSecondary)
            } else {
                ForEach(map.lesoes.prefix(8)) { lesion in
                    HStack(spacing: 6) {
                        Circle().fill(color(for: lesion.estado)).frame(width: 8, height: 8)
                        Text("\(lesion.lado.title): \(lesion.label)")
                            .font(TextStyle.caption)
                            .foregroundStyle(AppSurface.textSecondary)
                    }
                }
            }
        }
    }

    private func legendItem(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 22, height: 8)
            Text(text).font(.system(size: 10)).foregroundStyle(AppSurface.textSecondary)
        }
    }

    private func exportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(BrandColor.primaryDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(BrandColor.primary.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(BrandColor.primary.opacity(0.4), lineWidth: 1))
        }
    }

    private enum ExportFormat { case pdf, png }

    private func render() async {
        guard let map else {
            renderedImage = nil
            renderError = nil
            return
        }
        do {
            renderedImage = try VenousOrganicRenderer.renderImage(
                map: map,
                assetVersion: scheme?.assetVersion ?? VenousSchemeAsset.anteriorVersion
            )
            renderError = nil
        } catch {
            renderedImage = nil
            renderError = "Não foi possível renderizar a cartografia venosa."
        }
    }

    private func export(format: ExportFormat) async {
        guard let map else { return }
        isExporting = true
        defer { isExporting = false }
        let url: URL? = await Task.detached { @MainActor in
            switch format {
            case .pdf:
                guard let data = VenousSchemaExporter.renderPDF(
                    map: map,
                    assetVersion: scheme?.assetVersion ?? VenousSchemeAsset.anteriorVersion
                ) else { return nil }
                return Self.writeTemp(data: data, ext: "pdf")
            case .png:
                guard let data = VenousSchemaExporter.renderPNG(
                    map: map,
                    assetVersion: scheme?.assetVersion ?? VenousSchemeAsset.anteriorVersion
                ) else { return nil }
                return Self.writeTemp(data: data, ext: "png")
            }
        }.value
        guard let url else { return }
        Haptics.success()
        shareURL = url
    }

    private func sendToSala() async {
        guard let map else { return }
        sendingSala = true; salaResult = nil
        defer { sendingSala = false }
        let ok = await VenousSchemaExporter.send(
            map: map,
            assetVersion: scheme?.assetVersion ?? VenousSchemeAsset.anteriorVersion,
            examLabel: "Doppler venoso MMII — cartografia",
            reportId: reportId
        )
        if ok { Haptics.success() }
        salaResult = ok ? "Enviado pra Sala ✓" : "Falha ao enviar. Tente de novo."
    }

    private func color(for state: EstadoSegmento) -> Color {
        switch state {
        case .normal: return Color(hex: "2563EB")
        case .refluxo, .varicosidade: return Color(red: 209/255, green: 132/255, blue: 26/255)
        case .tromboseOclusiva, .recanalizada: return Color(red: 176/255, green: 58/255, blue: 74/255)
        case .tromboseParcial: return Color(red: 196/255, green: 96/255, blue: 110/255)
        }
    }

    @MainActor
    private static func writeTemp(data: Data, ext: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cartografia-venosa-\(Int(Date().timeIntervalSince1970)).\(ext)")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

private struct VenousShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct VenousShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
