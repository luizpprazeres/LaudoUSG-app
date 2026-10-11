import XCTest
@testable import LaudoUSG

/// W16B (andamento em etapas) e W17 (clarify) — contrato com o JSON real da API
/// (`packages/shared/src/schemas/generate.ts` e `validator.ts`).
@MainActor
final class GenerationProgressClarifyTests: XCTestCase {
    private let reportId = "6f1c1f1e-3b0a-4f7e-9d7c-1a2b3c4d5e6f"

    private func decodeEvent(_ json: String) throws -> GenerateSSEEvent {
        try JSONDecoder.api.decode(GenerateSSEEvent.self, from: Data(json.utf8))
    }

    private func encodedJSON(_ request: GenerateRequest) throws -> [String: Any] {
        let data = try JSONEncoder.api.encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private var clarifyJSON: String {
        #"""
        {"type":"clarify","ts":"2026-10-11T12:00:00Z","questions":[
          {"id":"confuso_0","question":"Você quis dizer o quê neste trecho? \"rim com cisto\" (lateralidade)","expects":"text"},
          {"id":"confuso_1","question":"Qual a medida do baço?","expects":"number","target_field":"baco.medida"},
          {"id":"confuso_2","question":"Terceira pergunta","expects":"text"}
        ]}
        """#
    }

    // MARK: - Decode

    func testClarifyDecodesRealApiShape() throws {
        guard case .clarify(let payload) = try decodeEvent(clarifyJSON) else {
            return XCTFail("clarify não decodificou")
        }
        XCTAssertEqual(payload.questions.count, 3)
        XCTAssertEqual(payload.questions[0].id, "confuso_0")
        XCTAssertTrue(payload.questions[0].question.hasPrefix("Você quis dizer"))
        XCTAssertEqual(payload.questions[1].expects, "number")
        XCTAssertEqual(payload.questions[1].targetField, "baco.medida")
    }

    func testStageWithStepsDecodes() throws {
        let json = #"{"type":"stage","ts":null,"stage":"interpretando","label":"Lendo o ditado… 6 s","step":2,"steps":4,"elapsed_ms":6200}"#
        guard case .stage(let payload) = try decodeEvent(json) else { return XCTFail() }
        XCTAssertEqual(payload.step, 2)
        XCTAssertEqual(payload.steps, 4)
        XCTAssertEqual(payload.elapsedMs, 6200)
    }

    func testLegacyStageWithoutStepsStillDecodes() throws {
        let json = #"{"type":"stage","ts":null,"stage":"montando","label":"Montando o laudo…"}"#
        guard case .stage(let payload) = try decodeEvent(json) else { return XCTFail() }
        XCTAssertNil(payload.step)
        XCTAssertEqual(payload.label, "Montando o laudo…")
    }

    func testDoneWithTimingsDecodes() throws {
        let json = #"{"type":"done","ts":null,"report_id":"r-1","final_text":"Laudo.","timings":{"recebido_ms":120,"lendo_ms":400,"montando_ms":null,"texto_ms":null,"total_ms":8100}}"#
        guard case .done(let payload) = try decodeEvent(json) else { return XCTFail() }
        XCTAssertEqual(payload.timings?.totalMs, 8100)
        XCTAssertNil(payload.timings?.montandoMs)
    }

    func testMalformedTimingsDoNotDropDone() throws {
        let json = #"{"type":"done","ts":null,"report_id":"r-1","final_text":"Laudo.","timings":"oops"}"#
        guard case .done(let payload) = try decodeEvent(json) else { return XCTFail("done perdido") }
        XCTAssertEqual(payload.finalText, "Laudo.")
        XCTAssertNil(payload.timings)
    }

    // MARK: - Andamento

    func testLabelLosesServerClock() {
        XCTAssertEqual(GenerateViewModel.semRelogio("Lendo o ditado… 12 s"), "Lendo o ditado…")
        XCTAssertEqual(GenerateViewModel.semRelogio("Montando o laudo…"), "Montando o laudo…")
    }

    func testStageWithStepFeedsIndicator() throws {
        let vm = GenerateViewModel()
        vm.inputText = "Fígado normal."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        vm.handle(event: try decodeEvent(#"{"type":"stage","ts":null,"stage":"interpretando","label":"Lendo o ditado… 9 s","step":2,"steps":4,"elapsed_ms":9000}"#))
        XCTAssertEqual(vm.generationStep, 2)
        XCTAssertEqual(vm.generationSteps, 4)
        XCTAssertEqual(vm.currentStatusMessage, "Lendo o ditado…")
        let started = try XCTUnwrap(vm.generationStartedAt)
        XCTAssertEqual(Date().timeIntervalSince(started), 9, accuracy: 1)
    }

    func testStageWithoutStepKeepsLegacyBehaviour() throws {
        let vm = GenerateViewModel()
        vm.inputText = "Fígado normal."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        vm.handle(event: try decodeEvent(#"{"type":"stage","ts":null,"stage":"montando","label":"Montando o laudo… 3 s"}"#))
        XCTAssertNil(vm.generationStep)
        XCTAssertEqual(vm.currentStatusMessage, "Montando o laudo… 3 s")
    }

    // MARK: - Clarify

    private func clarifyingViewModel() throws -> GenerateViewModel {
        let vm = GenerateViewModel()
        vm.category = .abdomenTotal
        vm.inputText = "Rim com cisto."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        vm.handle(event: try decodeEvent(#"{"type":"open","ts":null,"report_id":"\#(reportId)"}"#))
        vm.handle(event: try decodeEvent(clarifyJSON))
        return vm
    }

    func testClarifyShowsAtMostTwoQuestionsAndLeavesGenerating() throws {
        let vm = try clarifyingViewModel()
        guard case .clarifying(let questions) = vm.phase else { return XCTFail("fase \(vm.phase)") }
        XCTAssertEqual(questions.map(\.id), ["confuso_0", "confuso_1"])
        XCTAssertEqual(vm.clarifyReportId, reportId)
        XCTAssertFalse(vm.phase.isBusy)
        XCTAssertEqual(vm.currentStatusMessage, "")
        XCTAssertNil(vm.lastError)
    }

    func testSubmitRequiresANonEmptyAnswer() throws {
        let vm = try clarifyingViewModel()
        XCTAssertFalse(vm.canSubmitClarify)
        vm.clarifyAnswers["confuso_0"] = "   "
        XCTAssertFalse(vm.canSubmitClarify)
        vm.clarifyAnswers["confuso_0"] = "rim direito"
        XCTAssertTrue(vm.canSubmitClarify)
    }

    func testCancelClarifyReturnsToAchados() throws {
        let vm = try clarifyingViewModel()
        vm.cancelClarify()
        XCTAssertEqual(vm.phase, .ready)
        XCTAssertEqual(vm.activeTab, .achados)
        XCTAssertTrue(vm.clarifyQuestions.isEmpty)
        XCTAssertNil(vm.clarifyReportId)
    }

    func testClarifyWithoutOpenFailsInsteadOfHanging() throws {
        let vm = GenerateViewModel()
        vm.inputText = "Rim com cisto."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        vm.handle(event: try decodeEvent(clarifyJSON))
        guard case .error = vm.phase else { return XCTFail("fase \(vm.phase)") }
        XCTAssertNotNil(vm.lastError)
    }

    func testResumeRequestEncodesReportIdAndAnswers() throws {
        let json = try encodedJSON(GenerateRequest(
            rawInput: "Rim com cisto.",
            categoryHint: .abdomenTotal,
            resumeFromReportId: reportId,
            clarifyAnswers: [ClarifyAnswer(questionId: "confuso_0", answer: "rim direito")]
        ))
        XCTAssertEqual(json["resume_from_report_id"] as? String, reportId)
        let answers = try XCTUnwrap(json["clarify_answers"] as? [[String: String]])
        XCTAssertEqual(answers, [["question_id": "confuso_0", "answer": "rim direito"]])
    }

    // MARK: - Erros de stream

    func testTimeoutBecomesReadableMessage() {
        let message = GenerationStreamError.message(for: URLError(.timedOut))
        XCTAssertTrue(message.contains("2 minutos"))
        let wrapped = GenerationStreamError.message(for: APIError.transport(URLError(.notConnectedToInternet)))
        XCTAssertTrue(wrapped.contains("Sem conexão"))
    }
}
