import XCTest
@testable import LaudoUSG

final class DopplerParserTests: XCTestCase {
    func testTextualIGAndUmbilicalIP() {
        let findings = DopplerParser.parse(achados: "32 semanas. AU IP 1.5")

        XCTAssertEqual(findings.ig, GestationalAge(weeks: 32, days: 0, source: .textual))
        XCTAssertEqual(findings.umbilicalIP, 1.5)
    }

    func testDUMHasPriorityAndCalculatesIG() {
        let today = date(2025, 8, 15)
        let findings = DopplerParser.parse(achados: "DUM 01/01/2025. AU 1.4", today: today)

        XCTAssertEqual(findings.ig, GestationalAge(weeks: 32, days: 2, source: .dum))
        XCTAssertEqual(findings.umbilicalIP, 1.4)
    }

    func testMultipleArteries() {
        let findings = DopplerParser.parse(
            achados: "32s. AU 1.2. ACM 1.8. Uterinas média 1.3"
        )

        XCTAssertEqual(findings.ig, GestationalAge(weeks: 32, days: 0, source: .textual))
        XCTAssertEqual(findings.umbilicalIP, 1.2)
        XCTAssertEqual(findings.cerebralMediaIP, 1.8)
        XCTAssertEqual(findings.uterinasMediaIP, 1.3)
    }

    func testMissingIGRemainsNil() {
        let findings = DopplerParser.parse(achados: "AU IP 1.5")

        XCTAssertNil(findings.ig)
        XCTAssertEqual(findings.umbilicalIP, 1.5)
    }

    func testBrazilianDecimalSeparator() {
        let findings = DopplerParser.parse(achados: "AU IP 1,45")

        XCTAssertEqual(findings.umbilicalIP, 1.45)
    }

    func testDuctoVenosoNegativeWaveA() {
        let findings = DopplerParser.parse(achados: "Ducto venoso onda A negativa")

        XCTAssertEqual(findings.ductoVenoso, .ondaANegativa)
    }

    func testBiometriaUsesHadlockFemurDating() {
        let findings = DopplerParser.parse(achados: "DBP 75 mm. CC 273 mm. CF 54 mm")

        XCTAssertEqual(findings.ig, GestationalAge(weeks: 28, days: 4, source: .biometria))
    }

    func testFirstUltrasoundAnchor() {
        let today = date(2025, 2, 1)
        let findings = DopplerParser.parse(
            achados: "1ª USG IG 8s2d em 01/01/2025. ACM IP 1.7",
            today: today
        )

        XCTAssertEqual(findings.ig, GestationalAge(weeks: 12, days: 5, source: .primeiraUSG))
        XCTAssertEqual(findings.cerebralMediaIP, 1.7)
    }

    func testUterineSidesShorthand() {
        let findings = DopplerParser.parse(achados: "Uterinas: D 1.2 / E 1.4")

        XCTAssertEqual(findings.uterinaDireitaIP, 1.2)
        XCTAssertEqual(findings.uterinaEsquerdaIP, 1.4)
    }

    func testDUMOverridesTextualIG() {
        let today = date(2025, 8, 15)
        let findings = DopplerParser.parse(
            achados: "32 semanas. DUM em 1 de janeiro de 2025. AU IP 1.1",
            today: today
        )

        XCTAssertEqual(findings.ig, GestationalAge(weeks: 32, days: 2, source: .dum))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")

        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        return calendar.date(from: components)!
    }
}
