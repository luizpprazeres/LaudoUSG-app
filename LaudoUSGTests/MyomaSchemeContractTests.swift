import XCTest
@testable import LaudoUSG

final class MyomaSchemeContractTests: XCTestCase {
    func testGenericAnatomicLabelDoesNotInventFigoNumber() throws {
        let findings = MyomaFindingsParser.parse(
            "Miométrio com nódulo intramural na parede anterior, medindo 2,0 x 1,8 x 1,5 cm."
        )

        XCTAssertEqual(findings.count, 1)
        XCTAssertNil(findings[0].figo)
        XCTAssertEqual(findings[0].sizeMaxMm, 20)
        XCTAssertEqual(findings[0].localizacao, .anterior)
    }

    func testExplicitFigoIsPreserved() throws {
        let findings = MyomaFindingsParser.parse(
            "Nódulo miomatoso subseroso posterior, medindo 2,3 x 1,8 x 2,0 cm, categoria FIGO 6."
        )

        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings[0].figo, 6)
        XCTAssertEqual(findings[0].sizeMaxMm, 23)
        XCTAssertEqual(findings[0].localizacao, .posterior)
    }

    func testOnlyUnambiguousAnatomyCanDeriveFigo() throws {
        let findings = MyomaFindingsParser.parse(
            "Nódulo miomatoso submucoso pediculado intracavitário, medindo 12 mm."
        )

        XCTAssertEqual(findings.first?.figo, 0)
    }

    func testMissingWallDoesNotBecomeAnterior() throws {
        let findings = MyomaFindingsParser.parse(
            "Nódulo miomatoso FIGO 4, medindo 2,5 cm."
        )
        XCTAssertEqual(findings.first?.localizacao, .notInformed)
        let contract = MyomaSchemeContract(editorFindings: findings)
        XCTAssertEqual(contract.findings.first?.location, .notInformed)
    }

    func testPortableContractMatchesSharedAndroidFieldsAndCoordinates() throws {
        let finding = MyomaFinding(
            figo: 4,
            sizeMaxMm: 24,
            localizacao: .lateralDireita,
            ecotextura: .heterogenea,
            sagPoint: .init(x: 210, y: 260),
            axPoint: .init(x: 280, y: 200)
        )
        let contract = MyomaSchemeContract(editorFindings: [finding])

        XCTAssertTrue(contract.activationIssues.isEmpty)
        XCTAssertEqual(contract.contractVersion, "myoma-scheme/v1")
        XCTAssertEqual(contract.examType, "MIOMAS")
        XCTAssertEqual(contract.findings.first?.figo, 4)
        XCTAssertEqual(contract.findings.first?.figoConfirmed, true)
        XCTAssertEqual(contract.findings.first?.location, .lateralDireita)
        XCTAssertEqual(contract.findings.first?.echo, .heterogenea)
        XCTAssertEqual(contract.findings.first?.sagittalPoint, .init(x: 210, y: 260))
        XCTAssertEqual(contract.findings.first?.axialPoint, .init(x: 280, y: 200))

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(contract)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["contractVersion", "examType", "findings"])
        XCTAssertEqual(json["contractVersion"] as? String, "myoma-scheme/v1")
        XCTAssertEqual(json["examType"] as? String, "MIOMAS")
        let encoded = try XCTUnwrap((json["findings"] as? [[String: Any]])?.first)
        XCTAssertEqual(
            Set(encoded.keys),
            ["id", "figo", "figoConfirmed", "sizeMaxMm", "location", "echo", "sagittalPoint", "axialPoint"]
        )
        XCTAssertEqual(encoded["sizeMaxMm"] as? Double, 24)
        XCTAssertEqual(encoded["figoConfirmed"] as? Bool, true)
        XCTAssertEqual(encoded["location"] as? String, "lateral_direita")
    }

    func testPortableContractFailsClosedWithoutFigoConfirmationAndPreservesNullShape() throws {
        let contract = MyomaSchemeContract(editorFindings: [MyomaFinding()])
        XCTAssertEqual(contract.findings.first?.figo, 4)
        XCTAssertEqual(contract.findings.first?.figoConfirmed, false)
        XCTAssertEqual(contract.activationIssues.map(\.field), ["findings.0.figoConfirmed"])

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(contract)) as? [String: Any])
        let encoded = try XCTUnwrap((json["findings"] as? [[String: Any]])?.first)
        XCTAssertTrue(encoded["sizeMaxMm"] is NSNull)
        XCTAssertTrue(encoded["echo"] is NSNull)
        XCTAssertTrue(encoded["sagittalPoint"] is NSNull)
        XCTAssertTrue(encoded["axialPoint"] is NSNull)
    }

    func testSalaPayloadIncludesCanonicalMyomaContractOnlyForMyomas() throws {
        let finding = MyomaFinding(figo: 4, sizeMaxMm: 25, localizacao: .notInformed)
        let contract = MyomaSchemeContract(editorFindings: [finding])
        let data = try SalaSchemaUploader.makePayloadData(
            png: Data([1, 2, 3]), pdf: nil, examType: "MIOMAS",
            examLabel: "Pelve — miomas", reportId: nil, myomaContract: contract
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["contractVersion"] as? String, "myoma-scheme/v1")
        let findings = try XCTUnwrap(json["findings"] as? [[String: Any]])
        XCTAssertEqual(findings.first?["location"] as? String, "not_informed")
        XCTAssertEqual(findings.first?["figoConfirmed"] as? Bool, true)

        let other = try SalaSchemaUploader.makePayloadData(
            png: Data([1]), pdf: nil, examType: "MAMA",
            examLabel: "Mama", reportId: nil, myomaContract: contract
        )
        let otherJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: other) as? [String: Any])
        XCTAssertNil(otherJSON["contractVersion"])
        XCTAssertNil(otherJSON["findings"])
    }
}
