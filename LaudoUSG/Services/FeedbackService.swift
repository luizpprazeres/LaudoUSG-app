import Foundation

enum FeedbackService {
    static func submit(reportId: String, categoryCode: String, verdict: String, comment: String?) async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw SupabaseError.unauthorized
        }

        let cleanedComment = comment?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        let body = try JSONEncoder.api.encode(UserFeedbackPayload(
            reportId: reportId,
            userId: userId,
            categoryCode: categoryCode,
            verdict: verdict,
            comment: cleanedComment
        ))

        try await SupabaseRESTClient.shared.postRaw(
            "/rest/v1/user_feedback",
            query: ["on_conflict": "report_id,user_id"],
            body: body,
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }
}

private struct UserFeedbackPayload: Encodable {
    let reportId: String
    let userId: String
    let categoryCode: String
    let verdict: String
    let comment: String?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
