import XCTest
@testable import LaudoUSG

final class DopplerRawPercentileTests: XCTestCase {
    func testLowMcaAndCprAreNotCoercedToNormal() {
        let result = DopplerCalculator.calculate(.init(
            weeks: 30,
            days: 0,
            ipUmbilical: 1.0,
            ipMCA: 0.5,
            ipUterinaDireita: 0.7,
            ipUterinaEsquerda: 0.7
        ))

        XCTAssertLessThan(result.arteriaCerebralMedia.percentile, 5)
        XCTAssertTrue(result.arteriaCerebralMedia.pathological)
        XCTAssertLessThan(result.ratioCerebroplacentario.percentile, 5)
        XCTAssertTrue(result.ratioCerebroplacentario.pathological)
    }

    func testBarcelonaCutoffsKeepP5AndP95AsNormalBoundaries() {
        XCTAssertEqual(DopplerCalculator.barcelonaDopplerPercentile(1.645).label, "95")
        XCTAssertEqual(DopplerCalculator.barcelonaDopplerPercentile(1.646).label, "96")
        XCTAssertEqual(DopplerCalculator.barcelonaDopplerPercentile(-1.645).label, "5")
        XCTAssertEqual(DopplerCalculator.barcelonaDopplerPercentile(-1.646).label, "4")
    }

    func testDuctusVenosusUsesBarcelona2021Equation() throws {
        let meanAt30 = 0.903 - 0.0116 * 30
        let normal = try XCTUnwrap(DuctoVenosoCalculator.calculate(.init(
            igWeeks: 30,
            pi: meanAt30,
            ondaA: .positiva
        )))
        XCTAssertEqual(normal.percentile, 50)
        XCTAssertEqual(normal.classification, .normal)

        let aboveP95 = try XCTUnwrap(DuctoVenosoCalculator.calculate(.init(
            igWeeks: 30,
            pi: meanAt30 + 0.1483 * 1.646,
            ondaA: .positiva
        )))
        XCTAssertEqual(aboveP95.percentile, 96)
        XCTAssertEqual(aboveP95.classification, .alterado)
    }

    func testSameUmbilicalPIChangesWithGestationalAge() throws {
        let at20 = try XCTUnwrap(DopplerPercentileTable.calculate(artery: .umbilical, ip: 1.8, igWeeks: 20))
        let at30 = try XCTUnwrap(DopplerPercentileTable.calculate(artery: .umbilical, ip: 1.8, igWeeks: 30))
        XCTAssertFalse(at20.estimatedPercentile.contains("P9"))
        XCTAssertTrue(at30.estimatedPercentile == "P98" || at30.estimatedPercentile == "P99" || at30.estimatedPercentile == ">P99")
        XCTAssertNotNil(DopplerPercentileTable.calculate(artery: .ductoVenoso, ip: 0.55, igWeeks: 30))
    }

    func testGestationalDaysParticipateInFormula() throws {
        let at30d0 = try XCTUnwrap(DuctoVenosoCalculator.calculate(.init(
            igWeeks: 30,
            igDays: 0,
            pi: 0.55,
            ondaA: .positiva
        )))
        let at30d6 = try XCTUnwrap(DuctoVenosoCalculator.calculate(.init(
            igWeeks: 30,
            igDays: 6,
            pi: 0.55,
            ondaA: .positiva
        )))
        XCTAssertLessThan(at30d6.medianExpected, at30d0.medianExpected)
        XCTAssertNil(DopplerPercentileTable.calculate(
            artery: .umbilical,
            ip: 1.0,
            igWeeks: 30,
            igDays: 7
        ))
    }
}
