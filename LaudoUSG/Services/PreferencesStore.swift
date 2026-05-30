import Foundation
import Observation

@Observable
@MainActor
final class PreferencesStore {
    private let key = "laudousg.preferences"

    var preferences: UserPreferences

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .default
        }
    }

    func update(_ newValue: UserPreferences) {
        preferences = newValue
        if let data = try? JSONEncoder().encode(newValue) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
