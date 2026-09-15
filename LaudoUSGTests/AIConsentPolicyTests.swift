import XCTest
@testable import LaudoUSG

final class AIConsentPolicyTests: XCTestCase {
    func testConsentIsExplicitRevocableAndAccountScoped() {
        let suite = "ai-consent-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(AIConsentPolicy.decision(userID: "A", defaults: defaults))
        AIConsentPolicy.set(true, userID: "A", defaults: defaults)
        XCTAssertEqual(AIConsentPolicy.decision(userID: "a", defaults: defaults), true)
        XCTAssertNil(AIConsentPolicy.decision(userID: "B", defaults: defaults))
        AIConsentPolicy.set(false, userID: "A", defaults: defaults)
        XCTAssertEqual(AIConsentPolicy.decision(userID: "A", defaults: defaults), false)
    }

    func testAllAITransportsRequirePermissionButAccountAndHistoryDoNot() {
        for path in ["/api/generate", "/api/consultant", "/api/transcribe", "/api/analyze-image", "/api/deepgram/token", "api/generate/"] {
            XCTAssertTrue(AIConsentPolicy.requiresPermission(path: path), path)
        }
        for path in ["/api/me/profile", "/api/reports/123", "/api/me/delete-account", "/api/iap/validate-receipt", "/api/sala/push"] {
            XCTAssertFalse(AIConsentPolicy.requiresPermission(path: path), path)
        }
    }
}
