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
}
