import Foundation

enum WorkspaceCompanionInputKind: String, Codable, CaseIterable, Identifiable {
    case text
    case measurements

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Texto"
        case .measurements: return "Medidas"
        }
    }

    var placeholder: String {
        switch self {
        case .text:
            return "Ex.: fígado aumentado, com esteatose leve…"
        case .measurements:
            return "Ex.: útero 7,2 × 4,1 × 3,8 cm…"
        }
    }
}

struct WorkspaceCompanionSession: Codable, Sendable, Hashable {
    let id: String
    let code: String
    let expiresAt: Date
    let pairedAt: Date?
    let deviceLabel: String?
    let active: Bool

    var isActive: Bool {
        active && expiresAt > Date()
    }

    var remainingLabel: String {
        let remaining = max(0, expiresAt.timeIntervalSinceNow)
        let hours = Int(remaining) / 3_600
        let minutes = (Int(remaining) % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)min restantes" : "\(minutes)min restantes"
    }
}
