import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    var session: SessionState = .checking
    var profile: UserProfile?
    var defaultWritingStyleId: String = GenerateRequest.defaultWritingStyleId
    var availableStyles: [WritingStyleRecord] = []

    var needsLegalAcceptance: Bool {
        guard let profile else { return false }
        if profile.termsAcceptedAt == nil { return true }
        if profile.termsVersionAccepted != LegalVersions.termsOfUse { return true }
        if profile.privacyVersionAccepted != LegalVersions.privacyPolicy { return true }
        if profile.medicalDisclaimerVersionAccepted != LegalVersions.medicalDisclaimer { return true }
        return false
    }

    var needsOnboarding: Bool {
        guard let profile else { return false }
        return profile.onboardingCompletedAt == nil
    }

    func signIn(email: String, name: String?) {
        profile = UserProfile(
            email: email,
            displayName: name ?? email,
            crm: nil,
            uf: nil,
            plan: nil,
            termsAcceptedAt: nil,
            termsVersionAccepted: nil,
            privacyVersionAccepted: nil,
            medicalDisclaimerVersionAccepted: nil,
            onboardingCompletedAt: nil
        )
        session = .authenticated
    }

    func updateProfile(_ record: UserProfileRecord) {
        profile = UserProfile(
            email: record.email ?? profile?.email ?? "",
            displayName: record.name ?? record.email ?? profile?.displayName ?? "",
            crm: record.crm ?? profile?.crm,
            uf: record.uf ?? profile?.uf,
            plan: record.plan,
            termsAcceptedAt: record.termsAcceptedAt ?? profile?.termsAcceptedAt,
            termsVersionAccepted: record.termsVersionAccepted ?? profile?.termsVersionAccepted,
            privacyVersionAccepted: record.privacyVersionAccepted ?? profile?.privacyVersionAccepted,
            medicalDisclaimerVersionAccepted: record.medicalDisclaimerVersionAccepted ?? profile?.medicalDisclaimerVersionAccepted,
            onboardingCompletedAt: record.onboardingCompletedAt ?? profile?.onboardingCompletedAt
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
            plan: profile?.plan,
            termsAcceptedAt: profile?.termsAcceptedAt,
            termsVersionAccepted: profile?.termsVersionAccepted,
            privacyVersionAccepted: profile?.privacyVersionAccepted,
            medicalDisclaimerVersionAccepted: profile?.medicalDisclaimerVersionAccepted,
            onboardingCompletedAt: profile?.onboardingCompletedAt
        )
    }

    func markLegalAccepted(at date: Date) {
        guard let profile else { return }
        self.profile = UserProfile(
            email: profile.email,
            displayName: profile.displayName,
            crm: profile.crm,
            uf: profile.uf,
            plan: profile.plan,
            termsAcceptedAt: date,
            termsVersionAccepted: LegalVersions.termsOfUse,
            privacyVersionAccepted: LegalVersions.privacyPolicy,
            medicalDisclaimerVersionAccepted: LegalVersions.medicalDisclaimer,
            onboardingCompletedAt: profile.onboardingCompletedAt
        )
    }

    func markOnboardingComplete(at date: Date) {
        guard let profile else { return }
        self.profile = UserProfile(
            email: profile.email,
            displayName: profile.displayName,
            crm: profile.crm,
            uf: profile.uf,
            plan: profile.plan,
            termsAcceptedAt: profile.termsAcceptedAt,
            termsVersionAccepted: profile.termsVersionAccepted,
            privacyVersionAccepted: profile.privacyVersionAccepted,
            medicalDisclaimerVersionAccepted: profile.medicalDisclaimerVersionAccepted,
            onboardingCompletedAt: date
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
    let termsAcceptedAt: Date?
    let termsVersionAccepted: String?
    let privacyVersionAccepted: String?
    let medicalDisclaimerVersionAccepted: String?
    let onboardingCompletedAt: Date?

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
