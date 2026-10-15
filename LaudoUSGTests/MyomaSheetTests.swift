import XCTest
import UIKit
@testable import LaudoUSG

/// Folha A4 de miomas (M1, M2…) e leitura do laudo numerado que o writer da pelve passou a escrever.
@MainActor
final class MyomaSheetTests: XCTestCase {
    /// Saída real do writer (bancada 15/10, ditado sintético).
    private let laudoTres = """
    OS SEGUINTES ASPECTOS FORAM OBSERVADOS:
    Útero em retroversão, medindo 10,4 x 5,6 x 7,0 cm.
    Endométrio medindo 1,0 cm de espessura.
    Miométrio apresentando três imagens hipoecoicas e heterogêneas, com margens regulares, assim descritas:
    (M1) - medindo 3,1 x 2,8 x 2,7 cm, situada na parede posterior.
    (M2) - medindo 1,9 x 1,7 x 1,6 cm, situada na parede anterior.
    (M3) - medindo 1,4 x 1,2 x 1,1 cm, situada na parede lateral esquerda, com calcificações.
    Ovário direito apresentando imagens anecoicas.

    CONCLUSÃO:
    1) Útero de volume aumentado (213 cm³).
    2) Miométrio apresentando três imagens sólidas, que têm como diagnóstico mais provável nódulos miomatosos: M1 - intramural (categoria FIGO 4), M2 - submucoso com menos de 50% intramural (categoria FIGO 1) e M3 - nódulo miomatoso.
    3) Ovários ecograficamente normais, ambos contendo folículos.

    FIGO: Federação Internacional de Ginecologia e Obstetrícia.
    """

    func testNumberedReportMapsBodyAndConclusionByNumber() {
        let f = MyomaFindingsParser.parse(laudoTres)
        XCTAssertEqual(f.count, 3)
        XCTAssertEqual(f.map(\.figo), [4, 1, nil])
        XCTAssertEqual(f.map(\.localizacao), [.posterior, .anterior, .lateralEsquerda])
        XCTAssertEqual(f[0].dimsMm, [31, 28, 27])
        XCTAssertEqual(f[0].sizeMaxMm, 31)
        XCTAssertEqual(f[2].ecotextura, .calcificada)
    }

    func testNumberedReportWithRegionFundicaAndFigo5() {
        let laudo = """
        Miométrio apresentando duas imagens hipoecoicas e heterogêneas, com margens regulares, assim descritas:
        (M1) - medindo 2,6 x 2,4 x 2,2 cm, situada na parede lateral direita.
        (M2) - medindo 4,2 x 3,8 x 3,5 cm, situada em região fúndica.

        CONCLUSÃO:
        3) Miométrio apresentando duas imagens sólidas, que têm como diagnóstico mais provável nódulos miomatosos: M1 - subseroso com mais de 50% intramural (categoria FIGO 5), M2 - intramural (categoria FIGO 4).
        """
        let f = MyomaFindingsParser.parse(laudo)
        XCTAssertEqual(f.map(\.figo), [5, 4])
        XCTAssertEqual(f.map(\.localizacao), [.lateralDireita, .fundo])
        XCTAssertEqual(f[1].dimsMm, [42, 38, 35])
    }

    func testOldFormatStillParses() {
        let laudo = "Miométrio apresentando imagem hipoecoica e heterogênea, com margens regulares, medindo 2,0 x 1,8 x 1,7 cm, situada na parede anterior. CONCLUSÃO: 1) Miométrio apresentando imagem sólida, que tem como diagnóstico mais provável nódulo miomatoso intramural (categoria FIGO 4)."
        let f = MyomaFindingsParser.parse(laudo)
        XCTAssertEqual(f.count, 1)
        XCTAssertEqual(f.first?.figo, 4)
    }

    func testLegendLine() {
        let item = MyomaSheetItem(figo: 5, location: .lateralDireita, dimsMm: [26, 24, 22], calcified: true)
        let (id, figo, desc) = MyomaSheetRenderer.linhaLegenda(1, item)
        XCTAssertEqual(id, "M1")
        XCTAssertEqual(figo, "FIGO 5 · 2,6 × 2,4 × 2,2 cm")
        XCTAssertEqual(desc, "subseroso, ≥ 50% intramural, calcificado — parede lateral direita")
    }

    func testHandEditedSizeWinsOverReportAxes() {
        var f = MyomaFinding(figo: 4, sizeMaxMm: 31, localizacao: .posterior, dimsMm: [31, 28, 27])
        XCTAssertEqual(MyomaSheetItem(f).dimsMm, [31, 28, 27])
        f.sizeMaxMm = 40
        XCTAssertEqual(MyomaSheetItem(f).dimsMm, [40])
    }

    func testGeometryLoadsAndCervicalIsNotInTransversal() throws {
        let geo = try XCTUnwrap(MyomaArtGeometry.shared)
        XCTAssertEqual(Set(geo.vistas.keys), ["coronal", "longitudinal", "transversal"])
        let itens = [MyomaSheetItem(figo: 8, location: .cervical, dimsMm: [30], calcified: false),
                     MyomaSheetItem(figo: 4, location: .fundo, dimsMm: [42], calcified: false)]
        XCTAssertEqual(MyomaSheetRenderer.posicionar(.coronal, itens, geo).count, 2)
        XCTAssertEqual(MyomaSheetRenderer.posicionar(.transversal, itens, geo).map(\.n), [2])
    }

    func testIntramuralSitsInsideTheWallAndSubserousPedunculatedOutside() throws {
        let geo = try XCTUnwrap(MyomaArtGeometry.shared)
        let g = try XCTUnwrap(geo.vistas["coronal"])
        let c = CGPoint(x: g.centro[0] * g.largura, y: g.centro[1] * g.altura)
        let p = MyomaSheetRenderer.posicionar(.coronal, [
            MyomaSheetItem(figo: 4, location: .fundo, dimsMm: [20], calcified: false),
            MyomaSheetItem(figo: 7, location: .fundo, dimsMm: [20], calcified: false),
        ], geo)
        let dist = { (n: Int) -> CGFloat in let q = p.first { $0.n == n }!.centro; return hypot(q.x - c.x, q.y - c.y) }
        let serosa = try XCTUnwrap(g.cruzamentos(CGVector(dx: 0, dy: -1)).serosa)
        XCTAssertLessThan(dist(1), serosa)
        XCTAssertGreaterThan(dist(2), serosa)
    }

    func testRendersA4SheetAndPDF() throws {
        let itens = [
            MyomaSheetItem(figo: 5, location: .lateralDireita, dimsMm: [26, 24, 22], calcified: true),
            MyomaSheetItem(figo: 4, location: .fundo, dimsMm: [42, 38, 35], calcified: false),
            MyomaSheetItem(figo: 1, location: .posterior, dimsMm: [25, 22, 20], calcified: false),
            MyomaSheetItem(figo: 7, location: .lateralEsquerda, dimsMm: [60, 52, 48], calcified: false),
        ]
        let img = try XCTUnwrap(MyomaSheetRenderer.render(itens))
        XCTAssertEqual(img.size, MyomaSheetRenderer.pageSize)
        let pdf = try XCTUnwrap(MyomaSheetRenderer.renderPDF(itens))
        XCTAssertGreaterThan(pdf.count, 50_000)
        // cópia para conferência visual fora do teste
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("myoma-sheet-test.png")
        try img.pngData()?.write(to: out)
        print("FOLHA_MIOMAS: \(out.path)")
    }
}
