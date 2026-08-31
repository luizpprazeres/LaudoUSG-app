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

    func testBreastImagesMergeMultipleFindingsOnSameSide() {
        let first = BiometricData(breastFindings: [
            ExtractedBreastFinding(side: "direita", type: "nodulo", c1: "1.2", c2: "0.9", c3: "0.8", margin: "circunscrita")
        ])
        let second = BiometricData(breastFindings: [
            ExtractedBreastFinding(side: "direita", type: "cisto_simples", c1: "0.6", c2: "0.5", c3: "0.4")
        ])

        let merged = ImageAnalysisService.merge([first, second])
        let text = ImageAnalysisService.format([merged], category: .mamaria)

        XCTAssertEqual(merged.breastFindings?.count, 2)
        XCTAssertTrue(text.contains("1. Nódulo — mama direita: 1.2 x 0.9 x 0.8 cm"))
        XCTAssertTrue(text.contains("2. Cisto simples — mama direita: 0.6 x 0.5 x 0.4 cm"))
        XCTAssertFalse(text.contains("BI-RADS"))
    }

    func testCarotidImagesMergeVesselsAndPlaquesWithoutClassifyingStenosis() {
        let first = BiometricData(carotidMeasurements: [
            ExtractedCarotidMeasurement(side: "direita", vessel: "interna", psv: "82", vdf: "24", ir: "0.71")
        ])
        let second = BiometricData(
            carotidMeasurements: [ExtractedCarotidMeasurement(side: "esquerda", vessel: "vertebral", psv: "41", flowDirection: "anterogrado")],
            carotidPlaques: [ExtractedCarotidPlaque(side: "direita", location: "bulbo carotídeo", thickness: "2.1")]
        )

        let merged = ImageAnalysisService.merge([first, second])
        let text = ImageAnalysisService.format([merged], category: .dopplerCarotidas)

        XCTAssertEqual(merged.carotidMeasurements?.count, 2)
        XCTAssertEqual(merged.carotidPlaques?.count, 1)
        XCTAssertTrue(text.contains("carótida interna direita: PSV 82 · VDF 24 · IR 0.71"))
        XCTAssertTrue(text.contains("vertebral esquerda: PSV 41 · Fluxo anterogrado"))
        XCTAssertTrue(text.contains("Placa 1 direita: bulbo carotídeo · 2.1 mm"))
        XCTAssertFalse(text.lowercased().contains("estenose grave"))
    }
}
