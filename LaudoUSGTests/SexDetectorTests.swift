import XCTest
@testable import LaudoUSG

final class SexDetectorTests: XCTestCase {
    func testMaleExternalGenitalia() {
        XCTAssertEqual(SexDetector.detect("Genitália masculina identificada."), .male)
    }

    func testMaleSex() {
        XCTAssertEqual(SexDetector.detect("Sexo masculino."), .male)
    }

    func testScrotalSac() {
        XCTAssertEqual(SexDetector.detect("Saco escrotal visualizado."), .male)
    }

    func testFetalPenis() {
        XCTAssertEqual(SexDetector.detect("Pênis fetal observado."), .male)
    }

    func testFemaleExternalGenitalia() {
        XCTAssertEqual(SexDetector.detect("Genitália feminina identificada."), .female)
    }

    func testFemaleSex() {
        XCTAssertEqual(SexDetector.detect("Sexo feminino."), .female)
    }

    func testLabia() {
        XCTAssertEqual(SexDetector.detect("Grandes lábios observados."), .female)
    }

    func testFemaleFetus() {
        XCTAssertEqual(SexDetector.detect("Feto do sexo feminino."), .female)
    }

    func testNoVisibleGenitalia() {
        XCTAssertEqual(SexDetector.detect("Sem genitália visível."), .unisex)
    }

    func testGenitaliaNotSeen() {
        XCTAssertEqual(SexDetector.detect("Genitália não visualizada por posição."), .unisex)
    }

    func testEmpty() {
        XCTAssertEqual(SexDetector.detect(""), .unisex)
    }

    func testGenericFetus() {
        XCTAssertEqual(SexDetector.detect("Feto único em apresentação cefálica."), .unisex)
    }
}
