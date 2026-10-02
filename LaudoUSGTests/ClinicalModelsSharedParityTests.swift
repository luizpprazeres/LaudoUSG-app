import XCTest
@testable import LaudoUSG

/// Paridade com `@laudousg/shared` (clinicalModels v1). A fixture é gerada
/// executando `validateClinicalModelInput` e `renderClinicalModelReport` reais
/// do monorepo; ver `sharedCommit` no JSON. Regerar sempre que o contrato ou o
/// renderer compartilhado mudar.
final class ClinicalModelsSharedParityTests: XCTestCase {
    private struct Fixture: Decodable {
        let sharedCommit: String
        let normalAbdomenReport: String
        let cases: [Case]
    }

    private struct Case: Decodable {
        let name: String
        let success: Bool
        let issueCodes: [String]
        let warningCodes: [String]
        let report: String?
    }

    private func loadFixture() throws -> (Fixture, [[String: Any]]) {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "clinical-models-v1-golden", withExtension: "json"),
            "clinical-models-v1-golden.json não foi copiado para o bundle de testes"
        )
        let data = try Data(contentsOf: url)
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inputs = try XCTUnwrap(raw["cases"] as? [[String: Any]]).compactMap { $0["input"] as? [String: Any] }
        XCTAssertEqual(inputs.count, fixture.cases.count)
        return (fixture, inputs)
    }

    func testSharedGoldenCasesRenderAndBlockIdentically() throws {
        let (fixture, inputs) = try loadFixture()
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 40)

        for (expected, input) in zip(fixture.cases, inputs) {
            let inputData = try JSONSerialization.data(withJSONObject: input)
            let draft = try JSONDecoder().decode(ClinicalModelDraft.self, from: inputData)
            let issues = draft.previewIssues
            let codes = Set(issues.map(\.code))

            XCTAssertEqual(issues.filter { $0.severity == .error }.isEmpty, expected.success, "\(expected.name): bloqueio diverge do servidor; iOS = \(codes.sorted())")
            XCTAssertTrue(Set(expected.issueCodes).isSubset(of: codes), "\(expected.name): faltam \(Set(expected.issueCodes).subtracting(codes).sorted())")
            XCTAssertEqual(Set(issues.filter { $0.severity == .warning }.map(\.code)), Set(expected.warningCodes), expected.name)

            if let report = expected.report {
                let rendered = try ClinicalModelReportRenderer.render(draft)
                XCTAssertEqual(rendered, report, "\(expected.name): \(Self.firstDifference(rendered, report))")
            } else {
                XCTAssertThrowsError(try ClinicalModelReportRenderer.render(draft), expected.name)
            }

            let reencoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? NSDictionary
            XCTAssertEqual(reencoded, input as NSDictionary, "\(expected.name): o contrato iOS não reproduz o payload do shared")
        }
    }

    private static func firstDifference(_ lhs: String, _ rhs: String) -> String {
        let left = lhs.components(separatedBy: "\n")
        let right = rhs.components(separatedBy: "\n")
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : "<fim>"
            let b = index < right.count ? right[index] : "<fim>"
            if a != b { return "linha \(index + 1): iOS «\(a)» ≠ shared «\(b)»" }
        }
        return "sem diferença"
    }

    func testAbdomenBaseTextMatchesApprovedSharedDefault() throws {
        let (fixture, _) = try loadFixture()
        XCTAssertEqual(AbdomenTotalDopplerDraft.normalAbdomenReport, fixture.normalAbdomenReport)
        XCTAssertTrue(fixture.normalAbdomenReport.contains("Não há sinais de processo expansivo hepático."))
        guard case .abdomen(let draft)? = ClinicalModelDraft.empty(for: .abdomenTotalDoppler) else {
            return XCTFail("rascunho de abdome ausente")
        }
        XCTAssertEqual(draft.abdomenReport, fixture.normalAbdomenReport)
    }
}

final class ClinicalModelsIOSPreparationTests: XCTestCase {
    func testRolloutGateKeepsFiveModelsHiddenAndUnreachable() async {
        XCTAssertFalse(PendingClinicalModelContracts.isRolloutEnabled)
        XCTAssertTrue(PendingClinicalModelContracts.categories.isDisjoint(with: Set(ReportCategory.selectable)))
        await MainActor.run {
            let vm = GenerateViewModel()
            vm.category = .viasUrinarias
            for category in PendingClinicalModelContracts.categories {
                vm.category = category
                XCTAssertEqual(vm.category, .viasUrinarias, "\(category.rawValue) não pode ser aberta com o gate OFF")
            }
        }
    }

    func testHumanLabelsMatchSharedPresentation() {
        let expected: [ReportCategory: String] = [
            .abdomenTotalDoppler: "Abdome total com Doppler",
            .dopplerVenosoMmss: "Doppler venoso de membros superiores",
            .dopplerArterialMmss: "Doppler arterial de membros superiores",
            .torax: "Ultrassonografia de tórax",
            .quadrilInfantil: "Quadril infantil",
        ]
        for (category, label) in expected { XCTAssertEqual(category.label, label) }
    }

    func testLateralityResetsUnrequestedSideAndBlocksStaleSides() throws {
        guard case .venous(var venous)? = ClinicalModelDraft.empty(for: .dopplerVenosoMmss) else {
            return XCTFail("rascunho venoso ausente")
        }
        XCTAssertTrue(venous.right.examined)
        XCTAssertFalse(venous.left.examined)

        venous = venous.applyingLaterality(.bilateral)
        venous.left.deepSystem = .thrombosis
        venous.left.thrombosisPhase = .acute
        venous.left.catheter = .init(present: true, relation: .occlusive, segment: "veia axilar")
        venous = venous.applyingLaterality(.right)
        XCTAssertEqual(venous.left, DopplerVenosoMmssDraft.unexaminedSide)
        XCTAssertFalse(venous.activationIssues.contains { $0.field.hasPrefix("left") })

        venous.left.examined = true
        XCTAssertTrue(venous.activationIssues.contains { $0.code == "SIDE_OUTSIDE_LATERALITY" })

        guard case .arterial(var arterial)? = ClinicalModelDraft.empty(for: .dopplerArterialMmss) else {
            return XCTFail("rascunho arterial ausente")
        }
        arterial = arterial.applyingLaterality(.left)
        XCTAssertEqual(arterial.right, DopplerArterialMmssDraft.unexaminedSide)
        XCTAssertTrue(arterial.left.examined)
        arterial.right.examined = true
        XCTAssertTrue(arterial.activationIssues.contains { $0.code == "SIDE_OUTSIDE_LATERALITY" })
    }

    func testBilateralRendersSingleReportWithBothSections() throws {
        guard case .venous(var venous)? = ClinicalModelDraft.empty(for: .dopplerVenosoMmss) else {
            return XCTFail("rascunho venoso ausente")
        }
        venous = venous.applyingLaterality(.bilateral)
        for side in [\DopplerVenosoMmssDraft.right, \.left] {
            venous[keyPath: side].deepSystem = .patent
            venous[keyPath: side].superficialSystem = .patent
        }
        let text = try ClinicalModelReportRenderer.render(.venous(venous))
        XCTAssertEqual(text.components(separatedBy: "DOPPLER VENOSO DE MEMBRO SUPERIOR").count, 2)
        XCTAssertTrue(text.contains("Membro superior direito:"))
        XCTAssertTrue(text.contains("Membro superior esquerdo:"))
    }

    func testGrafConfirmationIsDroppedWhenSuggestionChanges() {
        let side = QuadrilInfantilDraft.Side(
            adequateStandardPlane: true, alphaDeg: 63, betaDeg: 47,
            bonyRoof: .normal, cartilaginousRoof: .normal, femoralHead: .centered,
            labrumPosition: .normal, coveragePercent: nil,
            grafClassification: .typeI, classificationConfirmed: true
        )
        var draft = QuadrilInfantilDraft(ageDays: 60, right: side, left: side, recommendation: nil, recommendationConfirmed: false)
        XCTAssertEqual(draft.reconcilingGrafConfirmation(), draft)

        draft.right.alphaDeg = 55
        let reconciled = draft.reconcilingGrafConfirmation()
        XCTAssertNil(reconciled.right.grafClassification)
        XCTAssertFalse(reconciled.right.classificationConfirmed)
        XCTAssertEqual(reconciled.left, side)
        XCTAssertTrue(reconciled.activationIssues.contains { $0.code == "GRAF_UNCONFIRMED" })

        draft.right.alphaDeg = 63
        draft.ageDays = nil
        XCTAssertNil(draft.reconcilingGrafConfirmation().right.grafClassification)
    }

    func testThrombosisPhaseClearsWhenThrombosisIsRemoved() {
        var side = DopplerVenosoMmssDraft.unexaminedSide
        side.examined = true
        side.deepSystem = .thrombosis
        side.thrombosisPhase = .acute
        side.phaseConfirmed = true
        XCTAssertEqual(side.reconcilingThrombosisPhase(), side)

        side.deepSystem = .patent
        let reconciled = side.reconcilingThrombosisPhase()
        XCTAssertEqual(reconciled.thrombosisPhase, .notApplicable)
        XCTAssertFalse(reconciled.phaseConfirmed)
    }

    func testAffectedVesselRenameCarriesItsVelocity() {
        var side = DopplerArterialMmssDraft.unexaminedSide
        side.examined = true
        side.status = .stenosis
        side.psvCms = ["artéria subcl": 250, "Artéria radial": 60]
        side.affectedVessel = "artéria subcl"

        let renamed = side.renamingAffectedVessel(to: "artéria subclávia esquerda")
        XCTAssertEqual(renamed.psvCms, ["artéria subclávia esquerda": 250, "Artéria radial": 60])

        let cleared = renamed.renamingAffectedVessel(to: nil)
        XCTAssertEqual(cleared.psvCms, ["Artéria radial": 60])

        side.affectedVessel = "Artéria radial"
        XCTAssertEqual(side.renamingAffectedVessel(to: "outra").psvCms["Artéria radial"], 60)
    }

    func testSubmissionMatchesServerNormalization() throws {
        guard case .arterial(var arterial)? = ClinicalModelDraft.empty(for: .dopplerArterialMmss) else {
            return XCTFail("rascunho arterial ausente")
        }
        arterial.right.status = .occlusion
        arterial.right.affectedVessel = "  artéria radial direita "
        arterial.right.psvCms = [" artéria braquial direita ": 62.5]
        arterial.right.distalPattern = "reenchimento distal\n"
        arterial.right.thoracicOutlet = .init(evaluated: false, maneuvers: "texto antigo", positions: "x", result: .positive, physicianConfirmed: true)

        var state = ClinicalModelWorkspaceState(draft: .arterial(arterial))
        guard case .arterial(let normalized) = state.submissionDraft else { return XCTFail() }
        XCTAssertEqual(normalized.right.affectedVessel, "artéria radial direita")
        XCTAssertEqual(normalized.right.psvCms, ["artéria braquial direita": 62.5])
        XCTAssertEqual(normalized.right.distalPattern, "reenchimento distal")
        XCTAssertNil(normalized.right.thoracicOutlet.maneuvers)

        try state.preparePreview()
        let serverJSON = """
        {"report":{"id":"r1","category_code":"DOPPLER_ARTERIAL_MMSS","status":"generated","content_revision":1,
        "review_status":"pending","physician_reviewed":false,"generated_output":"TEXTO DO SERVIDOR",
        "contract":\(String(decoding: try JSONEncoder().encode(state.submissionDraft), as: UTF8.self)),
        "warnings":[],"created_at":"2026-10-02T13:49:23.123Z"}}
        """
        let report = try ClinicalReportService.decoder.decode(
            ClinicalReportService.CreateResponse.self, from: Data(serverJSON.utf8)
        ).report
        try state.acceptCreatedReport(report)
        XCTAssertEqual(state.previewText, "TEXTO DO SERVIDOR")
    }

    func testServerResponseKeepsVesselKeysAndParsesPostgresTimestamps() throws {
        let json = """
        {"report":{"id":"r1","category_code":"DOPPLER_ARTERIAL_MMSS","status":"generated","content_revision":3,
        "review_status":"pending","physician_reviewed":false,"generated_output":"x",
        "contract":{"schemaVersion":1,"categoryCode":"DOPPLER_ARTERIAL_MMSS","physicianReviewed":false,"laterality":"right",
        "right":{"examined":true,"status":"normal","psvCms":{"arteria_radial":61},"percentageDataSufficient":false,"percentageConfirmed":false,"thoracicOutlet":{"evaluated":false}},
        "left":{"examined":false,"status":"normal","psvCms":{},"percentageDataSufficient":false,"percentageConfirmed":false,"thoracicOutlet":{"evaluated":false}}},
        "warnings":[{"code":"W","severity":"warning","path":"right","message":"m"}],"created_at":"2026-10-02T13:49:23.123Z"}}
        """
        let report = try ClinicalReportService.decoder.decode(
            ClinicalReportService.CreateResponse.self, from: Data(json.utf8)
        ).report
        guard case .arterial(let contract) = report.contract else { return XCTFail() }
        XCTAssertEqual(contract.right.psvCms, ["arteria_radial": 61])
        XCTAssertEqual(report.contentRevision, 3)
        XCTAssertEqual(report.warnings.first?.field, "right")

        let review = try ClinicalReportService.decoder.decode(
            ClinicalReportService.ReviewResponse.self,
            from: Data(#"{"ok":true,"contentRevision":3,"reviewStatus":"reviewed","reviewedAt":"2026-10-02T13:49:23.123456+00:00"}"#.utf8)
        )
        XCTAssertEqual(review.contentRevision, 3)
    }

    func testCreateRequestSendsVelocitiesInPreviewOrder() throws {
        var side = DopplerArterialMmssDraft.unexaminedSide
        side.psvCms = ["artéria ulnar": 1, "Artéria radial": 2, "Artéria axilar": 3, "artéria braquial direita": 4]
        let request = ClinicalReportService.CreateRequest(
            contract: .arterial(.init(laterality: .right, right: side, left: side)), writingStyleId: nil
        )
        let json = String(decoding: try ClinicalReportService.requestEncoder.encode(request), as: UTF8.self)
        let positions = side.psvCms.keys.sorted(by: <).map { try? XCTUnwrap(json.range(of: "\"\($0)\"")).lowerBound }
        XCTAssertEqual(positions.compactMap { $0 }, positions.compactMap { $0 }.sorted())
    }

    func testServerErrorsBecomeReadableAndKeepServerIssues() {
        let unavailable = ClinicalReportServiceError(status: 404, body: #"{"error":"clinical_models_v1_unavailable"}"#)
        XCTAssertEqual(unavailable.code, "clinical_models_v1_unavailable")
        XCTAssertTrue(unavailable.errorDescription?.contains("ainda não foram liberados") == true)

        let blocked = ClinicalReportServiceError(
            status: 422,
            body: #"{"error":"clinical_contract_incomplete","issues":[{"code":"GRAF_UNCONFIRMED","severity":"error","path":"right.classificationConfirmed","message":"A classificação calculada deve ser confirmada pelo médico."}]}"#
        )
        XCTAssertEqual(blocked.issues.map(\.code), ["GRAF_UNCONFIRMED"])
        XCTAssertTrue(blocked.errorDescription?.contains("A classificação calculada deve ser confirmada pelo médico.") == true)

        let unknown = ClinicalReportServiceError(status: 503, body: "<html>")
        XCTAssertNil(unknown.code)
        XCTAssertEqual(unknown.errorDescription, "Não foi possível concluir a operação (erro 503).")
    }

    func testNumberFieldParsesBrazilianDecimalsWithoutReformattingKeystrokes() {
        XCTAssertEqual(ClinicalNumberField.parse("1,1"), 1.1)
        XCTAssertEqual(ClinicalNumberField.parse("1,"), 1)
        XCTAssertEqual(ClinicalNumberField.parse(" 22.5 "), 22.5)
        XCTAssertNil(ClinicalNumberField.parse(""))
        XCTAssertNil(ClinicalNumberField.parse("abc"))
        XCTAssertNil(ClinicalNumberField.parse("nan"))
        XCTAssertEqual(ClinicalNumberField.format(1), "1")
        XCTAssertEqual(ClinicalNumberField.format(1.1), "1,1")
        XCTAssertEqual(ClinicalNumberField.format(1234.5), "1234,5")
        XCTAssertEqual(ClinicalNumberField.format(nil), "")
    }
}
