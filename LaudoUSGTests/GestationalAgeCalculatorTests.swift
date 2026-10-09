import XCTest
@testable import LaudoUSG

final class GestationalAgeCalculatorTests: XCTestCase {
    private var today: Date { date("09/10/2026") }

    func testUSGInsertBlocoIncludesFirstUSGWeeksWithoutZeroDays() throws {
        let result = try XCTUnwrap(
            GestationalAgeCalculator.calcByUSG(usgDate: date("08/08/2026"), usgWeeks: 7, usgDays: 0, today: today)
        )

        XCTAssertEqual(
            result.insertBloco,
            "Primeira ultrassonografia realizada em 08/08/2026 com 7 semanas. Hoje com 15 semanas e 6 dias."
        )
        XCTAssertEqual(result.weeks, 15)
        XCTAssertEqual(result.days, 6)
        XCTAssertEqual(GestationalAgeCalculator.formatDate(result.dpp), "27/03/2027")
    }

    func testUSGInsertBlocoIncludesFirstUSGDays() throws {
        let result = try XCTUnwrap(
            GestationalAgeCalculator.calcByUSG(usgDate: date("08/08/2026"), usgWeeks: 7, usgDays: 3, today: today)
        )

        XCTAssertEqual(
            result.insertBloco,
            "Primeira ultrassonografia realizada em 08/08/2026 com 7 semanas e 3 dias. Hoje com 16 semanas e 2 dias."
        )
        XCTAssertEqual(result.weeks, 16)
        XCTAssertEqual(result.days, 2)
        XCTAssertEqual(GestationalAgeCalculator.formatDate(result.dpp), "24/03/2027")
    }

    func testUSGInsertBlocoUsesSingularForOneWeekAndOneDay() throws {
        let result = try XCTUnwrap(
            GestationalAgeCalculator.calcByUSG(usgDate: date("09/10/2026"), usgWeeks: 1, usgDays: 1, today: today)
        )

        XCTAssertEqual(
            result.insertBloco,
            "Primeira ultrassonografia realizada em 09/10/2026 com 1 semana e 1 dia. Hoje com 1 semana e 1 dia."
        )
    }

    func testUSGInsertBlocoMixesSingularAndPlural() throws {
        let result = try XCTUnwrap(
            GestationalAgeCalculator.calcByUSG(usgDate: date("02/10/2026"), usgWeeks: 1, usgDays: 0, today: today)
        )

        XCTAssertEqual(
            result.insertBloco,
            "Primeira ultrassonografia realizada em 02/10/2026 com 1 semana. Hoje com 2 semanas."
        )
    }

    func testUSGRejectsInvalidInputs() {
        XCTAssertNil(GestationalAgeCalculator.calcByUSG(usgDate: date("08/08/2026"), usgWeeks: 7, usgDays: 7, today: today))
        XCTAssertNil(GestationalAgeCalculator.calcByUSG(usgDate: date("08/08/2026"), usgWeeks: -1, usgDays: 0, today: today))
        XCTAssertNil(GestationalAgeCalculator.calcByUSG(usgDate: date("10/10/2026"), usgWeeks: 7, usgDays: 0, today: today))
    }

    private static func date(_ value: String) -> Date {
        GestationalAgeCalculator.parseDateBR(value)!
    }

    private func date(_ value: String) -> Date {
        Self.date(value)
    }
}
