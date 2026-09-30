import UIKit
import XCTest
@testable import LaudoUSG

final class ThyroidDualViewSchemaTests: XCTestCase {
    func testFrontalClassifiesSideThirdAndIsthmus() {
        let superior = ThyroidDualViewSchema.bucketAt(CGPoint(x: 145, y: 188), projection: .frontal, preservedThird: nil)
        XCTAssertEqual(superior?.side, .direito)
        XCTAssertEqual(superior?.third, .superior)

        let inferior = ThyroidDualViewSchema.bucketAt(CGPoint(x: 255, y: 292), projection: .frontal, preservedThird: nil)
        XCTAssertEqual(inferior?.side, .esquerdo)
        XCTAssertEqual(inferior?.third, .inferior)

        let isthmus = ThyroidDualViewSchema.bucketAt(CGPoint(x: 200, y: 252), projection: .frontal, preservedThird: .medio)
        XCTAssertEqual(isthmus?.side, .istmo)
        XCTAssertNil(isthmus?.third)
        XCTAssertNil(ThyroidDualViewSchema.bucketAt(CGPoint(x: 30, y: 35), projection: .frontal, preservedThird: nil))
    }

    func testTransversePreservesThirdWithoutInferringDepth() {
        let left = ThyroidDualViewSchema.bucketAt(CGPoint(x: 630, y: 178), projection: .transverse, preservedThird: .superior)
        XCTAssertEqual(left?.side, .esquerdo)
        XCTAssertEqual(left?.third, .superior)

        let right = ThyroidDualViewSchema.bucketAt(CGPoint(x: 500, y: 178), projection: .transverse, preservedThird: .inferior)
        XCTAssertEqual(right?.side, .direito)
        XCTAssertEqual(right?.third, .inferior)
        XCTAssertNil(ThyroidDualViewSchema.bucketAt(CGPoint(x: 760, y: 400), projection: .transverse, preservedThird: .medio))
    }

    func testApprovedAnatomyAssetsAreBundled() {
        XCTAssertNotNil(UIImage(named: "ThyroidFrontalV2"))
        XCTAssertNotNil(UIImage(named: "ThyroidTransverseV2"))
    }
}
