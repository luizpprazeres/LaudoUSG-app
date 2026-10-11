import XCTest
@testable import LaudoUSG

/// "Ajustar laudo" (W18): contrato do `/api/edit`, diff da prévia, recusa com o
/// laudo intacto, aplicar/descartar/desfazer.
@MainActor
final class AdjustLaudoTests: XCTestCase {
    private let reportId = "6f1c1f1e-3b0a-4f7e-9d7c-1a2b3c4d5e6f"

    private let base = """
    ACHADOS:
    Fígado de dimensões normais.
    Rins tópicos, de dimensões normais, sem imagens de cálculos ou cistos.

    CONCLUSÃO:
    Exame dentro dos limites da normalidade.
    """

    private let edited = """
    ACHADOS:
    Fígado de dimensões normais.
    Rins tópicos, de dimensões normais, sem imagens de cálculos. Cisto simples no rim direito, medindo 2,0 cm.

    CONCLUSÃO:
    Cisto simples no rim direito.
    """

    // MARK: - Contrato

    func testRequestEncodesSnakeCase() throws {
        let data = try JSONEncoder.api.encode(EditReportRequest(reportId: reportId, instruction: "troque", target: "both"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["report_id"] as? String, reportId)
        XCTAssertEqual(json["instruction"] as? String, "troque")
        XCTAssertEqual(json["target"] as? String, "both")
    }

    func testResponseDecodesServerJSON() throws {
        let json = #"""
        {"edited_text":"A\nB","changed_lines":[{"line":2,"before":"X","after":null,"section":"conclusion"}],"accepted":false,"reason":"edição ampla — confirme"}
        """#
        let response = try JSONDecoder.api.decode(EditReportResponse.self, from: Data(json.utf8))
        XCTAssertFalse(response.accepted)
        XCTAssertEqual(response.editedText, "A\nB")
        XCTAssertEqual(response.changedLines.first?.after, nil)
        XCTAssertEqual(response.changedLines.first?.section, "conclusion")
        XCTAssertEqual(response.reason, "edição ampla — confirme")
    }

    func testEditRequiresAIConsent() {
        XCTAssertTrue(AIConsentPolicy.requiresPermission(path: "/api/edit"))
    }

    // MARK: - Alvo automático

    func testAutomaticTarget() {
        XCTAssertEqual(AdjustTargetChoice.inferTarget(from: "acrescente cisto no rim direito"), .body)
        XCTAssertEqual(AdjustTargetChoice.inferTarget(from: "na conclusão, tire o item 2"), .conclusion)
        XCTAssertEqual(AdjustTargetChoice.inferTarget(from: "Impressão: troque por colelitíase"), .conclusion)
        XCTAssertEqual(AdjustTargetChoice.inferTarget(from: "corrija o corpo e a conclusão"), .both)
        XCTAssertEqual(AdjustTargetChoice.conclusion.resolve(for: "qualquer coisa"), .conclusion)
    }

    // MARK: - Motivos de recusa do servidor

    func testRejectionMessagesForEveryServerReason() {
        let conclusaoNormal = AdjustRejection.from(reason: "achado novo com conclusão normal — confirme", target: .body)
        XCTAssertEqual(conclusaoNormal.retryTarget, .both)
        XCTAssertTrue(conclusaoNormal.title.contains("contraditória"))

        let ampla = AdjustRejection.from(reason: "edição ampla — confirme", target: .body)
        XCTAssertNil(ampla.retryTarget)
        XCTAssertTrue(ampla.message.contains("3 linhas"))

        let soCorpo = AdjustRejection.from(reason: "mudança na conclusão (você pediu só o corpo) — confirme", target: .body)
        XCTAssertEqual(soCorpo.retryTarget, .both)
        XCTAssertEqual(soCorpo.retryLabel, "Permitir mexer na conclusão")

        let soConclusao = AdjustRejection.from(reason: "mudança fora da conclusão — confirme", target: .conclusion)
        XCTAssertEqual(soConclusao.retryLabel, "Permitir mexer no corpo")

        let nada = AdjustRejection.from(reason: "sem alteração", target: .body)
        XCTAssertNil(nada.retryTarget)

        let desconhecido = AdjustRejection.from(reason: "outra coisa", target: .both)
        XCTAssertTrue(desconhecido.message.contains("outra coisa"))
        XCTAssertNil(desconhecido.retryTarget)
    }

    // MARK: - Diff

    func testDiffPairsReplacedLinesAndHighlightsOnlyChangedWords() {
        let changes = LaudoDiff.changes(from: base, to: edited)
        XCTAssertEqual(changes.count, 2)
        let rim = changes[0]
        XCTAssertEqual(rim.kind, .replaced)
        XCTAssertEqual(rim.line, 3)
        XCTAssertEqual(rim.beforeText, "Rins tópicos, de dimensões normais, sem imagens de cálculos ou cistos.")
        XCTAssertTrue(rim.afterText.hasSuffix("medindo 2,0 cm."))
        XCTAssertEqual(rim.before.first?.changed, false, "o começo igual não é destacado")
        XCTAssertTrue(rim.before.contains { $0.changed && $0.text.contains("cistos") })
        XCTAssertTrue(rim.after.contains { $0.changed && $0.text.contains("Cisto simples") })
        XCTAssertEqual(changes[1].afterText, "Cisto simples no rim direito.")
    }

    func testDiffOfIdenticalTextIsEmpty() {
        XCTAssertTrue(LaudoDiff.changes(from: base, to: base + "\n").isEmpty)
    }

    func testDiffInsertionAndRemoval() {
        let inserted = LaudoDiff.changes(from: "A\nB", to: "A\nNova\nB")
        XCTAssertEqual(inserted.map(\.kind), [.inserted])
        XCTAssertEqual(inserted.first?.afterText, "Nova")

        let removed = LaudoDiff.changes(from: "A\nVelha\nB", to: "A\nB")
        XCTAssertEqual(removed.map(\.kind), [.removed])
        XCTAssertEqual(removed.first?.beforeText, "Velha")
    }

    func testProposalFromChangedLines() {
        let proposal = LaudoDiff.proposal(from: [
            EditReportChangedLine(line: 3, before: "sem cistos.", after: "com cisto.", section: "body"),
            EditReportChangedLine(line: 5, before: nil, after: "", section: "body"),
        ])
        XCTAssertEqual(proposal.count, 1, "linha em branco sozinha não aparece")
        XCTAssertEqual(proposal.first?.kind, .replaced)
    }

    // MARK: - Fluxo

    private func makeViewModel(_ editor: StubEditor) -> (GenerateViewModel, SaveSpy) {
        let saves = SaveSpy()
        let vm = GenerateViewModel(reportEditor: editor)
        vm.saveFinalOutput = { id, text in await saves.record(id, text) }
        vm.editedLaudoText = base
        vm.lastReportId = reportId
        vm.phase = .done(reportId: reportId)
        return (vm, saves)
    }

    func testAcceptedEditShowsPreviewWithoutTouchingLaudoUntilApply() async {
        let editor = StubEditor(response: EditReportResponse(editedText: edited, changedLines: [], accepted: true, reason: nil))
        let (vm, saves) = makeViewModel(editor)
        vm.presentAdjust(listen: false)
        vm.adjust.instruction = "acrescente cisto simples de 2 cm no rim direito"

        await vm.submitAdjust()

        XCTAssertEqual(editor.calls.first?.target, .body)
        XCTAssertEqual(editor.calls.first?.reportId, reportId)
        XCTAssertEqual(saves.texts.first, base, "salva a versão da tela antes de pedir o ajuste")
        guard case .preview(_, let changes) = vm.adjust.phase else { return XCTFail("esperava prévia") }
        XCTAssertEqual(changes.count, 2)
        XCTAssertEqual(vm.editedLaudoText, base, "a prévia não muda o laudo")

        vm.applyAdjust()
        XCTAssertEqual(vm.editedLaudoText, edited)
        XCTAssertFalse(vm.adjust.isPresented)
        XCTAssertNotNil(vm.adjustUndoText)

        vm.undoAdjust()
        XCTAssertEqual(vm.editedLaudoText, base)
        XCTAssertNil(vm.adjustUndoText)
    }

    func testDiscardingAcceptedPreviewRestoresServerCopy() async throws {
        let editor = StubEditor(response: EditReportResponse(editedText: edited, changedLines: [], accepted: true, reason: nil))
        let (vm, saves) = makeViewModel(editor)
        vm.presentAdjust(listen: false)
        vm.adjust.instruction = "acrescente cisto"
        await vm.submitAdjust()

        vm.dismissAdjust()
        _ = await vm.flushLaudoAutosave()

        XCTAssertEqual(vm.editedLaudoText, base)
        XCTAssertEqual(saves.texts.last, base, "o servidor já tinha gravado o ajuste: regrava o original")
    }

    func testRejectedEditKeepsLaudoIntactAndExplainsWhy() async {
        let editor = StubEditor(response: EditReportResponse(
            editedText: base,
            changedLines: [EditReportChangedLine(line: 3, before: "sem cistos", after: "com cisto", section: "body")],
            accepted: false,
            reason: "achado novo com conclusão normal — confirme"
        ))
        let (vm, _) = makeViewModel(editor)
        vm.presentAdjust(listen: false)
        vm.adjust.instruction = "acrescente cisto"
        await vm.submitAdjust()

        guard case .rejected(let rejection, let proposal) = vm.adjust.phase else { return XCTFail("esperava recusa") }
        XCTAssertEqual(rejection.retryTarget, .both)
        XCTAssertEqual(proposal.count, 1)
        XCTAssertEqual(vm.editedLaudoText, base)
        XCTAssertNil(vm.adjustUndoText)
        vm.applyAdjust()
        XCTAssertEqual(vm.editedLaudoText, base, "recusa não tem o que aplicar")

        await vm.submitAdjust(targetOverride: .both)
        XCTAssertEqual(editor.calls.last?.target, .both)
    }

    func testServerErrorBecomesFriendlyFailure() async {
        let editor = StubEditor(error: APIError.http(status: 404, body: #"{"error":"edit_incremental_disabled"}"#))
        let (vm, _) = makeViewModel(editor)
        vm.presentAdjust(listen: false)
        vm.adjust.instruction = "troque o fígado"
        await vm.submitAdjust()
        XCTAssertEqual(vm.adjust.phase, .failed(ReportEditError.disabled.errorDescription!))
        XCTAssertEqual(vm.editedLaudoText, base)
    }

    func testFailedSaveAbortsBeforeCallingServer() async {
        let editor = StubEditor(response: EditReportResponse(editedText: edited, changedLines: [], accepted: true, reason: nil))
        let (vm, _) = makeViewModel(editor)
        vm.saveFinalOutput = { _, _ in throw URLError(.notConnectedToInternet) }
        vm.presentAdjust(listen: false)
        vm.adjust.instruction = "troque o fígado"
        await vm.submitAdjust()
        XCTAssertTrue(editor.calls.isEmpty)
        guard case .failed = vm.adjust.phase else { return XCTFail("esperava falha") }
    }

    func testAnchorGoesInsideInstruction() async {
        let editor = StubEditor(response: EditReportResponse(editedText: edited, changedLines: [], accepted: true, reason: nil))
        let (vm, _) = makeViewModel(editor)
        vm.presentAdjust(anchor: "Fígado de dimensões normais.", listen: false)
        vm.adjust.instruction = "fígado aumentado, 17 cm"
        await vm.submitAdjust()
        XCTAssertEqual(editor.calls.first?.instruction, "No trecho que começa com \u{201C}Fígado de dimensões normais\u{201D}: fígado aumentado, 17 cm")
        XCTAssertEqual(vm.adjust.sentInstruction, "fígado aumentado, 17 cm", "o eco na prévia é só o que o médico disse")
    }

    /// Formato que passou na bancada W18 (12/12): só o começo da linha, para o
    /// "sem imagens de cálculos ou cistos" do trecho não ligar o guard de achado.
    func testAnchorStartKeepsOnlyTheBeginningOfTheLine() {
        XCTAssertEqual(AdjustLaudoModel.anchorStart("Rins tópicos, de forma, contornos e dimensões normais, sem imagens de cálculos ou cistos."), "Rins tópicos")
        XCTAssertEqual(AdjustLaudoModel.anchorStart("Rim direito com diâmetros longitudinais e anteroposterior dentro dos limites normais."), "Rim direito com diâmetros longitudinais")
        XCTAssertEqual(AdjustLaudoModel.anchorStart("O índice do líquido amniótico mede 10,4 cm."), "O índice do líquido amniótico")
        XCTAssertEqual(AdjustLaudoModel.anchorStart("1. Gestação tópica, única, em torno de 30 semanas."), "Gestação tópica")
        XCTAssertEqual(AdjustLaudoModel.anchorStart("2) Rins sem alterações ecográficas."), "Rins sem alterações ecográficas")
        XCTAssertEqual(AdjustLaudoModel.anchorStart("TÉCNICA: Exame realizado com transdutor convexo."), "TÉCNICA")
        XCTAssertFalse(AdjustLaudoModel.anchorStart("Rins tópicos, sem imagens de cálculos ou cistos.").contains("cisto"))
    }

    func testCannotAdjustWithoutSavedReport() {
        let vm = GenerateViewModel(reportEditor: StubEditor(error: URLError(.unknown)))
        vm.editedLaudoText = base
        XCTAssertFalse(vm.canAdjustLaudo)
        vm.presentAdjust(listen: false)
        XCTAssertFalse(vm.adjust.isPresented)
    }
}

@MainActor
private final class StubEditor: ReportEditing {
    struct Call { let reportId: String; let instruction: String; let target: AdjustTarget }
    private let result: Result<EditReportResponse, Error>
    private(set) var calls: [Call] = []

    init(response: EditReportResponse) { result = .success(response) }
    init(error: Error) { result = .failure(error) }

    func edit(reportId: String, instruction: String, target: AdjustTarget) async throws -> EditReportResponse {
        calls.append(Call(reportId: reportId, instruction: instruction, target: target))
        return try result.get()
    }
}

@MainActor
private final class SaveSpy {
    private(set) var texts: [String] = []
    func record(_ id: String, _ text: String) { texts.append(text) }
}
