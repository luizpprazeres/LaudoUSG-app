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

    func testThyroidImagesMergeLobesAndMultipleNodules() {
        let right = BiometricData(
            thyroidRightLobe: ThyroidMeasurements(a: "4.2", b: "1.6", c: "1.8"),
            thyroidNodules: [ThyroidNodule(lobe: "lobo_direito", c1: "1.2", c2: "0.9", c3: "0.8", echogenicity: "hipoecoica", margin: "regular")]
        )
        let left = BiometricData(
            thyroidLeftLobe: ThyroidMeasurements(a: "4.0", b: "1.4", c: "1.7"),
            thyroidNodules: [ThyroidNodule(lobe: "lobo_esquerdo", c1: "0.7", c2: "0.5")]
        )

        let merged = ImageAnalysisService.merge([right, left])
        let text = ImageAnalysisService.format([merged], category: .tireoide)

        XCTAssertEqual(merged.thyroidNodules?.count, 2)
        XCTAssertTrue(text.contains("Lobo direito: 4.2 x 1.6 x 1.8 cm"))
        XCTAssertTrue(text.contains("Lobo esquerdo: 4.0 x 1.4 x 1.7 cm"))
        XCTAssertTrue(text.contains("Nódulo 2 (lobo esquerdo): 0.7 x 0.5 cm"))
    }
}
