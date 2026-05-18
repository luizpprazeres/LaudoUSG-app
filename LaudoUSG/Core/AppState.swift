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
        profile = UserProfile(email: email, displayName: name ?? email, crm: nil, uf: nil, plan: nil)
        session = .authenticated
    }

    func updateProfile(_ record: UserProfileRecord) {
        profile = UserProfile(
            email: record.email ?? profile?.email ?? "",
            displayName: record.name ?? record.email ?? profile?.displayName ?? "",
            crm: record.crm ?? profile?.crm,
            uf: record.uf ?? profile?.uf,
            plan: record.plan
        )
        if let styleId = record.defaultWritingStyleId {
            defaultWritingStyleId = styleId
        }
    }

    func updateProfile(name: String, crm: String, uf: String) {
        profile = UserProfile(
            email: profile?.email ?? "",
            displayName: name,
            crm: crm,
            uf: uf,
            plan: profile?.plan
        )
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
    let crm: String?
    let uf: String?
    let plan: String?

    var planLabel: String {
        switch plan?.lowercased() {
        case "free", "gratuito": return "Gratuito"
        case "essential", "essencial": return "Essencial"
        case "pro": return "Pro"
        default: return "Gratuito"
        }
    }

    var avatarInitial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
    }
}
