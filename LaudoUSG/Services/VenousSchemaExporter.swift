import SwiftUI
import UIKit

@MainActor
enum VenousSchemaExporter {
    static func renderPNG(map: MapaVenoso) -> Data? {
        try? VenousOrganicRenderer.renderPNG(map: map)
    }

    static func renderPDF(map: MapaVenoso) -> Data? {
        guard let image = try? VenousOrganicRenderer.renderImage(map: map) else { return nil }
        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let margin: CGFloat = 24
        let headerH: CGFloat = 46
        let footerH: CGFloat = 24
        let availW = pageW - margin * 2
        let availH = pageH - margin * 2 - headerH - footerH
        let aspect = image.size.width / image.size.height
        var drawW = availW
        var drawH = drawW / aspect
        if drawH > availH {
            drawH = availH
            drawW = drawH * aspect
        }
        let drawX = (pageW - drawW) / 2
        let drawY = margin + headerH

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "LaudoUSG",
            kCGPDFContextTitle as String: "Cartografia venosa MMII",
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH), format: format)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawHeader(map: map, pageW: pageW, margin: margin)
            image.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
            drawFooter(pageW: pageW, pageH: pageH, margin: margin)
        }
    }

    static func send(map: MapaVenoso, examLabel: String, reportId: String?) async -> Bool {
        guard let png = renderPNG(map: map) else { return false }
        let pdf = renderPDF(map: map)
        return await SalaSchemaUploader.upload(
            png: png,
            pdf: pdf,
            examType: "VENOSO_MMII",
            examLabel: examLabel,
            reportId: reportId
        )
    }

    private static func drawHeader(map: MapaVenoso, pageW: CGFloat, margin: CGFloat) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 0.024, green: 0.373, blue: 0.290, alpha: 1)
        ]
        "Cartografia venosa MMII".draw(at: CGPoint(x: margin, y: 26), withAttributes: titleAttrs)

        let status = map.tvpPresente ? "TVP presente" : "Sem TVP estruturada"
        let statusAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: map.tvpPresente ? UIColor(red: 0.69, green: 0.23, blue: 0.29, alpha: 1) : UIColor.darkGray
        ]
        let size = status.size(withAttributes: statusAttrs)
        status.draw(at: CGPoint(x: pageW - margin - size.width, y: 31), withAttributes: statusAttrs)
    }

    private static func drawFooter(pageW: CGFloat, pageH: CGFloat, margin: CGFloat) {
        let footer = "Esquema didático — posição aproximada. Não substitui o laudo."
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        let size = footer.size(withAttributes: attrs)
        footer.draw(at: CGPoint(x: (pageW - size.width) / 2, y: pageH - margin), withAttributes: attrs)
    }
}
