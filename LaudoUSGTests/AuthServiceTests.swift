import XCTest
@testable import LaudoUSG

final class AuthServiceTests: XCTestCase {
    func testAuthRedirectURLPreservesNativeCallback() throws {
        let url = try XCTUnwrap(authRedirectURL(
            base: URL(string: "https://example.supabase.co")!,
            path: "/auth/v1/signup",
            redirectTo: "laudousg://auth/callback"
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.path, "/auth/v1/signup")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "redirect_to" })?.value,
            "laudousg://auth/callback"
        )
    }

    func testAuthRedirectURLSupportsPasswordRecovery() throws {
        let url = try XCTUnwrap(authRedirectURL(
            base: URL(string: "https://example.supabase.co")!,
            path: "/auth/v1/recover",
            redirectTo: "laudousg://auth/reset-password"
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "redirect_to" })?.value,
            "laudousg://auth/reset-password"
        )
    }
}
