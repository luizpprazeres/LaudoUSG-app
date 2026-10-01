import XCTest
@testable import LaudoUSG

final class CategorySelectionTests: XCTestCase {
    func testSelectableCategoriesAreExactlyTheApprovedIOSSet() {
        let expected: Set<String> = [
            "ABDOMEN_TOTAL", "ABDOMEN_SUPERIOR", "VIAS_URINARIAS", "TIREOIDE",
            "PARATIREOIDE", "CERVICAL", "GLANDULAS_SALIVARES", "MAMARIA",
            "PELVE_FEMININA", "OBSTETRICA", "DOPPLER_OBSTETRICO", "MORFOLOGICO",
            "CERVICOMETRIA", "MUSCULOESQUELETICO_V2", "ESCROTAL", "REGIAO_INGUINAL",
            "PAREDE_ABDOMINAL", "PARTES_MOLES", "PROSTATA_TRANSRETAL",
            "PROSTATA_SUPRAPUBICA", "TRANSFONTANELA", "DOPPLER_CAROTIDAS",
            "DOPPLER_VENOSO_MMII", "DOPPLER_VENOSO_MMII_MEDIDAS",
            "DOPPLER_ARTERIAL_MMII", "DOPPLER_FISTULA_AV", "DOPPLER_RENAL",
            "OCULAR", "LIVRE",
        ]
        let selectable = ReportCategory.selectable
        XCTAssertEqual(Set(selectable.map(\.rawValue)), expected)
        XCTAssertEqual(selectable.count, expected.count)
        XCTAssertTrue(selectable.contains(.cervicometria))
        XCTAssertFalse(selectable.contains(.abdomenTotalDoppler))
        XCTAssertFalse(selectable.contains(.musculoesqueleticoRaras))
        XCTAssertTrue(Set(ReportCategory.priority).isSubset(of: Set(selectable)))
    }

    func testHiddenCodesStillDecodeForSavedReports() throws {
        for category in [
            ReportCategory.abdomenTotalDoppler,
            .dopplerVenosoMmss,
            .dopplerArterialMmss,
            .torax,
            .quadrilInfantil,
            .musculoesqueleticoRaras,
        ] {
            XCTAssertEqual(ReportCategory(rawValue: category.rawValue), category)
            let decoded = try JSONDecoder().decode(ReportCategory.self, from: Data("\"\(category.rawValue)\"".utf8))
            XCTAssertEqual(decoded, category)
        }
    }

    func testApprovedPendingModelsRemainHiddenUntilSimultaneousActivation() {
        let pending = Set(ReportCategory.allCases.filter(\.isPendingClinicalActivation))
        XCTAssertEqual(pending, PendingClinicalModelContracts.categories)
        XCTAssertTrue(pending.isDisjoint(with: Set(ReportCategory.selectable)))
        XCTAssertEqual(
            Set(pending.map(\.rawValue)),
            [
                "ABDOMEN_TOTAL_DOPPLER",
                "DOPPLER_VENOSO_MMSS",
                "DOPPLER_ARTERIAL_MMSS",
                "TORAX",
                "QUADRIL_INFANTIL",
            ]
        )
    }

    func testPendingModelsEncodeCanonicalBackendCodes() throws {
        for category in PendingClinicalModelContracts.categories {
            let request = GenerateRequest(rawInput: "Caso sintético", categoryHint: category)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder.api.encode(request)) as? [String: Any])
            XCTAssertEqual(json["category_hint"] as? String, category.rawValue)
        }
    }

    func testCervicometriaUsesExistingBackendCode() throws {
        let request = GenerateRequest(rawInput: "Medida do colo uterino", categoryHint: .cervicometria)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder.api.encode(request)) as? [String: Any])
        XCTAssertEqual(json["category_hint"] as? String, "CERVICOMETRIA")
    }
}
