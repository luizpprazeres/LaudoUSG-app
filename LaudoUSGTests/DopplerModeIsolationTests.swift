import XCTest
@testable import LaudoUSG

final class DopplerModeIsolationTests: XCTestCase {
    private let mixed = BiometricData(
        dbp: "82 mm", cc: "295 mm", gestAge: "32 semanas",
        irRightUterine: "0.51", ipRightUterine: "0.81",
        irLeftUterine: "0.52", ipLeftUterine: "0.82",
        irUmbilical: "0.53", ipUmbilical: "0.83",
        irMCA: "0.54", ipMCA: "0.84",
        irDuctusVenosus: "0.55", ipDuctusVenosus: "0.85",
        tibia: "50 mm", ila: "12 cm", gender: "feminino"
    )

    func testImageRequestWireContractMatchesAndroid() throws {
        let cases: [(ReportCategory, Bool, Bool, String, [String])] = [
            (.dopplerObstetrico, false, false, "OBSTETRICA", ["DOPPLER_OBSTETRICO"]),
            (.dopplerObstetrico, true, true, "DOPPLER_OBSTETRICO", []),
            (.obstetrica, false, false, "OBSTETRICA", []),
            (.obstetrica, true, true, "OBSTETRICA", []),
            (.morfologico, false, false, "MORFOLOGICO", []),
            (.morfologico, false, true, "MORFOLOGICO", ["DOPPLER_OBSTETRICO"])
        ]
        for (category, only, extra, expectedCategory, modules) in cases {
            let request = ImageAnalysisService.imageRequest(
                image: Data([1, 2, 3]), category: category, dopplerOnly: only, includeDoppler: extra
            )
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
            XCTAssertEqual(json["imageBase64"] as? String, "AQID")
            XCTAssertEqual(json["category"] as? String, expectedCategory)
            XCTAssertEqual(json["modules"] as? [String], modules)
            XCTAssertEqual(json["gemelar"] as? Bool, false)
            XCTAssertNil(json["doppler_mode"])
            XCTAssertNil(json["image_base64"])
        }
    }

    func testIsolatedFiltersStructuredPayloadAndTextToTenDopplerFields() throws {
        let selected = ImageAnalysisService.selectImagingData(mixed, category: .dopplerObstetrico, dopplerOnly: true)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(selected)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set([
            "irRightUterine", "ipRightUterine", "irLeftUterine", "ipLeftUterine",
            "irUmbilical", "ipUmbilical", "irMCA", "ipMCA", "irDuctusVenosus", "ipDuctusVenosus"
        ]))
        let text = ImageAnalysisService.format([mixed], category: .dopplerObstetrico)
        XCTAssertTrue(text.contains("IP ducto venoso: 0.85"))
        XCTAssertFalse(text.contains("DBP"))
        XCTAssertFalse(text.contains("ILA"))
        XCTAssertFalse(text.contains("Tíbia"))
        XCTAssertEqual(ImageAnalysisService.merge([selected]), selected)
        XCTAssertEqual(mixed.dbp, "82 mm")
    }

    func testPlainObstetricFiltersUnexpectedDopplerFromPayloadAndText() {
        let selected = ImageAnalysisService.selectImagingData(mixed, category: .obstetrica, includeDoppler: true)
        XCTAssertNil(selected.ipRightUterine)
        XCTAssertNil(selected.irDuctusVenosus)
        XCTAssertEqual(selected.dbp, mixed.dbp)
        XCTAssertEqual(selected.ila, mixed.ila)
        let text = ImageAnalysisService.format([mixed], category: .obstetrica)
        XCTAssertTrue(text.contains("DBP: 82 mm"))
        XCTAssertFalse(text.contains("Doppler"))
        XCTAssertFalse(text.contains("IP "))
        XCTAssertFalse(text.contains("IR "))
    }

    func testCombinedPreservesBiometryAndDoppler() {
        let selected = ImageAnalysisService.selectImagingData(mixed, category: .dopplerObstetrico)
        XCTAssertEqual(selected, mixed)
        let text = ImageAnalysisService.format([selected], category: .obstetrica, includeDoppler: true)
        XCTAssertTrue(text.contains("DBP: 82 mm"))
        XCTAssertTrue(text.contains("IP artéria umbilical: 0.83"))
    }

    func testMorphologyExtraAndOtherCategoriesArePreserved() {
        XCTAssertNil(ImageAnalysisService.selectImagingData(mixed, category: .morfologico).ipMCA)
        XCTAssertEqual(ImageAnalysisService.selectImagingData(mixed, category: .morfologico, includeDoppler: true), mixed)
        XCTAssertEqual(ImageAnalysisService.selectImagingData(mixed, category: .tireoide), mixed)
    }

    @MainActor
    func testCategoryChangeResetsOnlyToggleWithoutDiscardingDrafts() {
        let vm = GenerateViewModel()
        vm.category = .dopplerObstetrico
        XCTAssertFalse(vm.dopplerOnly)
        vm.dopplerOnly = true
        vm.inputText = "Ditado sintetico que deve permanecer."
        vm.editedLaudoText = "Laudo editado sintetico."
        vm.liveTranscript = "Transcricao sintetica."
        vm.pendingCompanionImageData = mixed
        vm.pendingCompanionImageSummary = "Resumo sintetico."
        vm.category = .obstetrica
        XCTAssertFalse(vm.dopplerOnly)
        XCTAssertEqual(vm.inputText, "Ditado sintetico que deve permanecer.")
        XCTAssertEqual(vm.editedLaudoText, "Laudo editado sintetico.")
        XCTAssertEqual(vm.liveTranscript, "Transcricao sintetica.")
        XCTAssertEqual(vm.pendingCompanionImageData, mixed)
        XCTAssertEqual(vm.pendingCompanionImageSummary, "Resumo sintetico.")
        vm.category = .dopplerObstetrico
        XCTAssertFalse(vm.dopplerOnly)
        vm.dopplerOnly = true
        vm.category = .dopplerObstetrico
        XCTAssertTrue(vm.dopplerOnly, "Reatribuir a mesma categoria nao e uma troca")
    }

    @MainActor
    func testExplicitResetRestoresCombinedMode() {
        let vm = GenerateViewModel()
        vm.category = .dopplerObstetrico
        vm.dopplerOnly = true
        vm.reset()
        XCTAssertFalse(vm.dopplerOnly)
        XCTAssertEqual(vm.category, .dopplerObstetrico)
    }
}
