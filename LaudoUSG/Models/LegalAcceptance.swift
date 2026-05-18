import Foundation

struct LegalAcceptance: Codable, Sendable, Hashable {
    let termsAcceptedAt: Date?
    let termsVersionAccepted: String?
    let privacyVersionAccepted: String?
    let medicalDisclaimerVersionAccepted: String?
    let onboardingCompletedAt: Date?
}

enum LegalDocKind: String, CaseIterable, Identifiable {
    case termsOfUse
    case privacyPolicy
    case medicalDisclaimer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .termsOfUse: return "Termos de Uso"
        case .privacyPolicy: return "Política de Privacidade"
        case .medicalDisclaimer: return "Disclaimer Médico"
        }
    }

    var bundleResourceName: String {
        switch self {
        case .termsOfUse: return "terms-of-use"
        case .privacyPolicy: return "privacy-policy"
        case .medicalDisclaimer: return "medical-disclaimer"
        }
    }

    var currentVersion: String {
        switch self {
        case .termsOfUse: return LegalVersions.termsOfUse
        case .privacyPolicy: return LegalVersions.privacyPolicy
        case .medicalDisclaimer: return LegalVersions.medicalDisclaimer
        }
    }
}
