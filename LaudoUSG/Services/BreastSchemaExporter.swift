import SwiftUI
import UIKit

/// Gera PDF (paisagem A4) e PNG (alta resolução) do esquema mamário.
/// Espelha `BreastSchemaExporter.tsx` da web, mas em landscape (640×310 cabe muito
/// melhor em A4 deitado: 842×595 pt) pra esquema ficar maior e mais legível.
@MainActor
enum BreastSchemaExporter {

    /// A4 landscape em pontos PDF.
    static let pageWidth: CGFloat = 842
    static let pageHeight: CGFloat = 595
    static let margin: CGFloat = 40

    // MARK: - PDF (paisagem)

    static func exportPDF(findings: [BreastFinding]) -> URL? {
        let logicalAspect = BreastSchemaView.logicalWidth / BreastSchemaView.logicalHeight

        // Esquema ocupa esquerda; lista textual à direita (largura 200 pt).
        let textColumnW: CGFloat = 200
        let textColumnGap: CGFloat = 20
        let imgW: CGFloat = pageWidth - margin * 2 - textColumnW - textColumnGap
        let imgH: CGFloat = imgW / logicalAspect

        // Renderiza schema em UIImage (high-DPI).
        let schemaView = ZStack {
            Color.white
            BreastSchemaView(findings: findings)
                .frame(width: imgW, height: imgH)
        }
        .frame(width: imgW, height: imgH)

        let renderer = ImageRenderer(content: schemaView)
        renderer.scale = 3
        guard let schemaImage = renderer.uiImage else { return nil }

        // Gera PDF.
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfFormat = UIGraphicsPDFRendererFormat()
        pdfFormat.documentInfo = [
            kCGPDFContextCreator as String: "LaudoUSG",
            kCGPDFContextTitle as String: "Esquema mamário",
            kCGPDFContextSubject as String: "Esquema didático bilateral — ultrassonografia das mamas",
        ]
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect, format: pdfFormat)

        let data = pdfRenderer.pdfData { ctx in
            ctx.beginPage()

            drawHeader()
            let imgY: CGFloat = 92
            schemaImage.draw(in: CGRect(x: margin, y: imgY, width: imgW, height: imgH))
            drawFindingsList(
                findings,
                x: margin + imgW + textColumnGap,
                y: imgY,
                width: textColumnW,
                height: imgH
            )
            drawFooter()
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("esquema-mamario-\(Int(Date().timeIntervalSince1970)).pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - PNG (alta resolução)

    static func exportPNG(findings: [BreastFinding]) -> URL? {
        let logicalAspect = BreastSchemaView.logicalWidth / BreastSchemaView.logicalHeight
        let imgW: CGFloat = 1280
        let imgH: CGFloat = imgW / logicalAspect

        let view = ZStack {
            Color.white
            BreastSchemaView(findings: findings)
                .frame(width: imgW, height: imgH)
        }
        .frame(width: imgW, height: imgH)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.uiImage, let png = image.pngData() else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("esquema-mamario-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try png.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - PDF drawing helpers

    private static func drawHeader() {
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 0.024, green: 0.373, blue: 0.290, alpha: 1) // emerald-800
        ]
        "Esquema mamário".draw(at: CGPoint(x: margin, y: 32), withAttributes: titleAttr)

        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "pt_BR")
        timeFmt.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        let timestamp = "Gerado em \(timeFmt.string(from: Date())) por LaudoUSG"
        let tsAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        timestamp.draw(at: CGPoint(x: margin, y: 58), withAttributes: tsAttr)
    }

    private static func drawFindingsList(
        _ findings: [BreastFinding],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) {
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        "ACHADOS".draw(at: CGPoint(x: x, y: y), withAttributes: headerAttr)

        guard !findings.isEmpty else {
            let emptyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            "(Nenhum achado marcado)".draw(at: CGPoint(x: x, y: y + 18), withAttributes: emptyAttr)
            return
        }

        let itemAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5),
            .foregroundColor: UIColor.black
        ]
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: UIColor.black
        ]

        var lineY = y + 18
        let sorted = findings.sorted { lhs, rhs in
            if lhs.side != rhs.side { return lhs.side == .direita }
            return (lhs.hora ?? 12) < (rhs.hora ?? 12)
        }

        for (idx, f) in sorted.enumerated() {
            let prefix = "\(idx + 1). "
            let sideLabel = f.side == .direita ? "MD" : "ME"
            var parts: [String] = ["\(sideLabel) — \(f.type.label)"]
            if let h = f.hora { parts.append("\(h)h") }
            if let s = f.sizeMax { parts.append(formatSize(s)) }
            if let d = f.distMamilo {
                let dFmt = String(format: "%.1f", d).replacingOccurrences(of: ".", with: ",")
                parts.append("\(dFmt) cm do mamilo")
            }
            let body = parts.joined(separator: " · ")

            prefix.draw(at: CGPoint(x: x, y: lineY), withAttributes: labelAttr)
            let prefixWidth = prefix.size(withAttributes: labelAttr).width
            let bodyRect = CGRect(x: x + prefixWidth, y: lineY, width: width - prefixWidth, height: 28)
            body.draw(in: bodyRect, withAttributes: itemAttr)

            // 1 ou 2 linhas conforme ocupar espaço — espaçamento fixo 24pt
            lineY += body.size(withAttributes: itemAttr).width > (width - prefixWidth) ? 24 : 14
            if lineY > y + height - 14 { break }
        }
    }

    private static func drawFooter() {
        let footer = "Esquema didático — posição aproximada. Não substitui o laudo."
        let footerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        let footerSize = footer.size(withAttributes: footerAttr)
        let footerX = (pageWidth - footerSize.width) / 2
        footer.draw(at: CGPoint(x: footerX, y: pageHeight - margin), withAttributes: footerAttr)
    }

    private static func formatSize(_ sizeMm: Double) -> String {
        if sizeMm >= 10 {
            let cm = sizeMm / 10
            let fmt = String(format: "%.1f", cm).replacingOccurrences(of: ".", with: ",")
            return "\(fmt) cm"
        }
        return "\(Int(sizeMm.rounded())) mm"
    }
}
