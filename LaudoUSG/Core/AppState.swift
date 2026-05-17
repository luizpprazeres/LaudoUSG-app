import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    var session: SessionState = .checking
    var profile: UserProfile?
    var defaultWritingStyleId: String = GenerateRequest.defaultWritingStyleId
    var availableStyles: [WritingStyleRecord] = []

    func signIn(email: String, name: String?) {
        profile = UserProfile(email: email, displayName: name ?? email)
        session = .authenticated
    }

    func signOut() {
        profile = nil
        availableStyles = []
        defaultWritingStyleId = GenerateRequest.defaultWritingStyleId
        session = .signedOut
        Task { await AuthService.shared.signOut() }
    }

    func markChecked(signedIn: Bool) {
        session = signedIn ? .authenticated : .signedOut
    }
}

enum SessionState {
    case checking
    case signedOut
    case authenticated
}

struct UserProfile: Equatable {
    let email: String
    let displayName: String
    var avatarInitial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
    }
}
