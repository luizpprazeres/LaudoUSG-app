import Foundation

enum GestationalAgeCalculator {
    enum IGMethod: String, Sendable {
        case dum = "DUM"
        case usg = "USG"
    }

    struct IGResult: Sendable, Hashable {
        let weeks: Int
        let days: Int
        let dpp: Date
        let method: IGMethod
        let label: String
        let insertBloco: String
    }

    struct ConcordanceResult: Sendable, Hashable {
        let concordant: Bool
        let threshold: Int
        let diff: Int
    }

    static func calcByDUM(dum: Date, today: Date = Date()) -> IGResult? {
        let totalDays = diffDays(today, dum)
        guard totalDays >= 0 else { return nil }

        let weeks = totalDays / 7
        let days = totalDays % 7
        let dpp = addDays(dum, 280)
        let label = igLabel(weeks: weeks, days: days)
        let insertBloco = "Idade gestacional de \(label) (DUM: \(formatDate(dum))). DPP: \(formatDate(dpp))."

        return IGResult(weeks: weeks, days: days, dpp: dpp, method: .dum, label: label, insertBloco: insertBloco)
    }

    static func calcByUSG(
        usgDate: Date,
        usgWeeks: Int,
        usgDays: Int,
        today: Date = Date()
    ) -> IGResult? {
        guard usgWeeks >= 0, (0...6).contains(usgDays) else { return nil }

        let usgTotalDays = usgWeeks * 7 + usgDays
        let daysSinceUSG = diffDays(today, usgDate)
        guard daysSinceUSG >= 0 else { return nil }

        let currentTotalDays = usgTotalDays + daysSinceUSG
        let weeks = currentTotalDays / 7
        let days = currentTotalDays % 7
        let dpp = addDays(usgDate, 280 - usgTotalDays)
        let label = igLabel(weeks: weeks, days: days)
        let insertBloco = "Primeira ultrassonografia realizada em \(formatDate(usgDate)). Hoje com \(label)."

        return IGResult(weeks: weeks, days: days, dpp: dpp, method: .usg, label: label, insertBloco: insertBloco)
    }

    static func checkConcordance(dum: IGResult, usg: IGResult) -> ConcordanceResult {
        let diff = abs(diffDays(dum.dpp, usg.dpp))
        let threshold: Int

        if usg.weeks <= 8 {
            threshold = 5
        } else if usg.weeks <= 13 {
            threshold = 7
        } else if usg.weeks <= 21 {
            threshold = 10
        } else if usg.weeks <= 27 {
            threshold = 14
        } else {
            threshold = 21
        }

        return ConcordanceResult(concordant: diff <= threshold, threshold: threshold, diff: diff)
    }

    static func parseDateBR(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("-"), let isoDate = ISO8601DateFormatter().date(from: trimmed) {
            return isoDate
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false

        formatter.dateFormat = trimmed.contains("-") ? "yyyy-MM-dd'T'HH:mm:ss" : "dd/MM/yyyy'T'HH:mm:ss"
        let normalized = "\(trimmed)T12:00:00"
        return formatter.date(from: normalized)
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = calendar
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }

    private static func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func diffDays(_ a: Date, _ b: Date) -> Int {
        let startA = calendar.startOfDay(for: a)
        let startB = calendar.startOfDay(for: b)
        return calendar.dateComponents([.day], from: startB, to: startA).day ?? 0
    }

    private static func igLabel(weeks: Int, days: Int) -> String {
        let weeksText = "\(weeks) semana\(weeks == 1 ? "" : "s")"
        let daysText = days == 0 ? "" : " e \(days) dia\(days == 1 ? "" : "s")"
        return "\(weeksText)\(daysText)"
    }
}
