import XCTest
@testable import LaudoUSG

final class ReportReviewContractTests: XCTestCase {
    func testReviewRequestUsesBackendCamelCaseAndExactVisibleText() throws {
        let text = "Útero de dimensões preservadas.\nConclusão: sem alterações."
        let data = try JSONEncoder().encode(ReportReviewRequest(expectedRevision: 12, expectedText: text))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["expectedRevision"] as? Int, 12)
        XCTAssertEqual(object["expectedText"] as? String, text)
        XCTAssertNil(object["expected_revision"])
        XCTAssertNil(object["expected_text"])
    }

    func testRevisionConflictAsksForAnotherMedicalReview() {
        XCTAssertTrue(HistoryService.ReviewError.conflict.localizedDescription.contains("revise novamente"))
    }

    func testReviewResponseAndDetailDecodeServerRevisionAndStatus() throws {
        let responseJSON = #"{"ok":true,"contentRevision":12,"reviewStatus":"reviewed","reviewedAt":"2026-09-28T14:30:00.000Z"}"#
        let response = try JSONDecoder.api.decode(ReportReviewResponse.self, from: Data(responseJSON.utf8))
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.contentRevision, 12)
        XCTAssertEqual(response.reviewStatus, .reviewed)
        XCTAssertNotNil(response.reviewedAt)

        let reportJSON = #"{"report":{"id":"r1","category_code":"ABDOME_TOTAL","status":"generated","final_output":"Laudo final","content_revision":12,"review_status":"reviewed","reviewed_at":"2026-09-28T14:30:00Z","created_at":"2026-09-28T14:00:00Z","updated_at":"2026-09-28T14:30:00Z"}}"#
        let envelope = try JSONDecoder.api.decode(ReportEnvelopeFixture.self, from: Data(reportJSON.utf8))
        XCTAssertEqual(envelope.report.contentRevision, 12)
        XCTAssertEqual(envelope.report.reviewStatus, .reviewed)
        XCTAssertEqual(envelope.report.displayText, "Laudo final")
    }

    func testLegacyReportWithoutReviewFieldsDecodesAsUnreviewed() throws {
        let reportJSON = #"{"id":"legacy","category_code":"ABDOME_TOTAL","status":"generated","generated_output":"Laudo legado","created_at":"2026-09-28T14:00:00Z","updated_at":"2026-09-28T14:00:00Z"}"#
        let report = try JSONDecoder.api.decode(Report.self, from: Data(reportJSON.utf8))

        XCTAssertNil(report.contentRevision)
        XCTAssertNil(report.reviewStatus)
        XCTAssertNil(report.reviewedAt)
    }
}

private struct ReportEnvelopeFixture: Decodable {
    let report: Report
}
