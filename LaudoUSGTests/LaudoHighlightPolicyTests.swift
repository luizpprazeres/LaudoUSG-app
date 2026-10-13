import XCTest
import SwiftUI
@testable import LaudoUSG

/// Estudo dos alertas de 12/10: menos amarelo sem perder o roxo nem os avisos reais.
final class LaudoHighlightPolicyTests: XCTestCase {
    private func issue(_ anchor: String?, _ msg: String, severity: String = "warning", id: String = "x") -> LaudoHighlightIssue {
        LaudoHighlightIssue(id: id, kind: .warning, anchor: anchor, message: msg, severity: severity)
    }
    private func painted(_ c: LaudoHighlightContent) -> Int {
        c.attributed.runs.filter { $0.backgroundColor != nil }.count
    }

    func testWarningPaintsOnlyFirstOccurrence() {
        let text = "Ovário direito sem alterações. Ovário esquerdo sem alterações."
        let c = text.laudoHighlight(issues: [issue("sem alterações", "Confira o ovário")])
        XCTAssertEqual(painted(c), 1)
    }

    func testGenericAnchorAndInfoGoToList() {
        let text = "Útero medindo 6,7 x 3,0 x 5,0 cm. Endométrio de 12 mm."
        let c = text.laudoHighlight(issues: [issue("12 mm", "Medida não ditada"), issue("Endométrio de 12 mm", "Info", severity: "info", id: "y")])
        XCTAssertEqual(painted(c), 0)
        XCTAssertEqual(c.notices.count, 2)
    }

    func testPlaceholderStillPaintedPurpleEverywhere() {
        let c = "DBP de ____ mm. CF de ____ mm.".laudoHighlight(issues: [])
        XCTAssertEqual(painted(c), 2)
    }

    func testDuplicateFromSecondSanityEventIsMerged() {
        let text = "Placenta anterior. Líquido normal."
        let c = text.laudoHighlight(issues: [
            issue("Placenta anterior", "Achado não ditado", id: "deterministico"),
            issue("placenta  anterior", "achado não ditado", id: "mesclado"),
        ])
        XCTAssertEqual(painted(c), 1)
    }

    func testGenericAnchorDetector() {
        XCTAssertTrue(String.isGenericAnchor("12 mm"))
        XCTAssertTrue(String.isGenericAnchor("0,5 cm"))
        XCTAssertFalse(String.isGenericAnchor("Endométrio de 12 mm"))
    }
}
