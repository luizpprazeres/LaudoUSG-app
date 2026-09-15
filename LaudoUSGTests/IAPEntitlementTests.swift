import XCTest
@testable import LaudoUSG

/// Gates do IAP no cliente — a parte que decide sem StoreKit:
/// posse (appAccountToken), expiração/revogação, tier, e o que o backend
/// respondeu ⇒ finalizar ou não a transação.
final class IAPEntitlementTests: XCTestCase {
    private let userA = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let userB = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var future: Date { now.addingTimeInterval(30 * 24 * 3600) }
    private var past: Date { now.addingTimeInterval(-3600) }

    private func snap(
        _ product: String = StoreManager.proMonthly,
        token: UUID?,
        expires: Date? = nil,
        revoked: Date? = nil,
        upgraded: Bool = false
    ) -> IAPTransactionSnapshot {
        IAPTransactionSnapshot(
            productID: product,
            appAccountToken: token,
            expirationDate: expires ?? future,
            revocationDate: revoked,
            isUpgraded: upgraded
        )
    }

    // MARK: Posse

    func testTransactionOfLoggedUserCounts() {
        let ids = IAPEntitlementResolver.activeProductIDs([snap(token: userA)], userID: userA, now: now)
        XCTAssertEqual(ids, [StoreManager.proMonthly])
    }

    func testTransactionOfAnotherAccountDoesNotCount() {
        let ids = IAPEntitlementResolver.activeProductIDs([snap(token: userA)], userID: userB, now: now)
        XCTAssertTrue(ids.isEmpty, "trocar de conta no mesmo iPhone não pode herdar o plano")
    }

    func testTransactionWithoutTokenDoesNotCount() {
        let ids = IAPEntitlementResolver.activeProductIDs([snap(token: nil)], userID: userA, now: now)
        XCTAssertTrue(ids.isEmpty, "sem appAccountToken não há prova de posse")
    }

    func testNoBoundUserMeansNoAccess() {
        let ids = IAPEntitlementResolver.activeProductIDs([snap(token: userA)], userID: nil, now: now)
        XCTAssertTrue(ids.isEmpty, "deslogado (clearAccount) ⇒ zero acesso por IAP")
    }

    func testOtherAccountEntitlementIsReportedForRestoreMessage() {
        let snaps = [snap(token: userA)]
        XCTAssertTrue(IAPEntitlementResolver.hasEntitlementForAnotherAccount(snaps, userID: userB, now: now))
        XCTAssertFalse(IAPEntitlementResolver.hasEntitlementForAnotherAccount(snaps, userID: userA, now: now))
        XCTAssertFalse(IAPEntitlementResolver.hasEntitlementForAnotherAccount([snap(token: userA, expires: past)], userID: userB, now: now))
    }

    // MARK: Expiração / revogação / upgrade

    func testExpiredDoesNotCount() {
        XCTAssertTrue(IAPEntitlementResolver.activeProductIDs([snap(token: userA, expires: past)], userID: userA, now: now).isEmpty)
    }

    func testRevokedDoesNotCount() {
        XCTAssertTrue(IAPEntitlementResolver.activeProductIDs([snap(token: userA, revoked: past)], userID: userA, now: now).isEmpty)
    }

    func testUpgradedOldTransactionDoesNotCountButNewDoes() {
        let snaps = [
            snap(StoreManager.essentialMonthly, token: userA, upgraded: true),
            snap(StoreManager.proMonthly, token: userA),
        ]
        let ids = IAPEntitlementResolver.activeProductIDs(snaps, userID: userA, now: now)
        XCTAssertEqual(ids, [StoreManager.proMonthly])
        XCTAssertEqual(IAPEntitlementResolver.tier(for: ids), .pro)
    }

    func testMixedAccountsOnlyOwnCounts() {
        let snaps = [
            snap(StoreManager.proYearly, token: userB),
            snap(StoreManager.essentialMonthly, token: userA),
        ]
        let ids = IAPEntitlementResolver.activeProductIDs(snaps, userID: userA, now: now)
        XCTAssertEqual(ids, [StoreManager.essentialMonthly])
        XCTAssertEqual(IAPEntitlementResolver.tier(for: ids), .essential)
    }

    // MARK: Tier

    func testTierMapping() {
        XCTAssertEqual(IAPEntitlementResolver.tier(forProductID: StoreManager.proYearly), .pro)
        XCTAssertEqual(IAPEntitlementResolver.tier(forProductID: StoreManager.essentialYearly), .essential)
        XCTAssertNil(IAPEntitlementResolver.tier(forProductID: "com.outro.app.gold"))
        XCTAssertNil(IAPEntitlementResolver.tier(for: []))
        XCTAssertEqual(IAPEntitlementResolver.tier(for: [StoreManager.essentialMonthly, StoreManager.proMonthly]), .pro)
        XCTAssertEqual(PlanTier.pro.backendPlan, "clinic")
        XCTAssertEqual(PlanTier.essential.backendPlan, "essencial")
        XCTAssertTrue(PlanTier.essential < PlanTier.pro)
    }

    // MARK: Resposta do backend ⇒ finish() ou não

    func testOnlyAcceptedFinishesTransaction() {
        XCTAssertTrue(IAPSyncOutcome.accepted(plan: "clinic").shouldFinishTransaction)
        XCTAssertFalse(IAPSyncOutcome.rejected(code: "owned_by_other_account").shouldFinishTransaction)
        XCTAssertFalse(IAPSyncOutcome.retryLater(reason: "storage_unavailable").shouldFinishTransaction)
    }

    func testDefinitiveRejectionsAreClassified() {
        XCTAssertEqual(
            IAPSyncOutcome.classify(APIError.http(status: 409, body: #"{"error":"owned_by_other_account","retryable":false}"#)),
            .rejected(code: "owned_by_other_account")
        )
        XCTAssertEqual(
            IAPSyncOutcome.classify(APIError.http(status: 422, body: #"{"error":"invalid_jws","retryable":false}"#)),
            .rejected(code: "invalid_jws")
        )
        XCTAssertEqual(
            IAPSyncOutcome.classify(APIError.http(status: 403, body: #"{"error":"app_account_token_mismatch"}"#)),
            .rejected(code: "app_account_token_mismatch")
        )
        XCTAssertEqual(IAPSyncOutcome.classify(APIError.http(status: 400, body: nil)), .rejected(code: "http_400"))
    }

    func testRetryableFailuresNeverFinish() {
        let cases: [IAPSyncOutcome] = [
            IAPSyncOutcome.classify(APIError.http(status: 503, body: #"{"error":"storage_unavailable","retryable":true}"#)),
            IAPSyncOutcome.classify(APIError.http(status: 500, body: nil)),
            IAPSyncOutcome.classify(APIError.http(status: 429, body: #"{"error":"slow_down","retryable":true}"#)),
            IAPSyncOutcome.classify(APIError.unauthorized),
            IAPSyncOutcome.classify(APIError.transport(URLError(.notConnectedToInternet))),
            IAPSyncOutcome.classify(APIError.invalidResponse),
            IAPSyncOutcome.classify(NSError(domain: "x", code: 1)),
        ]
        for outcome in cases {
            guard case .retryLater = outcome else {
                return XCTFail("esperava retryLater, veio \(outcome)")
            }
            XCTAssertFalse(outcome.shouldFinishTransaction)
        }
    }
}
