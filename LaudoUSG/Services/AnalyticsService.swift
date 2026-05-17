import Foundation

enum AnalyticsService {
    static func fetch() async throws -> AnalyticsSummary {
        try await APIClient.shared.get("/api/me/analytics", as: AnalyticsSummary.self)
    }
}
