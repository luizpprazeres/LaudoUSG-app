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

/// Render do esquema: a folha A4 (retrato) com as três vistas e a legenda M1, M2… — PNG (exibir na Sala) e PDF (baixar/imprimir).
@MainActor
enum MyomaSchemaExporter {
    static func items(_ findings: [MyomaFinding]) -> [MyomaSheetItem] { findings.map(MyomaSheetItem.init) }

    static func renderPNG(_ findings: [MyomaFinding]) -> Data? {
        MyomaSheetRenderer.render(items(findings), scale: 0.5)?.pngData()   // 1240 × 1754 px
    }

    static func renderPDF(_ findings: [MyomaFinding]) -> Data? {
        MyomaSheetRenderer.renderPDF(items(findings))
    }
}

/// Renderiza + envia o esquema de miomas pra Sala (usa o uploader genérico).
@MainActor
enum MyomaSchemaSender {
    static func send(findings: [MyomaFinding], examLabel: String, reportId: String?) async -> Bool {
        let contract = MyomaSchemeContract(editorFindings: findings)
        guard !contract.findings.isEmpty, contract.activationIssues.isEmpty else { return false }
        guard let png = MyomaSchemaExporter.renderPNG(findings) else { return false }
        let pdf = MyomaSchemaExporter.renderPDF(findings)
        return await SalaSchemaUploader.upload(
            png: png, pdf: pdf, examType: "MIOMAS", examLabel: examLabel,
            reportId: reportId, myomaContract: contract
        )
    }
}
