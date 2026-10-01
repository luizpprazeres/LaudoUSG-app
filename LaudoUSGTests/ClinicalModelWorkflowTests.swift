import XCTest
@testable import LaudoUSG

final class ClinicalModelWorkflowTests: XCTestCase {
    func testDraftEncodesWithoutEnumEnvelopeAndRoundTrips() throws {
        let draft = try XCTUnwrap(ClinicalModelDraft.empty(for: .torax))
        let data = try JSONEncoder().encode(draft)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["categoryCode"] as? String, "TORAX")
        XCTAssertNil(json["thorax"])
        XCTAssertEqual(try JSONDecoder().decode(ClinicalModelDraft.self, from: data), draft)
    }

    func testPreviewDoesNotReviewAndEditInvalidatesRemoteReview() throws {
        var state = ClinicalModelWorkspaceState(draft: validThorax())
        let preview = try state.preparePreview()

        XCTAssertFalse(state.draft.physicianReviewed)
        XCTAssertFalse(state.canCopyOrSendToSala)

        try state.acceptCreatedReport(.init(
            id: "report-1",
            categoryCode: "TORAX",
            status: "generated",
            contentRevision: 1,
            reviewStatus: "pending",
            physicianReviewed: false,
            generatedOutput: preview,
            contract: state.draft,
            warnings: [],
            createdAt: Date()
        ))
        try state.acceptReview(.init(
            ok: true,
            contentRevision: 1,
            reviewStatus: "reviewed",
            reviewedAt: Date()
        ))
        XCTAssertTrue(state.canCopyOrSendToSala)
        XCTAssertFalse(state.draftForPersistence.canCopyOrSendToSala)
        XCTAssertNil(state.draftForPersistence.remoteReport)

        state.replaceDraft(state.draft)
        XCTAssertFalse(state.canCopyOrSendToSala)
        XCTAssertNil(state.previewText)
        XCTAssertNil(state.remoteReport)
        XCTAssertFalse(state.draft.physicianReviewed)
    }

    func testWorkspaceStateIsSerializable() throws {
        var state = ClinicalModelWorkspaceState(draft: validThorax())
        _ = try state.preparePreview()
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(ClinicalModelWorkspaceState.self, from: data), state)
    }

    func testVersionedCreatePayloadUsesSnakeCaseAndContractShape() throws {
        let request = ClinicalReportService.CreateRequest(
            contract: validThorax(),
            writingStyleId: "11111111-1111-4111-8111-111111111111"
        )
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let contract = try XCTUnwrap(json["contract"] as? [String: Any])

        XCTAssertEqual(json["writing_style_id"] as? String, "11111111-1111-4111-8111-111111111111")
        XCTAssertEqual(contract["categoryCode"] as? String, "TORAX")
        XCTAssertEqual(contract["physicianReviewed"] as? Bool, false)
        XCTAssertNil(contract["category_code"])
        let right = try XCTUnwrap(contract["right"] as? [String: Any])
        XCTAssertNotNil(right["pleuralLine"])
        XCTAssertNil(right["pleural_line"])
        let effusion = try XCTUnwrap(right["effusion"] as? [String: Any])
        XCTAssertEqual(Set(effusion.keys), ["present"])
    }

    func testDiscriminatedFalseBranchesOmitStaleOptionalFields() throws {
        guard case .abdomen(var abdomen) = ClinicalModelDraft.empty(for: .abdomenTotalDoppler),
              case .arterial(var arterial) = ClinicalModelDraft.empty(for: .dopplerArterialMmss) else {
            return XCTFail("Rascunhos ausentes")
        }
        abdomen.hepaticVeins = .init(evaluated: false, caliberCm: 1, velocityCms: 2, flow: .hepatopetal)
        arterial.right.thoracicOutlet = .init(
            evaluated: false, maneuvers: "Adson", positions: "Abdução",
            result: .positive, physicianConfirmed: true
        )

        let abdomenJSON = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(abdomen)
        ) as? [String: Any])
        let vessel = try XCTUnwrap(abdomenJSON["hepaticVeins"] as? [String: Any])
        XCTAssertEqual(Set(vessel.keys), ["evaluated"])

        let arterialJSON = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(arterial)
        ) as? [String: Any])
        let right = try XCTUnwrap(arterialJSON["right"] as? [String: Any])
        let outlet = try XCTUnwrap(right["thoracicOutlet"] as? [String: Any])
        XCTAssertEqual(Set(outlet.keys), ["evaluated"])
    }

    func testVersionedReviewPayloadRemainsCamelCase() throws {
        let request = ClinicalReportService.ReviewRequest(
            expectedRevision: 3,
            expectedText: "Laudo revisado"
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(request)
        ) as? [String: Any])
        XCTAssertEqual(json["expectedRevision"] as? Int, 3)
        XCTAssertEqual(json["expectedText"] as? String, "Laudo revisado")
        XCTAssertNil(json["expected_revision"])
    }

    func testApiWarningDecodesPathIntoField() throws {
        let data = #"{"code":"AGE_OUTSIDE_TARGET","severity":"warning","path":"ageDays","message":"Aviso"}"#.data(using: .utf8)!
        let issue = try JSONDecoder().decode(ClinicalContractIssue.self, from: data)
        XCTAssertEqual(issue.field, "ageDays")
    }

    func testPortalHepatofugalRequiresPortalFinding() throws {
        guard case .abdomen(var value) = ClinicalModelDraft.empty(for: .abdomenTotalDoppler) else {
            return XCTFail("Rascunho ausente")
        }
        value.portalVein = .init(caliberCm: 1.1, velocityCms: 22, flow: .hepatofugal)
        XCTAssertTrue(value.activationIssues.contains {
            $0.code == "HEPATOFUGAL_FLOW_WITHOUT_PORTAL_FINDING"
        })
    }

    func testVenousExaminedSideRequiresTerritory() throws {
        let draft = try XCTUnwrap(ClinicalModelDraft.empty(for: .dopplerVenosoMmss))
        XCTAssertTrue(draft.activationIssues.contains { $0.code == "VENOUS_TERRITORY_REQUIRED" })
    }

    func testArterialPercentageCounterexamplesFailClosed() throws {
        guard case .arterial(var value) = ClinicalModelDraft.empty(for: .dopplerArterialMmss) else {
            return XCTFail("Rascunho ausente")
        }
        value.right.stenosisPercent = 40
        value.right.percentageDataSufficient = true
        value.right.percentageConfirmed = true
        XCTAssertTrue(value.activationIssues.contains {
            $0.code == "STENOSIS_PERCENT_STATUS_MISMATCH"
        })

        value.right.stenosisPercent = nil
        XCTAssertTrue(value.activationIssues.contains {
            $0.code == "PERCENTAGE_FLAGS_WITHOUT_VALUE"
        })
    }

    func testThoraxPleuralFindingAllowsCorrelationAndBalikIneligibleOnlyWarns() throws {
        guard case .thorax(var value) = ClinicalModelDraft.empty(for: .torax) else {
            return XCTFail("Rascunho ausente")
        }
        value.correlationSuggested = true
        value.right.pleuralLine = .irregular
        value.right.effusion = .init(
            present: true,
            separationMm: 12,
            context: .init(
                adult: true,
                mechanicallyVentilated: false,
                supineTorso15Deg: true,
                endExpirationPosteriorAxillary: true,
                physicianConfirmed: true
            )
        )

        XCTAssertFalse(value.activationIssues.contains { $0.code == "CORRELATION_WITHOUT_REASON" })
        let issue = try XCTUnwrap(value.activationIssues.first {
            $0.code == "EFFUSION_BALIK_CONTEXT_UNSUPPORTED"
        })
        XCTAssertEqual(issue.severity, .warning)
        let rendered = try ClinicalModelReportRenderer.render(.thorax(value))
        XCTAssertTrue(rendered.contains("volume não calculado"))
        XCTAssertTrue(rendered.contains("irregularidade da linha pleural"))
    }

    func testGrafRequiresLabrumEvenForTypeI() throws {
        guard case .hip(var value) = ClinicalModelDraft.empty(for: .quadrilInfantil) else {
            return XCTFail("Rascunho ausente")
        }
        value.ageDays = 60
        value.right = .init(
            adequateStandardPlane: true,
            alphaDeg: 65,
            betaDeg: 45,
            bonyRoof: .normal,
            cartilaginousRoof: .normal,
            femoralHead: .centered,
            labrumPosition: .notAssessed,
            coveragePercent: nil,
            grafClassification: .typeI,
            classificationConfirmed: true
        )
        XCTAssertNil(value.suggestedGrafClassification(for: .right))
        XCTAssertTrue(value.activationIssues.contains {
            $0.code == "GRAF_INPUT_INCOMPLETE" && $0.field == "right"
        })
    }

    private func validThorax() -> ClinicalModelDraft {
        let side = ThoraxDraft.Side(
            pleuralLine: .regular,
            sliding: .present,
            linesB: .init(count: 0, distribution: .none),
            effusion: .init(present: false, separationMm: nil, context: nil),
            consolidation: .notSeen,
            atelectasis: .notSeen,
            pneumothorax: .notSeen
        )
        return .thorax(.init(
            right: side,
            left: side,
            limitation: nil,
            correlationSuggested: false
        ))
    }
}
