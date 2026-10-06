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

    func testIntergrowthRejectsAgeOutsideTableDomain() {
        XCTAssertNil(IntergrowthTable.lookup(igWeeks: 21, igDays: 6))
        XCTAssertNotNil(IntergrowthTable.lookup(igWeeks: 22, igDays: 0))
        XCTAssertNotNil(IntergrowthTable.lookup(igWeeks: 39, igDays: 6))
        XCTAssertNotNil(IntergrowthTable.lookup(igWeeks: 40, igDays: 0))
        XCTAssertNil(IntergrowthTable.lookup(igWeeks: 40, igDays: 1))
        XCTAssertNil(IntergrowthTable.lookup(igWeeks: 30, igDays: 7))

        XCTAssertNil(calculate(input(.normal, igWeeks: 20, igDays: 0), source: .intergrowth21st))
        XCTAssertNotNil(calculate(input(.normal, igWeeks: 22, igDays: 0), source: .intergrowth21st))
        XCTAssertNil(calculate(input(.normal, igWeeks: 40, igDays: 1), source: .intergrowth21st))
    }

    func testHadlockRejectsAgeOutsideTableDomain() {
        XCTAssertNil(HadlockTable.lookup(igWeeks: 23, igDays: 6))
        XCTAssertNotNil(HadlockTable.lookup(igWeeks: 24, igDays: 0))
        XCTAssertNotNil(HadlockTable.lookup(igWeeks: 40, igDays: 6))
        XCTAssertNotNil(HadlockTable.lookup(igWeeks: 41, igDays: 0))
        XCTAssertNil(HadlockTable.lookup(igWeeks: 41, igDays: 1))
        XCTAssertNil(HadlockTable.lookup(igWeeks: 30, igDays: -1))

        XCTAssertNil(calculate(input(.normal, igWeeks: 23, igDays: 6), source: .hadlock1991))
        XCTAssertNotNil(calculate(input(.normal, igWeeks: 41, igDays: 0), source: .hadlock1991))
        XCTAssertNil(calculate(input(.normal, igWeeks: 41, igDays: 1), source: .hadlock1991))
    }

    func testKnownResultsRemainStableInsideCurveDomain() {
        let intergrowth = calculate(input(.normal), source: .intergrowth21st)
        XCTAssertEqual(intergrowth?.weightGrams, 1_472)
        XCTAssertEqual(intergrowth?.percentileValue, 56)

        let hadlock = calculate(input(.normal), source: .hadlock1991)
        XCTAssertEqual(hadlock?.weightGrams, 1_472)
        XCTAssertEqual(hadlock?.percentileValue, 24)
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

    // MARK: - Normalização mm/cm por medida (achado #6 da auditoria de calculadoras)

    func testTermMeasurementsInCmAreNotMistakenForMm() {
        // CA de 35 cm e CC de 33,5 cm são valores de termo em cm; antes viravam 3,5 e 3,35.
        let inCm = BiometryInput(dbp: 9.2, cc: 33.5, ca: 35.0, cf: 7.2, igWeeks: 38, igDays: 0)
        let inMm = BiometryInput(dbp: 92, cc: 335, ca: 350, cf: 72, igWeeks: 38, igDays: 0)
        let a = calculate(inCm, source: .intergrowth21st)
        let b = calculate(inMm, source: .intergrowth21st)
        XCTAssertNotNil(a)
        XCTAssertEqual(a?.weightGrams, b?.weightGrams)
        XCTAssertEqual(a?.percentileValue, b?.percentileValue)
        XCTAssertGreaterThan(a?.weightGrams ?? 0, 2500, "peso de termo esperado")
    }

    func testNormalizeCmThresholdsPerMeasure() {
        XCTAssertEqual(HadlockCalculator.normalizeCm(35, measure: .ca), 35)      // 35 cm
        XCTAssertEqual(HadlockCalculator.normalizeCm(350, measure: .ca), 35)     // 350 mm
        XCTAssertEqual(HadlockCalculator.normalizeCm(33.5, measure: .cc), 33.5)  // 33,5 cm
        XCTAssertEqual(HadlockCalculator.normalizeCm(9.2, measure: .dbp), 9.2)   // 9,2 cm
        XCTAssertEqual(HadlockCalculator.normalizeCm(92, measure: .dbp), 9.2)    // 92 mm
        XCTAssertEqual(HadlockCalculator.normalizeCm(7.2, measure: .cf), 7.2)    // 7,2 cm
        XCTAssertEqual(HadlockCalculator.normalizeCm(14, measure: .cf), 1.4)     // 14 mm (14 semanas)
    }

    func testGestationalAgeByFemurAcceptsMmAndCm() {
        let fromMm = HadlockCalculator.gestationalAgeByFemur(cf: 56)
        let fromCm = HadlockCalculator.gestationalAgeByFemur(cf: 5.6)
        XCTAssertNotNil(fromMm)
        XCTAssertEqual(fromMm?.weeks, fromCm?.weeks)
        XCTAssertEqual(fromMm?.days, fromCm?.days)
        XCTAssertNotNil(HadlockCalculator.gestationalAgeByFemur(cf: 14), "14 mm (14 semanas) deve ser aceito")
    }

    // MARK: - WHO indisponível cai para o padrão

    func testWHOFallsBackToIntergrowthWhilePendingCuration() throws {
        if PercentileSource.whoMulticentre2017.isAvailable {
            throw XCTSkip("tabela WHO já curada; o fallback não se aplica")
        }
        let result = calculate(input(.normal), source: .whoMulticentre2017)
        XCTAssertNotNil(result, "preferência WHO salva não pode deixar o percentil nulo")
        XCTAssertEqual(result?.percentileSourceUsed, .intergrowth21st)
        XCTAssertEqual(result?.sourceVersion, IntergrowthTable.version)
        XCTAssertFalse(PercentileSource.allCases.filter(\.isAvailable).contains(.whoMulticentre2017))
    }

    private enum CaseKind {
        case normal
        case small
        case large
    }

    private func input(
        _ kind: CaseKind,
        sex: Sex = .unisex,
        igWeeks: Int? = nil,
        igDays: Int? = nil
    ) -> BiometryInput {
        switch kind {
        case .normal:
            BiometryInput(dbp: 72, cc: 280, ca: 260, cf: 56, igWeeks: igWeeks ?? 30, igDays: igDays ?? 2, sex: sex)
        case .small:
            BiometryInput(dbp: 65, cc: 245, ca: 215, cf: 50, igWeeks: igWeeks ?? 30, igDays: igDays ?? 0, sex: sex)
        case .large:
            BiometryInput(dbp: 82, cc: 310, ca: 310, cf: 62, igWeeks: igWeeks ?? 30, igDays: igDays ?? 0, sex: sex)
        }
    }

    private func calculate(_ input: BiometryInput, source: PercentileSource) -> BiometryResult? {
        HadlockCalculator.calculate(
            input,
            weightFormula: .hadlock4_1985,
            percentileSource: source
        )
    }
}
