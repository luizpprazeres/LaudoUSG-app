import XCTest
@testable import LaudoUSG

/// Opções B e D do estudo de transcrição de 12/10/2026: captura do motor de voz no request e
/// a faixa "Revisão do ditado" (contrato com POST /api/ditado/revisar).
@MainActor
final class DitadoReviewTests: XCTestCase {
    private func s(_ start: Int, _ end: Int, _ original: String, _ rep: String?, _ kind: String, auto: Bool) -> DitadoSuggestion {
        DitadoSuggestion(start: start, end: end, original: original, replacement: rep, kind: kind, confidence: 0.9, automatic: auto)
    }

    func testDecodesServerResponse() throws {
        let json = #"{"enabled":true,"suggestions":[{"start":14,"end":17,"original":"C e","replacement":"sem","kind":"negacao","confidence":0.84,"automatic":true},{"start":30,"end":38,"original":"7.34 0,1","replacement":null,"kind":"medida","confidence":1,"automatic":false}]}"#
        let r = try JSONDecoder.api.decode(DitadoReviewResponse.self, from: Data(json.utf8))
        XCTAssertTrue(r.enabled)
        XCTAssertEqual(r.suggestions.count, 2)
        XCTAssertNil(r.suggestions[1].replacement)
    }

    func testAppliesAutomaticAndShiftsTheRest() {
        // "Mama esquerda C e nódulos. 6 sinais de mastite."
        let text = "Mama esquerda C e nódulos. 6 sinais de mastite."
        let ns = text as NSString
        let ce = ns.range(of: "C e"), seis = ns.range(of: "6 sinais")
        let out = DitadoReviewEngine.apply([
            s(ce.location, ce.location + ce.length, "C e", "sem", "negacao", auto: true),
            s(seis.location, seis.location + 1, "6", "sem", "negacao", auto: false),
        ], to: text, uncertainWords: [])
        XCTAssertEqual(out.text, "Mama esquerda sem nódulos. 6 sinais de mastite.")
        XCTAssertEqual(out.state.applied.count, 1)
        XCTAssertEqual(out.state.pending.count, 1)
        // a sugestão pendente andou com a troca ("C e" → "sem" = 0 de diferença aqui) e ainda aponta o "6"
        let p = out.state.pending[0]
        XCTAssertEqual((out.text as NSString).substring(with: NSRange(location: p.start, length: p.end - p.start)), "6")
    }

    func testSkipsAutomaticWhenTextDoesNotMatch() {
        let out = DitadoReviewEngine.apply([s(0, 3, "C e", "sem", "negacao", auto: true)], to: "Sem nódulos", uncertainWords: [])
        XCTAssertEqual(out.text, "Sem nódulos")
        XCTAssertTrue(out.state.applied.isEmpty)
    }

    func testDismissedSuggestionDoesNotComeBack() {
        let sug = s(0, 1, "6", "sem", "negacao", auto: false)
        let out = DitadoReviewEngine.apply([sug], to: "6 sinais", uncertainWords: [], dismissed: [sug.dismissKey])
        XCTAssertTrue(out.state.pending.isEmpty)
    }

    func testReplaceNearPicksClosestOccurrence() {
        let t = "6 sinais de A. 6 sinais de B."
        XCTAssertEqual(DitadoReviewEngine.replaceNear(in: t, original: "6", with: "sem", near: 15), "6 sinais de A. sem sinais de B.")
        XCTAssertNil(DitadoReviewEngine.replaceNear(in: t, original: "xyz", with: "a", near: 0))
    }

    func testPhraseShowsFollowingWords() {
        let t = "cálculo de 1,2 cm, 6 sinais de colecistite. Mama."
        let p = DitadoReviewEngine.phrase(original: "6", replacement: "sem", near: 19, in: t)
        XCTAssertEqual(p.from, "6 sinais de colecistite")
        XCTAssertEqual(p.to, "sem sinais de colecistite")
        let q = DitadoReviewEngine.phrase(original: "6 e 20", replacement: "120", near: 0, in: "pico de 6 e 20 cm/s.")
        XCTAssertEqual(q.to, "120 cm/s")
    }

    func testUncertainWordsOnlyIfStillInText() {
        let out = DitadoReviewEngine.apply([], to: "fossa poplítea", uncertainWords: ["apoplítea", "poplítea"])
        XCTAssertEqual(out.state.uncertainWords, ["poplítea"])
    }

    func testAsrCaptureBufferAndRequestEncoding() throws {
        var b = AsrCaptureBuffer()
        XCTAssertNil(b.payload)
        b.append(text: "100 sinais de colecistite", words: [AsrWord(w: "100", c: 0.41, s: 1.2), AsrWord(w: "sinais", c: 0.99, s: 1.5)], provider: "deepgram")
        b.append(text: "rim normal", words: [], provider: "apple")
        XCTAssertEqual(b.payload?.provedor, "outro")
        XCTAssertEqual(b.payload?.texto, "100 sinais de colecistite\nrim normal")
        XCTAssertEqual(b.uncertainWords, ["100"])
        let req = GenerateRequest(rawInput: "sem sinais de colecistite", categoryHint: .abdomenTotal, asrOriginal: b.payload)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder.api.encode(req)) as? [String: Any])
        let asr = try XCTUnwrap(obj["asr_original"] as? [String: Any])
        XCTAssertEqual(asr["provedor"] as? String, "outro")
        XCTAssertEqual((asr["palavras"] as? [[String: Any]])?.first?["w"] as? String, "100")
        // sem ditado, o campo nem vai
        let vazio = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder.api.encode(GenerateRequest(rawInput: "digitado"))) as? [String: Any])
        XCTAssertNil(vazio["asr_original"])
    }
}
