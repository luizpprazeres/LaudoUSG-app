import XCTest
@testable import LaudoUSG

final class ImageAnalysisServiceTests: XCTestCase {
    func testStandaloneDopplerFormatsResistanceAndPulsatilityWithoutBiometry() {
        let data = BiometricData(
            dbp: "82 mm",
            irRightUterine: "0,59",
            ipRightUterine: "0,81",
            irUmbilical: "0,58",
            ipUmbilical: "1,80"
        )

        let text = ImageAnalysisService.format([data], category: .dopplerObstetrico)

        XCTAssertTrue(text.contains("IR uterina direita: 0,59"))
        XCTAssertTrue(text.contains("IP uterina direita: 0,81"))
        XCTAssertTrue(text.contains("IR artéria umbilical: 0,58"))
        XCTAssertTrue(text.contains("IP artéria umbilical: 1,80"))
        XCTAssertFalse(text.contains("DBP"))
        XCTAssertFalse(text.contains("Biometria fetal"))
    }

    func testObstetricImageCanCombineBiometryAndDoppler() {
        let data = BiometricData(
            dbp: "82 mm",
            cc: "295 mm",
            irMCA: "0,81",
            ipMCA: "1,75",
            irDuctusVenosus: "0,40",
            ipDuctusVenosus: "1,89"
        )

        let text = ImageAnalysisService.format([data], category: .obstetrica)

        XCTAssertTrue(text.contains("Biometria fetal"))
        XCTAssertTrue(text.contains("DBP: 82 mm"))
        XCTAssertTrue(text.contains("CC: 295 mm"))
        XCTAssertTrue(text.contains("IR artéria cerebral média: 0,81"))
        XCTAssertTrue(text.contains("IP ducto venoso: 1,89"))
    }
}
