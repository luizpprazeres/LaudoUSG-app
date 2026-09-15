import Foundation

enum AIConsentError: LocalizedError {
    case permissionRequired

    var errorDescription: String? {
        "Para usar IA, autorize o processamento em Preferências > Privacidade e IA."
    }
}

enum AIConsentPolicy {
    static func key(userID: String) -> String {
        "laudousg.aiConsent.v1.\(userID.lowercased())"
    }

    static func decision(userID: String, defaults: UserDefaults = .standard) -> Bool? {
        defaults.object(forKey: key(userID: userID)) as? Bool
    }

    static func set(_ allowed: Bool, userID: String, defaults: UserDefaults = .standard) {
        defaults.set(allowed, forKey: key(userID: userID))
    }

    static func requiresPermission(path: String) -> Bool {
        let normalized = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return ["/api/generate", "/api/consultant", "/api/transcribe", "/api/analyze-image", "/api/deepgram/token"].contains(normalized)
    }

    static func authorize(path: String) async throws {
        guard requiresPermission(path: path) else { return }
        guard let userID = await AuthService.shared.currentUserId(), decision(userID: userID) == true else {
            throw AIConsentError.permissionRequired
        }
    }
}
