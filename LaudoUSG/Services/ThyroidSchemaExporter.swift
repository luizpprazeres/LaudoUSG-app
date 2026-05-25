import SwiftUI
import UIKit

/// Gera PDF (paisagem A4) e PNG (alta resolução) do esquema tireoidiano.
/// Espelha `BreastSchemaExporter` — mesma estrutura, paisagem A4.
/// O esquema é quadrado (480×480), então fica menor em proporção que o da mama;
/// sobra mais espaço pra lista textual à direita.
@MainActor
enum ThyroidSchemaExporter {

    /// A4 landscape em pontos PDF.
    static let pageWidth: CGFloat = 842
    static let pageHeight: CGFloat = 595
    static let margin: CGFloat = 40

    // MARK: - PDF (paisagem)

    static func exportPDF(findings: [ThyroidFinding]) -> URL? {
        // Esquema quadrado: altura limita o tamanho.
        let usableH: CGFloat = pageHeight - margin * 2 - 60  // 60 pra header
        let imgH = min(usableH, 460)
        let imgW = imgH  // 1:1
        let textColumnGap: CGFloat = 24
        let textColumnX = margin + imgW + textColumnGap
        let textColumnW = pageWidth - textColumnX - margin

        // Renderiza schema em UIImage high-DPI
        let schemaView = ZStack {
            Color.white
            ThyroidSchemaView(findings: findings)
                .frame(width: imgW, height: imgH)
        }
        .frame(width: imgW, height: imgH)

        let renderer = ImageRenderer(content: schemaView)
        renderer.scale = 3
        guard let schemaImage = renderer.uiImage else { return nil }

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfFormat = UIGraphicsPDFRendererFormat()
        pdfFormat.documentInfo = [
            kCGPDFContextCreator as String: "LaudoUSG",
            kCGPDFContextTitle as String: "Esquema tireoidiano",
            kCGPDFContextSubject as String: "Esquema didático bilateral — ultrassonografia da tireoide",
        ]
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect, format: pdfFormat)

        let data = pdfRenderer.pdfData { ctx in
            ctx.beginPage()

            drawHeader()
            let imgY: CGFloat = 92
            schemaImage.draw(in: CGRect(x: margin, y: imgY, width: imgW, height: imgH))
            drawFindingsList(
                findings,
                x: textColumnX,
                y: imgY,
                width: textColumnW,
                height: imgH
            )
            drawFooter()
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("esquema-tireoide-\(Int(Date().timeIntervalSince1970)).pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - PNG (alta resolução)

    static func exportPNG(findings: [ThyroidFinding]) -> URL? {
        let size: CGFloat = 1024
        let view = ZStack {
            Color.white
            ThyroidSchemaView(findings: findings)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.uiImage, let png = image.pngData() else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("esquema-tireoide-\(Int(Date().timeIntervalSince1970)).png")
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
        "Esquema tireoidiano".draw(at: CGPoint(x: margin, y: 32), withAttributes: titleAttr)

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
        _ findings: [ThyroidFinding],
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

        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5),
            .foregroundColor: UIColor.black
        ]

        var lineY = y + 18
        let sorted = findings.sorted { lhs, rhs in
            if lhs.side != rhs.side { return Self.sideOrder(lhs.side) < Self.sideOrder(rhs.side) }
            return Self.tercioOrder(lhs.tercio) < Self.tercioOrder(rhs.tercio)
        }

        for (idx, f) in sorted.enumerated() {
            let prefix = "\(idx + 1). "
            let sideLabel = f.side.shortLabel
            var parts: [String] = ["\(sideLabel) — \(f.type.label)"]
            if let t = f.tercio { parts.append("terço \(t.shortLabel)") }
            if let s = f.sizeMax { parts.append(formatSize(s)) }
            if let e = f.echogenicity { parts.append(e.label.lowercased()) }
            if let m = f.margins { parts.append("margens \(m.label.lowercased())") }
            if let tr = f.tiRads { parts.append("TI-RADS \(tr)") }
            let body = parts.joined(separator: " · ")

            prefix.draw(at: CGPoint(x: x, y: lineY), withAttributes: labelAttr)
            let prefixWidth = prefix.size(withAttributes: labelAttr).width
            let bodyRect = CGRect(x: x + prefixWidth, y: lineY, width: width - prefixWidth, height: 36)
            body.draw(in: bodyRect, withAttributes: bodyAttr)

            let bodyWidth = body.size(withAttributes: bodyAttr).width
            lineY += bodyWidth > (width - prefixWidth) ? 26 : 14
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

    private static func sideOrder(_ side: ThyroidFinding.Side) -> Int {
        switch side {
        case .direito: return 0
        case .istmo: return 1
        case .esquerdo: return 2
        }
    }

    private static func tercioOrder(_ tercio: ThyroidFinding.Tercio?) -> Int {
        switch tercio {
        case .superior: return 0
        case .medio: return 1
        case .inferior: return 2
        case .none: return 3
        }
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
