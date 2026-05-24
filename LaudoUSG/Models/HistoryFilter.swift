import Foundation

enum HistoryDateRange: String, CaseIterable, Identifiable {
    case all
    case today
    case lastWeek
    case lastMonth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Tudo"
        case .today: return "Hoje"
        case .lastWeek: return "7 dias"
        case .lastMonth: return "30 dias"
        }
    }

    func startDate(now: Date = Date()) -> Date? {
        let cal = Calendar(identifier: .gregorian)
        switch self {
        case .all:
            return nil
        case .today:
            return cal.startOfDay(for: now)
        case .lastWeek:
            return cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now))
        case .lastMonth:
            return cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: now))
        }
    }
}

struct HistoryFilter: Equatable {
    var dateRange: HistoryDateRange = .all
    var categories: Set<ReportCategory> = []
    var searchText: String = ""

    var isActive: Bool {
        dateRange != .all || !categories.isEmpty || !trimmedSearch.isEmpty
    }

    var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
