import XCTest
@testable import LaudoUSG

final class DopplerHepaticoClinicalModelTests: XCTestCase {
    func testInitialDraftIsFailClosedWithoutNormalDefaults() throws {
        guard case .hepaticDoppler(let value)? = ClinicalModelDraft.empty(for: .dopplerHepatico) else {
            return XCTFail("Rascunho hepático ausente")
        }

        XCTAssertEqual(value.portalVein.patency, .notAssessed)
        XCTAssertNil(value.portalVein.caliberCm)
        XCTAssertNil(value.portalVein.velocityCms)
        XCTAssertNil(value.portalVein.flow)
        XCTAssertEqual(value.portalPathology.status, .notAssessed)
        XCTAssertFalse(value.normalHemodynamicsConfirmed)
        XCTAssertFalse(value.hepaticVeins.evaluated)
        XCTAssertFalse(value.splenicVein.evaluated)
        XCTAssertFalse(value.superiorMesentericVein.evaluated)
        XCTAssertFalse(value.commonHepaticArtery.evaluated)

        let codes = Set(value.activationIssues.map(\.code))
        XCTAssertTrue(codes.contains("PORTAL_VEIN_REQUIRED"))
        XCTAssertTrue(codes.contains("PORTAL_PATENCY_REQUIRED"))
        XCTAssertTrue(codes.contains("PORTAL_STATUS_REQUIRED"))
        XCTAssertThrowsError(try ClinicalModelReportRenderer.render(.hepaticDoppler(value)))
    }

    func testMinimalNormalReportRequiresExplicitConfirmation() throws {
        var value = normalDraft()
        value.normalHemodynamicsConfirmed = false
        XCTAssertTrue(value.activationIssues.contains { $0.code == "NORMAL_HEMODYNAMICS_UNCONFIRMED" })

        value.normalHemodynamicsConfirmed = true
        let report = try ClinicalModelReportRenderer.render(.hepaticDoppler(value))
        XCTAssertTrue(report.hasPrefix("DOPPLER HEPÁTICO"))
        XCTAssertTrue(report.contains("Veia porta pérvia, com calibre de 1,1 cm, velocidade de 22 cm/s e fluxo hepatopetal."))
        XCTAssertTrue(report.contains("Estudo Doppler hepático sem alterações hemodinâmicas significativas nos vasos avaliados."))
        XCTAssertFalse(report.contains("Veia esplênica"))
        XCTAssertFalse(report.localizedCaseInsensitiveContains("TIPS"))
        XCTAssertFalse(report.localizedCaseInsensitiveContains("transplante"))
    }

    func testEvaluatedArteryRequiresAndRendersApprovedHemodynamics() throws {
        var value = normalDraft()
        value.commonHepaticArtery = .init(
            evaluated: true, patency: .patent, caliberCm: 0.5, velocityCms: nil,
            flow: .hepatopetal, spectralPattern: .preserved,
            peakSystolicVelocityCms: nil, endDiastolicVelocityCms: nil,
            resistanceIndex: nil
        )
        XCTAssertTrue(value.activationIssues.contains { $0.code == "HEPATIC_ARTERY_HEMODYNAMICS_REQUIRED" })

        value.commonHepaticArtery.peakSystolicVelocityCms = 82
        value.commonHepaticArtery.endDiastolicVelocityCms = 21
        value.commonHepaticArtery.resistanceIndex = 0.74
        let report = try ClinicalModelReportRenderer.render(.hepaticDoppler(value))
        XCTAssertTrue(report.contains("velocidade de pico sistólico de 82 cm/s"))
        XCTAssertTrue(report.contains("velocidade diastólica final de 21 cm/s"))
        XCTAssertTrue(report.contains("índice de resistência de 0,74"))
    }

    func testOptionalVesselOffEncodesOnlyDiscriminator() throws {
        var value = normalDraft()
        value.hepaticVeins = .init(
            evaluated: false, patency: .thrombosis, caliberCm: 0.8, velocityCms: 18,
            flow: .hepatopetal, spectralPattern: .altered,
            peakSystolicVelocityCms: 80, endDiastolicVelocityCms: 20,
            resistanceIndex: 0.7
        )
        let data = try JSONEncoder().encode(ClinicalModelDraft.hepaticDoppler(value))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let vessel = try XCTUnwrap(json["hepaticVeins"] as? [String: Any])
        XCTAssertEqual(Set(vessel.keys), ["evaluated"])
        XCTAssertEqual(vessel["evaluated"] as? Bool, false)
    }

    func testContractRoundTripsAndUsesExistingCreatePayload() throws {
        let draft = ClinicalModelDraft.hepaticDoppler(normalDraft())
        let data = try JSONEncoder().encode(draft)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["categoryCode"] as? String, "DOPPLER_HEPATICO")
        XCTAssertNil(json["hepaticDoppler"])
        XCTAssertEqual(try JSONDecoder().decode(ClinicalModelDraft.self, from: data), draft)

        let request = ClinicalReportService.CreateRequest(
            contract: draft,
            writingStyleId: "11111111-1111-4111-8111-111111111111"
        )
        let requestJSON = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(request)
        ) as? [String: Any])
        let contract = try XCTUnwrap(requestJSON["contract"] as? [String: Any])
        XCTAssertEqual(contract["categoryCode"] as? String, "DOPPLER_HEPATICO")
        XCTAssertEqual(contract["physicianReviewed"] as? Bool, false)
    }

    func testPortalThrombosisAcceptsZeroVelocityOnlyWithAbsentFlow() throws {
        var value = normalDraft()
        value.normalHemodynamicsConfirmed = false
        value.portalVein = .init(
            patency: .thrombosis, caliberCm: 1.3, velocityCms: 0, flow: .absent,
            spectralPattern: nil, peakSystolicVelocityCms: nil,
            endDiastolicVelocityCms: nil, resistanceIndex: nil
        )
        value.portalPathology = .init(
            status: .confirmed, kind: .portalThrombosis,
            evidence: "Material ecogênico intraluminal com ausência de fluxo ao Doppler",
            physicianConfirmed: true
        )
        XCTAssertFalse(value.activationIssues.contains { $0.code == "ZERO_VELOCITY_WITH_PRESENT_FLOW" })
        XCTAssertTrue(try ClinicalModelReportRenderer.render(.hepaticDoppler(value)).contains("Sinais ultrassonográficos de trombose portal."))

        value.portalVein.flow = .hepatopetal
        XCTAssertTrue(value.activationIssues.contains { $0.code == "ZERO_VELOCITY_WITH_PRESENT_FLOW" })
    }

    func testNormalStateRejectsNonPatentAndAlteredPattern() {
        var value = normalDraft()
        value.portalVein.patency = .thrombosis
        XCTAssertTrue(value.activationIssues.contains { $0.code == "NONPATENT_VESSEL_WITHOUT_FINDING" })

        value = normalDraft()
        value.hepaticVeins = .init(
            evaluated: true, patency: .patent, caliberCm: 0.8, velocityCms: 18,
            flow: .hepatofugal, spectralPattern: .altered,
            peakSystolicVelocityCms: nil, endDiastolicVelocityCms: nil,
            resistanceIndex: nil
        )
        XCTAssertTrue(value.activationIssues.contains { $0.code == "ALTERED_PATTERN_WITHOUT_FINDING" })
    }

    private func normalDraft() -> DopplerHepaticoDraft {
        var value = DopplerHepaticoDraft.empty
        value.portalVein = .init(
            patency: .patent, caliberCm: 1.1, velocityCms: 22, flow: .hepatopetal,
            spectralPattern: nil, peakSystolicVelocityCms: nil,
            endDiastolicVelocityCms: nil, resistanceIndex: nil
        )
        value.portalPathology = .init(status: .absent, kind: nil, evidence: nil, physicianConfirmed: false)
        value.normalHemodynamicsConfirmed = true
        return value
    }
}
