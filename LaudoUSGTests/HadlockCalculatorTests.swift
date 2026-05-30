import XCTest
@testable import LaudoUSG

final class HadlockCalculatorTests: XCTestCase {
    func testNormalIntergrowth() {
        let result = calculate(input(.normal), source: .intergrowth21st)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.formulaUsed, .hadlock4_1985)
        XCTAssertEqual(result?.percentileSourceUsed, .intergrowth21st)
        XCTAssertEqual(result?.sexUsedInLookup, .unisex)
        XCTAssertEqual(result?.sourceVersion, IntergrowthTable.version)
    }

    func testNormalHadlock() {
        let result = calculate(input(.normal), source: .hadlock1991)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.percentileSourceUsed, .hadlock1991)
        XCTAssertEqual(result?.sourceVersion, HadlockTable.version)
    }

    func testNormalWHO() throws {
        if WHOMulticentreTable.unisex.isEmpty {
            throw XCTSkip("WHO Multicentre table pending curation")
        }
        let result = calculate(input(.normal), source: .whoMulticentre2017)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.percentileSourceUsed, .whoMulticentre2017)
    }

    func testSmallIntergrowth() {
        let result = calculate(input(.small), source: .intergrowth21st)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isSGA == true || (result?.percentileValue ?? 50) < 20)
    }

    func testSmallHadlock() {
        let result = calculate(input(.small), source: .hadlock1991)
        XCTAssertNotNil(result)
        XCTAssertLessThan(result?.percentileValue ?? 100, 50)
    }

    func testSmallWHO() throws {
        if WHOMulticentreTable.unisex.isEmpty {
            throw XCTSkip("WHO Multicentre table pending curation")
        }
        let result = calculate(input(.small), source: .whoMulticentre2017)
        XCTAssertNotNil(result)
    }

    func testLargeIntergrowth() {
        let result = calculate(input(.large), source: .intergrowth21st)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result?.percentileValue ?? 0, 50)
    }

    func testLargeHadlock() {
        let result = calculate(input(.large), source: .hadlock1991)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result?.percentileValue ?? 0, 50)
    }

    func testLargeWHO() throws {
        if WHOMulticentreTable.unisex.isEmpty {
            throw XCTSkip("WHO Multicentre table pending curation")
        }
        let result = calculate(input(.large), source: .whoMulticentre2017)
        XCTAssertNotNil(result)
    }

    func testIntergrowthUsesUnisexEvenWhenMaleDetected() {
        let result = calculate(input(.normal, sex: .male), source: .intergrowth21st)
        XCTAssertEqual(result?.sexDetected, .male)
        XCTAssertEqual(result?.sexUsedInLookup, .unisex)
    }

    func testIntergrowthUsesUnisexEvenWhenFemaleDetected() {
        let result = calculate(input(.normal, sex: .female), source: .intergrowth21st)
        XCTAssertEqual(result?.sexDetected, .female)
        XCTAssertEqual(result?.sexUsedInLookup, .unisex)
    }

    func testHadlockUsesUnisexEvenWhenMaleDetected() {
        let result = calculate(input(.normal, sex: .male), source: .hadlock1991)
        XCTAssertEqual(result?.sexDetected, .male)
        XCTAssertEqual(result?.sexUsedInLookup, .unisex)
    }

    private enum CaseKind {
        case normal
        case small
        case large
    }

    private func input(_ kind: CaseKind, sex: Sex = .unisex) -> BiometryInput {
        switch kind {
        case .normal:
            BiometryInput(dbp: 72, cc: 280, ca: 260, cf: 56, igWeeks: 30, igDays: 2, sex: sex)
        case .small:
            BiometryInput(dbp: 65, cc: 245, ca: 215, cf: 50, igWeeks: 30, igDays: 0, sex: sex)
        case .large:
            BiometryInput(dbp: 82, cc: 310, ca: 310, cf: 62, igWeeks: 30, igDays: 0, sex: sex)
        }
    }

    private func calculate(input: BiometryInput, source: PercentileSource) -> BiometryResult? {
        HadlockCalculator.calculate(
            input,
            weightFormula: .hadlock4_1985,
            percentileSource: source
        )
    }
}
