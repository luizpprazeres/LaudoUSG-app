import XCTest
@testable import LaudoUSG

final class TIRADSCalculatorTests: XCTestCase {
    func testFocosEcogenicosAreAdditiveAndNoneDoesNotCancelRealFindings() {
        let result = TIRADSCalculator.calculate(.init(
            composicao: .solido,
            ecogenicidade: .muitoHipo,
            forma: .maisAlta,
            margem: .extensaoExtra,
            focosEcogenicos: [.nenhum, .macroCalcif, .perifericaContinua, .puntiformes, .macroCalcif],
            maiorEixoCm: 0.9
        ))

        XCTAssertEqual(result.pontos, 17)
        XCTAssertEqual(result.categoria, .tr5)
        XCTAssertTrue(result.recomendacao.contains("anual"))
        XCTAssertFalse(result.recomendacao.contains("PAAF"))
    }

    func testOfficialCategoriesAndManagementBoundaries() {
        let tr3FNA = calculate(
            composicao: .solido,
            ecogenicidade: .hiperIso,
            tamanho: 2.5
        )
        XCTAssertEqual(tr3FNA.categoria, .tr3)
        XCTAssertTrue(tr3FNA.recomendacao.contains("PAAF"))

        let tr4FollowUp = calculate(
            composicao: .solido,
            ecogenicidade: .hipo,
            tamanho: 1.0
        )
        XCTAssertEqual(tr4FollowUp.categoria, .tr4)
        XCTAssertTrue(tr4FollowUp.recomendacao.contains("1, 2, 3 e 5 anos"))

        let tr5FNA = calculate(
            composicao: .solido,
            ecogenicidade: .hipo,
            forma: .maisAlta,
            tamanho: 1.0
        )
        XCTAssertEqual(tr5FNA.categoria, .tr5)
        XCTAssertTrue(tr5FNA.recomendacao.contains("PAAF"))
    }

    func testPeripheralCalcificationScoresTwoPoints() {
        let result = TIRADSCalculator.calculate(.init(
            composicao: .cistico,
            ecogenicidade: .anecoico,
            forma: .maisLarga,
            margem: .lisaIndefinida,
            focosEcogenicos: [.perifericaContinua],
            maiorEixoCm: 1.0
        ))

        XCTAssertEqual(result.pontos, 2)
        XCTAssertEqual(result.categoria, .tr2)
    }

    private func calculate(
        composicao: TIRADSCalculator.Composicao,
        ecogenicidade: TIRADSCalculator.Ecogenicidade,
        forma: TIRADSCalculator.Forma = .maisLarga,
        margem: TIRADSCalculator.Margem = .lisaIndefinida,
        focos: [TIRADSCalculator.FocosEcogenicos] = [.nenhum],
        tamanho: Double
    ) -> TIRADSCalculator.TIRADSResult {
        TIRADSCalculator.calculate(.init(
            composicao: composicao,
            ecogenicidade: ecogenicidade,
            forma: forma,
            margem: margem,
            focosEcogenicos: focos,
            maiorEixoCm: tamanho
        ))
    }
}
