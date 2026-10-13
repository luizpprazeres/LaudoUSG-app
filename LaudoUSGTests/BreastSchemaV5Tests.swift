import XCTest
import SwiftUI
@testable import LaudoUSG

/// Esquema mamário no cartograma v5 (paridade com a web: breastGeometry.ts / BreastSchema.tsx).
@MainActor
final class BreastSchemaV5Tests: XCTestCase {
    func testHourAndDistanceRoundTrip() {
        for side in BreastFinding.Side.allCases {
            for hora in 1...12 {
                for dist in [1.0, 3.0, 5.5] {
                    let f = BreastFinding(side: side, type: .solid, hora: hora, distMamilo: dist)
                    let p = BreastSchemaView.point(for: f)
                    let back = BreastSchemaView.position(side: side, x: p.x, y: p.y)
                    XCTAssertEqual(back.hora, hora, "\(side) \(hora)h")
                    XCTAssertEqual(back.dist, dist, accuracy: 0.11, "\(side) \(hora)h \(dist)cm")
                }
            }
        }
    }

    func testTwelveIsUpAndThreeIsViewerRight() {
        let up = BreastSchemaView.point(for: BreastFinding(side: .direita, type: .solid, hora: 12, distMamilo: 3))
        let right = BreastSchemaView.point(for: BreastFinding(side: .direita, type: .solid, hora: 3, distMamilo: 3))
        XCTAssertLessThan(up.y, BreastSchemaView.cy)
        XCTAssertGreaterThan(right.x, BreastSchemaView.rightCx)
    }

    func testDragOutsideIsBoundedToTheBreast() {
        let p = BreastSchemaView.position(side: .esquerda, x: 1608, y: 0)
        XCTAssertLessThanOrEqual(p.dist, 6)
        XCTAssertLessThan(hypot((p.point.x - BreastSchemaView.leftCx) / BreastSchemaView.rx, (p.point.y - BreastSchemaView.cy) / BreastSchemaView.ry), 0.95)
    }

    func testSameSpotFindingsAreSpread() {
        let a = BreastFinding(side: .direita, type: .solid, hora: 10, distMamilo: 3)
        let b = BreastFinding(side: .direita, type: .cyst, hora: 10, distMamilo: 3)
        let pos = BreastSchemaView.positions(for: [a, b])
        XCTAssertNotEqual(pos[a.id], pos[b.id])
    }

    func testQuadrantFallbackWhenNoHour() {
        let f = BreastFinding(side: .esquerda, type: .solid, quadrant: .qsl, distMamilo: 3)
        let back = BreastSchemaView.position(side: .esquerda, x: BreastSchemaView.point(for: f).x, y: BreastSchemaView.point(for: f).y)
        XCTAssertEqual(back.hora, 2)
    }

    func testParserRecognizesSpiculated() {
        let text = "Mama esquerda: nódulo sólido hipoecoico de margens espiculadas às 2 horas, a 4 cm do mamilo, medindo 1,5 x 1,0 cm."
        XCTAssertEqual(BreastFindingsParser.parse(text).first?.type, .solidSpiculated)
    }

    func testExportsPNGAndPDFWithTheArt() throws {
        let fs = [BreastFinding(side: .direita, type: .solid, hora: 10, sizeMax: 12, distMamilo: 3),
                  BreastFinding(side: .esquerda, type: .cyst, hora: 2, sizeMax: 8, distMamilo: 2)]
        let png = try XCTUnwrap(BreastSchemaExporter.exportPNG(findings: fs))
        let pdf = try XCTUnwrap(BreastSchemaExporter.exportPDF(findings: fs))
        XCTAssertGreaterThan((try Data(contentsOf: png)).count, 20_000)
        XCTAssertGreaterThan((try Data(contentsOf: pdf)).count, 5_000)
        let dest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mama-export-teste.png")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: png, to: dest)
        print("EXPORT_PNG=\(dest.path)")
    }

    func testArtAssetIsBundled() {
        XCTAssertNotNil(UIImage(named: "BreastFrontalV5"))
    }
}
