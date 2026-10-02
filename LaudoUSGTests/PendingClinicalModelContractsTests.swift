import XCTest
@testable import LaudoUSG

final class PendingClinicalModelContractsTests: XCTestCase {
    func testAbdomenStartsWithoutClinicalMeasurementsAndFailsClosed() {
        let optional = AbdomenTotalDopplerDraft.OptionalVessel(evaluated: false, caliberCm: nil, velocityCms: nil, flow: nil)
        let draft = AbdomenTotalDopplerDraft(
            documentationPhoto: .include,
            abdomenReport: String(repeating: "Modelo de abdome revisado pelo médico. ", count: 3),
            portalVein: .init(caliberCm: nil, velocityCms: nil, flow: nil),
            hepaticVeins: optional,
            splenicVein: optional,
            superiorMesentericVein: optional,
            commonHepaticArtery: optional,
            portalPathology: .init(status: .suspected, kind: .portalHypertension, evidence: nil, physicianConfirmed: false)
        )

        XCTAssertEqual(
            Set(draft.activationIssues.map(\.code)),
            ["MODEL_NOT_REVIEWED", "PORTAL_VEIN_REQUIRED", "PORTAL_CONCLUSION_INCOMPLETE"]
        )
    }

    func testVenousUpperLimbBlocksUntestedRefluxAndUnconfirmedThrombusPhase() {
        let affected = DopplerVenosoMmssDraft.Side(
            examined: true,
            deepSystem: .thrombosis,
            superficialSystem: .patent,
            competenceTested: false,
            reflux: .present,
            internalJugular: .notAssessed,
            catheter: .init(present: true, relation: nil, segment: nil),
            thrombosisPhase: .acute,
            phaseConfirmed: false
        )
        let unexamined = DopplerVenosoMmssDraft.Side(
            examined: false,
            deepSystem: .notAssessed,
            superficialSystem: .notAssessed,
            competenceTested: false,
            reflux: .notAssessed,
            internalJugular: .notAssessed,
            catheter: .init(present: false, relation: nil, segment: nil),
            thrombosisPhase: .notApplicable,
            phaseConfirmed: false
        )
        let draft = DopplerVenosoMmssDraft(indication: .catheter, laterality: .right, right: affected, left: unexamined)

        XCTAssertEqual(
            Set(draft.activationIssues.map(\.code)),
            ["MODEL_NOT_REVIEWED", "REFLUX_NOT_TESTED", "THROMBOSIS_PHASE_UNCONFIRMED", "CATHETER_RELATION_INCOMPLETE"]
        )
    }

    func testArterialUpperLimbBlocksUnsupportedPercentageAndIncompleteOutletModule() {
        let side = DopplerArterialMmssDraft.Side(
            examined: true,
            status: .stenosis,
            affectedVessel: "Artéria subclávia",
            psvCms: [:],
            stenosisPercent: 70,
            percentageDataSufficient: true,
            percentageConfirmed: false,
            distalPattern: nil,
            thoracicOutlet: .init(evaluated: true, maneuvers: nil, positions: nil, result: nil, physicianConfirmed: false)
        )
        let other = DopplerArterialMmssDraft.Side(
            examined: false,
            status: .normal,
            affectedVessel: nil,
            psvCms: [:],
            stenosisPercent: nil,
            percentageDataSufficient: false,
            percentageConfirmed: false,
            distalPattern: nil,
            thoracicOutlet: .init(evaluated: false, maneuvers: nil, positions: nil, result: nil, physicianConfirmed: nil)
        )
        let draft = DopplerArterialMmssDraft(laterality: .right, right: side, left: other)

        XCTAssertEqual(
            Set(draft.activationIssues.map(\.code)),
            ["MODEL_NOT_REVIEWED", "ALTERED_ARTERIAL_MEASUREMENTS_REQUIRED", "DISTAL_PATTERN_REQUIRED", "STENOSIS_PERCENT_UNSUPPORTED", "THORACIC_OUTLET_UNCONFIRMED"]
        )
    }

    func testThoraxFailsClosedOutsideValidatedBalikContext() {
        let right = ThoraxDraft.Side(
            pleuralLine: .regular,
            sliding: .present,
            linesB: .init(count: 3, distribution: .none),
            effusion: .init(
                present: true,
                separationMm: 10,
                context: .init(adult: true, mechanicallyVentilated: false, supineTorso15Deg: true, endExpirationPosteriorAxillary: true, physicianConfirmed: true)
            ),
            consolidation: .notSeen,
            atelectasis: .notSeen,
            pneumothorax: .notSeen
        )
        let left = ThoraxDraft.Side(
            pleuralLine: .regular,
            sliding: .present,
            linesB: .init(count: 0, distribution: .none),
            effusion: .init(present: false, separationMm: nil, context: nil),
            consolidation: .notSeen,
            atelectasis: .notSeen,
            pneumothorax: .notSeen
        )
        let draft = ThoraxDraft(right: right, left: left, limitation: nil, correlationSuggested: false)

        XCTAssertEqual(
            Set(draft.activationIssues.map(\.code)),
            ["MODEL_NOT_REVIEWED", "EFFUSION_BALIK_CONTEXT_UNSUPPORTED", "LINES_B_COUNT_WITHOUT_DISTRIBUTION"]
        )
        XCTAssertNil(draft.right.effusion.estimatedVolumeMl)
    }

    func testThoraxCalculatesBalikVolumeOnlyInValidatedContext() {
        let effusion = ThoraxDraft.Effusion(
            present: true,
            separationMm: 10,
            context: .init(adult: true, mechanicallyVentilated: true, supineTorso15Deg: true, endExpirationPosteriorAxillary: true, physicianConfirmed: true)
        )

        XCTAssertEqual(effusion.estimatedVolumeMl, 200)
        XCTAssertEqual(BalikPleuralEffusionMethod.formula, "V (mL) = 20 × Sep (mm)")
        XCTAssertEqual(BalikPleuralEffusionMethod.doi, "10.1007/s00134-005-0024-2")
        XCTAssertEqual(BalikPleuralEffusionMethod.meanAbsoluteErrorMl, 158)
    }

    func testGrafSuggestionIsDeterministicButRequiresMedicalConfirmation() {
        let side = QuadrilInfantilDraft.Side(
            adequateStandardPlane: true,
            alphaDeg: 64,
            betaDeg: 48,
            bonyRoof: .normal,
            cartilaginousRoof: .normal,
            femoralHead: .centered,
            labrumPosition: .normal,
            coveragePercent: nil,
            grafClassification: .typeI,
            classificationConfirmed: false
        )
        let draft = QuadrilInfantilDraft(
            ageDays: 60,
            right: side,
            left: side,
            recommendation: nil,
            recommendationConfirmed: false
        )

        XCTAssertEqual(draft.suggestedGrafClassification(for: .right), .typeI)
        XCTAssertNil(draft.validatedGrafClassification(for: .right))
        XCTAssertFalse(draft.physicianReviewed)
        XCTAssertTrue(draft.activationIssues.contains { $0.code == "MODEL_NOT_REVIEWED" })
        XCTAssertTrue(draft.activationIssues.contains { $0.code == "GRAF_UNCONFIRMED" })
    }

    func testQuadrilStartsWithoutAgeAnglesOrClassification() {
        let emptySide = QuadrilInfantilDraft.Side(
            adequateStandardPlane: false,
            alphaDeg: nil,
            betaDeg: nil,
            bonyRoof: .notAssessed,
            cartilaginousRoof: .notAssessed,
            femoralHead: .notAssessed,
            labrumPosition: .notAssessed,
            coveragePercent: nil,
            grafClassification: nil,
            classificationConfirmed: false
        )
        let draft = QuadrilInfantilDraft(
            ageDays: nil,
            right: emptySide,
            left: emptySide,
            recommendation: nil,
            recommendationConfirmed: false
        )

        XCTAssertNil(draft.ageDays)
        XCTAssertNil(draft.right.alphaDeg)
        XCTAssertNil(draft.right.betaDeg)
        XCTAssertNil(draft.suggestedGrafClassification(for: .right))
        XCTAssertTrue(draft.activationIssues.contains { $0.code == "AGE_REQUIRED" })
        XCTAssertEqual(draft.activationIssues.filter { $0.code == "GRAF_INPUT_INCOMPLETE" }.count, 2)
    }

    func testGrafFailsClosedWhenAnyInputIsMissingAndAgeAboveSixMonthsOnlyWarns() {
        let incomplete = QuadrilInfantilDraft.Side(
            adequateStandardPlane: true,
            alphaDeg: 58,
            betaDeg: nil,
            bonyRoof: .rounded,
            cartilaginousRoof: .normal,
            femoralHead: .centered,
            labrumPosition: .normal,
            coveragePercent: nil,
            grafClassification: .typeIIB,
            classificationConfirmed: true
        )
        let draft = QuadrilInfantilDraft(
            ageDays: 240,
            right: incomplete,
            left: incomplete,
            recommendation: "Controle ultrassonográfico.",
            recommendationConfirmed: false
        )

        XCTAssertNil(draft.suggestedGrafClassification(for: .right))
        XCTAssertNil(draft.validatedGrafClassification(for: .right))
        XCTAssertTrue(draft.activationIssues.contains { $0.code == "GRAF_INPUT_INCOMPLETE" })
        XCTAssertTrue(draft.activationIssues.contains { $0.code == "AGE_OUTSIDE_TARGET" && $0.severity == .warning })
        XCTAssertTrue(draft.activationIssues.contains { $0.code == "RECOMMENDATION_UNCONFIRMED" })
    }

    func testContractsEncodeSameCamelCaseKeysAsSharedV1() throws {
        let side = QuadrilInfantilDraft.Side(
            adequateStandardPlane: true,
            alphaDeg: 64,
            betaDeg: 48,
            bonyRoof: .normal,
            cartilaginousRoof: .normal,
            femoralHead: .centered,
            labrumPosition: .normal,
            coveragePercent: 55,
            grafClassification: .typeI,
            classificationConfirmed: true
        )
        let draft = QuadrilInfantilDraft(ageDays: 60, right: side, left: side, recommendation: nil, recommendationConfirmed: false)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])

        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json["categoryCode"] as? String, "QUADRIL_INFANTIL")
        XCTAssertEqual(json["physicianReviewed"] as? Bool, false)
        XCTAssertEqual(json["ageDays"] as? Int, 60)
        let right = try XCTUnwrap(json["right"] as? [String: Any])
        XCTAssertEqual(right["alphaDeg"] as? Double, 64)
        XCTAssertEqual(right["grafClassification"] as? String, "I")
    }
}
