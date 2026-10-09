import XCTest
@testable import LaudoUSG

@MainActor
final class FreeCategoryRoutingTests: XCTestCase {
    private func encodedJSON(_ request: GenerateRequest) throws -> [String: Any] {
        let data = try JSONEncoder.api.encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decodeEvent(_ json: String) throws -> GenerateSSEEvent {
        try JSONDecoder.api.decode(GenerateSSEEvent.self, from: Data(json.utf8))
    }

    private func structuredEvent(category: String, tipoExame: String? = nil) throws -> GenerateSSEEvent {
        let tipo = tipoExame.map { #","tipo_exame":"\#($0)""# } ?? ""
        return try decodeEvent(#"""
        {"type":"structured","ts":"2026-10-08T12:00:00Z","payload":{"schema_version":"v1","categoria_detectada":"\#(category)"\#(tipo),"achados":{},"comandos_do_medico":[],"trechos_confusos":[],"nivel_de_confianca":"alta"}}
        """#)
    }

    private func doneEvent(text: String = "Tireoide de dimensões normais.") throws -> GenerateSSEEvent {
        try decodeEvent(#"{"type":"done","ts":null,"report_id":"r-1","final_text":"\#(text)"}"#)
    }

    // MARK: - Request

    func testFreeCategoryRequestAsksBackendToRoute() throws {
        let json = try encodedJSON(GenerateRequest(rawInput: "tireoide normal", categoryHint: .livre))
        XCTAssertEqual(json["category_hint"] as? String, "LIVRE")
        XCTAssertEqual(json["route_free_category"] as? Bool, true)
    }

    func testDirectCategoryRequestOmitsRouteFlag() throws {
        let json = try encodedJSON(GenerateRequest(rawInput: "tireoide normal", categoryHint: .tireoide))
        XCTAssertEqual(json["category_hint"] as? String, "TIREOIDE")
        XCTAssertNil(json["route_free_category"])
    }

    func testViewModelBuildsFreeRequestAndRecordsRequestedCategory() throws {
        let vm = GenerateViewModel()
        vm.category = .livre
        vm.inputText = "Tireoide com dimensões normais."
        let request = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        XCTAssertEqual(request.categoryHint, .livre)
        XCTAssertEqual(request.routeFreeCategory, true)
        XCTAssertEqual(vm.requestedCategory, .livre)
    }

    // MARK: - Ditado

    func testFreeCategoryForcesDeepgramEvenWithNativeEnginePreferred() {
        let vm = GenerateViewModel()
        vm.transcriptionEngine = .nativa
        let mic = vm.engine(for: .livre)
        XCTAssertTrue((mic as AnyObject) === vm.deepgram)
        XCTAssertEqual(vm.deepgram.categoryCode, "LIVRE")
    }

    // MARK: - Decoding

    func testStructuredEventExposesEffectiveCategoryFromCategoriaDetectada() throws {
        guard case .structured(let payload) = try structuredEvent(category: "TIREOIDE", tipoExame: "Tireoide") else {
            return XCTFail("esperava evento structured")
        }
        XCTAssertEqual(payload.effectiveCategoryCode, "TIREOIDE")
        XCTAssertEqual(payload.payload.tipoExame, "Tireoide")
    }

    func testStructuredEventAcceptsTopLevelEffectiveCategory() throws {
        let event = try decodeEvent(#"""
        {"type":"structured","ts":null,"effective_category":"MAMARIA","payload":{"categoria_detectada":"LIVRE"}}
        """#)
        guard case .structured(let payload) = event else { return XCTFail("esperava evento structured") }
        XCTAssertEqual(payload.effectiveCategoryCode, "MAMARIA")
    }

    func testStructuredEventWithoutCategoryYieldsNil() throws {
        let event = try decodeEvent(#"{"type":"structured","ts":null,"payload":{"achados":{}}}"#)
        guard case .structured(let payload) = event else { return XCTFail("esperava evento structured") }
        XCTAssertNil(payload.effectiveCategoryCode)
    }

    // MARK: - Rota no ViewModel

    func testFreeGenerationRoutedShowsNoticeAndUsesEffectiveCategory() throws {
        let vm = GenerateViewModel()
        vm.category = .livre
        vm.inputText = "Tireoide com dimensões normais."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)

        vm.handle(event: try structuredEvent(category: "TIREOIDE", tipoExame: "Tireoide"))
        XCTAssertEqual(vm.routedModelNotice, "Modelo identificado: \(ReportCategory.tireoide.label)")
        XCTAssertEqual(vm.effectiveCategory, .tireoide)
        XCTAssertEqual(vm.effectiveCategoryCode, "TIREOIDE")
        XCTAssertEqual(vm.category, .livre, "a categoria visual escolhida não muda")

        vm.handle(event: try doneEvent())
        XCTAssertEqual(vm.effectiveCategory, .tireoide)
        XCTAssertNotNil(vm.routedModelNotice)
    }

    func testFreeGenerationThatStaysFreeHasNoNotice() throws {
        let vm = GenerateViewModel()
        vm.category = .livre
        vm.inputText = "Exame qualquer."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)

        vm.handle(event: try structuredEvent(category: "LIVRE"))
        XCTAssertNil(vm.routedModelNotice)
        XCTAssertEqual(vm.effectiveCategory, .livre)
        XCTAssertEqual(vm.effectiveCategoryCode, "LIVRE")
    }

    func testRouteToCodeUnknownToAppKeepsGenericRulesButReportsCode() throws {
        let vm = GenerateViewModel()
        vm.category = .livre
        vm.inputText = "Exame qualquer."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)

        vm.handle(event: try structuredEvent(category: "NOVA_CATEGORIA", tipoExame: "Nova categoria"))
        XCTAssertEqual(vm.effectiveCategory, .livre)
        XCTAssertEqual(vm.effectiveCategoryCode, "NOVA_CATEGORIA")
        XCTAssertEqual(vm.routedModelNotice, "Modelo identificado: Nova categoria")
    }

    func testDirectCategoryIgnoresStructuredCategory() throws {
        let vm = GenerateViewModel()
        vm.category = .abdomenTotal
        vm.inputText = "Fígado normal."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)

        vm.handle(event: try structuredEvent(category: "TIREOIDE"))
        XCTAssertNil(vm.routedModelNotice)
        XCTAssertEqual(vm.effectiveCategory, .abdomenTotal)
        XCTAssertEqual(vm.effectiveCategoryCode, "ABDOMEN_TOTAL")
    }

    func testRouteIsClearedOnNewGenerationResetAndCategoryChange() throws {
        let vm = GenerateViewModel()
        vm.category = .livre
        vm.inputText = "Tireoide com dimensões normais."

        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        vm.handle(event: try structuredEvent(category: "TIREOIDE"))
        XCTAssertNotNil(vm.routedModelNotice)
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        XCTAssertNil(vm.routedModelNotice, "nova geração não herda a rota anterior")
        XCTAssertEqual(vm.effectiveCategory, .livre)

        vm.handle(event: try structuredEvent(category: "TIREOIDE"))
        vm.reset()
        XCTAssertNil(vm.routedModelNotice)
        XCTAssertNil(vm.requestedCategory)

        vm.inputText = "Tireoide com dimensões normais."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        vm.handle(event: try structuredEvent(category: "TIREOIDE"))
        vm.category = .mamaria
        XCTAssertNil(vm.routedModelNotice)
        XCTAssertEqual(vm.effectiveCategory, .mamaria)
        XCTAssertEqual(vm.effectiveCategoryCode, "MAMARIA")

        vm.handle(event: try structuredEvent(category: "TIREOIDE"))
        XCTAssertNil(vm.routedModelNotice, "evento atrasado da geração antiga não reacende a rota")
    }

    func testBackendErrorIsShownAndHidesNotice() throws {
        let vm = GenerateViewModel()
        vm.category = .livre
        vm.inputText = "Exame ambíguo."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)
        vm.handle(event: try structuredEvent(category: "TIREOIDE"))

        let message = "Não foi possível identificar o modelo do exame. Escolha a categoria."
        vm.handle(event: try decodeEvent(#"{"type":"error","ts":null,"code":"free_category_ambiguous","message":"\#(message)"}"#))
        XCTAssertEqual(vm.lastError, message)
        XCTAssertNil(vm.routedModelNotice)
    }

    func testBackendErrorWithoutMessageStillExplainsFailure() throws {
        let vm = GenerateViewModel()
        vm.category = .livre
        vm.inputText = "Exame ambíguo."
        _ = vm.prepareGeneration(writingStyleId: GenerateRequest.defaultWritingStyleId)

        vm.handle(event: try decodeEvent(#"{"type":"error","ts":null,"code":"free_category_ambiguous","message":" "}"#))
        XCTAssertEqual(vm.lastError, "Não foi possível gerar o laudo (free_category_ambiguous). Tente novamente.")
    }
}
