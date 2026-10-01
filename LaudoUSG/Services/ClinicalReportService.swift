import Foundation

enum ClinicalReportService {
    struct CreateRequest: Encodable, Equatable, Sendable {
        let contract: ClinicalModelDraft
        let writingStyleId: String?

        private enum CodingKeys: String, CodingKey {
            case contract
            case writingStyleId = "writing_style_id"
        }
    }

    struct CreateResponse: Decodable, Sendable { let report: Report }

    struct Report: Decodable, Sendable {
        let id: String
        let categoryCode: String
        let status: String
        let contentRevision: Int
        let reviewStatus: String
        let physicianReviewed: Bool
        let generatedOutput: String
        let contract: ClinicalModelDraft
        let warnings: [ClinicalContractIssue]
        let createdAt: Date
    }

    struct ReviewRequest: Encodable, Equatable, Sendable {
        let expectedRevision: Int
        let expectedText: String
    }

    struct ReviewResponse: Decodable, Sendable {
        let ok: Bool
        let contentRevision: Int
        let reviewStatus: String
        let reviewedAt: Date
    }

    static func create(
        draft: ClinicalModelDraft,
        writingStyleId: String?
    ) async throws -> Report {
        let request = CreateRequest(
            contract: draft.settingPhysicianReviewed(false),
            writingStyleId: writingStyleId
        )
        let data = try await APIClient.shared.postRawJSON(
            "/api/v1/clinical-reports",
            body: JSONEncoder().encode(request)
        )
        return try JSONDecoder.api.decode(CreateResponse.self, from: data).report
    }

    static func review(
        reportId: String,
        expectedRevision: Int,
        expectedText: String
    ) async throws -> ReviewResponse {
        let request = ReviewRequest(
                expectedRevision: expectedRevision,
                expectedText: expectedText
        )
        let data = try await APIClient.shared.postRawJSON(
            "/api/v1/clinical-reports/\(reportId)/review",
            body: JSONEncoder().encode(request)
        )
        return try JSONDecoder.api.decode(ReviewResponse.self, from: data)
    }
}
