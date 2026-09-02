import XCTest
@testable import LaudoUSG

final class FetalGrowthCalculatorTests: XCTestCase {
    private let source = "Intergrowth-21st"

    func testGoldenClinicalBoundariesAndStages() throws {
        let aga = try XCTUnwrap(FetalGrowthCalculator.calculate(.init(efwPercentile: 10, efwPercentileSource: source)))
        XCTAssertEqual(aga.classification, .adequateForGestationalAge)

        var pigInput = FetalGrowthCalculator.Input(efwPercentile: 3, efwPercentileSource: source)
        pigInput.dopplerAssessmentCompleteAndNormal = true
        XCTAssertEqual(FetalGrowthCalculator.calculate(pigInput)?.classification, .smallForGestationalAge)

        let stage1 = try XCTUnwrap(FetalGrowthCalculator.calculate(.init(efwPercentile: 2.9, efwPercentileSource: source)))
        XCTAssertEqual(stage1.stage, 1)

        var cprSingle = FetalGrowthCalculator.Input(efwPercentile: 7, efwPercentileSource: source)
        cprSingle.cprBelowP5 = .init(present: true, confirmed: false)
        XCTAssertNil(FetalGrowthCalculator.calculate(cprSingle)?.stage)
        XCTAssertEqual(FetalGrowthCalculator.calculate(cprSingle)?.pendingCriteria.first?.stage, 1)

        var stage2Input = FetalGrowthCalculator.Input(efwPercentile: 5, efwPercentileSource: source)
        stage2Input.umbilicalArteryEndDiastolicFlow = .absent
        stage2Input.umbilicalFlowAbnormalInMajorityBothArteries = true
        stage2Input.umbilicalFlowConfirmedInRequiredInterval = true
        XCTAssertEqual(FetalGrowthCalculator.calculate(stage2Input)?.stage, 2)

        var stage2WithoutBothArteries = FetalGrowthCalculator.Input(efwPercentile: 5, efwPercentileSource: source)
        stage2WithoutBothArteries.umbilicalArteryEndDiastolicFlow = .absent
        stage2WithoutBothArteries.umbilicalFlowConfirmedInRequiredInterval = true
        let pendingStage2 = try XCTUnwrap(FetalGrowthCalculator.calculate(stage2WithoutBothArteries))
        XCTAssertNil(pendingStage2.stage)
        XCTAssertTrue(pendingStage2.pendingCriteria.first?.confirmationRequirement?.contains("50%") == true)

        var stage3Input = FetalGrowthCalculator.Input(efwPercentile: 4, efwPercentileSource: source)
        stage3Input.ductusVenosus.piAboveP95 = true
        stage3Input.ductusVenosus.confirmedAfter6To12Hours = true
        XCTAssertEqual(FetalGrowthCalculator.calculate(stage3Input)?.stage, 3)

        var stage4Input = FetalGrowthCalculator.Input(efwPercentile: 9, efwPercentileSource: source)
        stage4Input.pathologicalCtg = true
        XCTAssertEqual(FetalGrowthCalculator.calculate(stage4Input)?.stage, 4)
        let insertBlock = FetalGrowthCalculator.insertBlock(from: try XCTUnwrap(FetalGrowthCalculator.calculate(stage4Input)))
        XCTAssertTrue(insertBlock.contains("Fetal Medicine Barcelona"))
        XCTAssertTrue(insertBlock.contains("percentil 9 pela curva Intergrowth-21st"))
        XCTAssertTrue(insertBlock.contains("Critério confirmado: traçado cardiotocográfico patológico"))
    }

    func testDopplerDoesNotBecomeFGRWhenWeightIsAtOrAboveP10() throws {
        var input = FetalGrowthCalculator.Input(efwPercentile: 20, efwPercentileSource: source)
        input.meanUterinePiAboveP95 = true
        let result = try XCTUnwrap(FetalGrowthCalculator.calculate(input))
        XCTAssertNil(result.stage)
        XCTAssertTrue(result.warnings.joined().contains("não preenche a definição de RCF"))
    }

}
