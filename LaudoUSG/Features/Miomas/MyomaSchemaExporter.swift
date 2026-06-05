import SwiftUI
import UIKit
import os

/// Layout de EXPORTAÇÃO (paisagem) — as 2 visões lado a lado + legenda FIGO,
/// preenchendo a folha. Renderizado pra PNG (exibir na Sala) e PDF (baixar).
struct MyomaExportLayout: View {
    var findings: [MyomaFinding]

    private let emerald = Color(hex: "0A6E4E")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Esquema de miomas — FIGO 0–8")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(emerald)
                Spacer()
                Text("LaudoUSG")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gray)
            }

            HStack(spacing: 20) {
                viewBox("Longitudinal") { SagittalCanvasView(findings: findings) }
                viewBox("Transversal") { AxialCanvasView(findings: findings) }
            }
            .frame(maxHeight: .infinity)

            legendStrip

            Text("Esquema didático — posição aproximada. Não substitui o laudo.")
                .font(.system(size: 10).italic())
                .foregroundColor(.gray)
        }
        .padding(28)
        .frame(width: 820, height: 560)
        .background(Color.white)
    }

    private func viewBox<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(1.0)
                .foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "FAF8F4")))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "E3DDD1"), lineWidth: 1))
    }

    private var legendStrip: some View {
        HStack(spacing: 14) {
            ForEach(FigoCategory.all, id: \.id) { c in
                HStack(spacing: 5) {
                    Text("\(c.figo)")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(c.family.color))
                    Text(c.titulo).font(.system(size: 9.5)).foregroundColor(.primary).lineLimit(1)
                }
            }
        }
    }
}

/// Render do esquema pra PNG (exibir) e PDF (paisagem A4, maximizado + margem).
@MainActor
enum MyomaSchemaExporter {
    private static let layoutSize = CGSize(width: 820, height: 560)

    static func renderPNG(_ findings: [MyomaFinding]) -> Data? {
        let r = ImageRenderer(content:
            MyomaExportLayout(findings: findings).frame(width: layoutSize.width, height: layoutSize.height)
        )
        r.scale = 2
        return r.uiImage?.pngData()
    }

    static func renderPDF(_ findings: [MyomaFinding]) -> Data? {
        let r = ImageRenderer(content:
            MyomaExportLayout(findings: findings).frame(width: layoutSize.width, height: layoutSize.height)
        )
        r.scale = 3
        guard let img = r.uiImage else { return nil }

        // A4 paisagem; imagem maximizada na folha mantendo margem de segurança.
        let pageW: CGFloat = 842, pageH: CGFloat = 595, margin: CGFloat = 22
        let availW = pageW - 2 * margin, availH = pageH - 2 * margin
        let aspect = img.size.width / img.size.height
        var dw = availW, dh = availW / aspect
        if dh > availH { dh = availH; dw = availH * aspect }
        let ox = (pageW - dw) / 2, oy = (pageH - dh) / 2

        let fmt = UIGraphicsPDFRendererFormat()
        fmt.documentInfo = [
            kCGPDFContextCreator as String: "LaudoUSG",
            kCGPDFContextTitle as String: "Esquema de miomas (FIGO)",
        ]
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH), format: fmt)
        return pdf.pdfData { ctx in
            ctx.beginPage()
            img.draw(in: CGRect(x: ox, y: oy, width: dw, height: dh))
        }
    }
}

/// Renderiza + envia o esquema pra Sala do Auxiliar (POST /api/sala/push-schema).
@MainActor
enum MyomaSchemaSender {
    private static let log = Logger(subsystem: "com.laudousg.LaudoUSG", category: "miomas")

    static func send(findings: [MyomaFinding], examLabel: String, reportId: String?) async -> Bool {
        guard let png = MyomaSchemaExporter.renderPNG(findings) else {
            log.error("falha ao renderizar PNG do esquema")
            return false
        }
        let pdf = MyomaSchemaExporter.renderPDF(findings)

        var payload: [String: Any] = [
            "examType": "MIOMAS",
            "examLabel": examLabel,
            "png": png.base64EncodedString(),
        ]
        if let pdf { payload["pdf"] = pdf.base64EncodedString() }
        if let reportId { payload["reportId"] = reportId }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        do {
            let data = try await APIClient.shared.postRawJSON("/api/sala/push-schema", body: body)
            let str = String(data: data, encoding: .utf8) ?? ""
            return str.contains("\"ok\":true") || str.contains("\"ok\": true")
        } catch {
            log.error("envio do esquema falhou: \(error.localizedDescription)")
            return false
        }
    }
}
