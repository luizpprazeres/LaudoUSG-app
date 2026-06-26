import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    var session: SessionState = .checking
    var profile: UserProfile?
    var defaultWritingStyleId: String = GenerateRequest.defaultWritingStyleId
    var availableStyles: [WritingStyleRecord] = []
    var reportPreferences: [ReportPreferenceRecord] = []
    var availableVariants: [ReportTemplateVariantRecord] = []
    let preferencesStore = PreferencesStore()
    /// Camada de In-App Purchase (StoreKit). Fonte de entitlement no dispositivo.
    let store = StoreManager()

    var preferences: UserPreferences {
        preferencesStore.preferences
    }

    // MARK: - Entitlement efetivo (IAP OU plano do backend)
    // A Apple (3.1.1/3.1.3b) exige que o que é comprado no app seja liberado por IAP.
    // Mantemos compatibilidade com quem comprou na web: vale o MAIOR entre o plano do
    // backend e a assinatura StoreKit ativa.

    /// Nível derivado do `plan` vindo do backend (web).
    private var backendTier: PlanTier? {
        guard let profile else { return nil }
        if profile.hasPro { return .pro }
        if profile.hasEssencialOrAbove { return .essential }
        return nil
    }

    /// Maior nível ativo considerando backend + IAP local.
    var effectiveTier: PlanTier? {
        [backendTier, store.entitlementTier].compactMap { $0 }.max()
    }

    /// Use estes nos gates de UI (em vez de `profile?.hasPro`).
    var hasProEffective: Bool { effectiveTier == .pro }
    var hasEssencialOrAboveEffective: Bool { effectiveTier != nil }
    var hasActiveIAP: Bool { store.hasActiveSubscription }

    /// Rótulo do plano considerando IAP + backend (para exibição).
    var effectivePlanLabel: String {
        switch effectiveTier {
        case .pro: return "Profissional"
        case .essential: return "Essencial"
        case nil: return profile?.planLabel ?? "Gratuito"
        }
    }

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

    func refreshProfile() async {
        do {
            let record = try await ProfileService.fetchProfile()
            updateProfile(record)
        } catch {
            // Falha silenciosa — UI segue com profile anterior.
        }
    }

    func refreshReportPreferences() async {
        do {
            let response = try await ProfileService.fetchReportPreferences()
            // Descarta resposta tardia se o usuário saiu da conta no meio tempo.
            guard session == .authenticated else { return }
            reportPreferences = response.preferences
            availableVariants = response.availableVariants
        } catch {
            // Falha silenciosa — UI segue com dados anteriores.
        }
    }

    func setReportPreference(categoryCode: String, variant: ReportTemplateVariantRecord?) {
        reportPreferences.removeAll { $0.categoryCode == categoryCode }
        if let variant {
            reportPreferences.append(
                ReportPreferenceRecord(
                    categoryCode: categoryCode,
                    defaultVariantId: variant.id,
                    variantKey: variant.variantKey
                )
            )
        }
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
        reportPreferences = []
        availableVariants = []
        defaultWritingStyleId = GenerateRequest.defaultWritingStyleId
        session = .signedOut
        Task { await AuthService.shared.signOut() }
    }

    func markChecked(signedIn: Bool) {
        session = signedIn ? .authenticated : .signedOut
    }

    func updatePreferences(_ preferences: UserPreferences) {
        preferencesStore.update(preferences)
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
        case "clinic": return "Profissional"
        case "pro": return "Pro"
        default: return "Gratuito"
        }
    }

    var hasEssencialOrAbove: Bool {
        switch plan?.lowercased() {
        case "essential", "essencial", "clinic", "pro": return true
        default: return false
        }
    }

    var hasPro: Bool {
        switch plan?.lowercased() {
        case "clinic", "pro": return true
        default: return false
        }
    }

    var avatarInitial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
    }
}
