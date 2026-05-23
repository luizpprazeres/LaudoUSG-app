import SwiftUI

struct DailyCalendarView: View {
    let reports: [Report]
    @State private var displayedMonth: Date

    private let weekdays = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)

    init(reports: [Report], month: Date) {
        self.reports = reports
        _displayedMonth = State(initialValue: Calendar.ptBR.startOfMonth(for: month))
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            header
            weekdayHeader

            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(calendarCells) { cell in
                    dayCell(cell)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppSurface.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthLabel)
                .font(TextStyle.bodySemibold)
                .foregroundStyle(AppSurface.textPrimary)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppSurface.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday)
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ cell: CalendarCell) -> some View {
        Group {
            if let day = cell.day {
                let data = monthData[day]
                CalendarDayCell(day: day, data: data)
            } else {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(AppSurface.muted)
                    .frame(height: 76)
            }
        }
    }

    private var monthData: [Int: DayData] {
        DayData.build(from: reports, month: displayedMonth)
    }

    private var calendarCells: [CalendarCell] {
        let calendar = Calendar.ptBR
        let range = calendar.range(of: .day, in: .month, for: displayedMonth) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let startOffset = (firstWeekday + 5) % 7
        var cells = (0..<startOffset).map { CalendarCell(id: "empty-start-\($0)", day: nil) }
        cells.append(contentsOf: range.map { CalendarCell(id: "day-\($0)", day: $0) })
        while cells.count % 7 != 0 {
            cells.append(CalendarCell(id: "empty-end-\(cells.count)", day: nil))
        }
        return cells
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth).capitalized(with: Locale(identifier: "pt_BR"))
    }

    private func changeMonth(by value: Int) {
        displayedMonth = Calendar.ptBR.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }
}

private struct CalendarCell: Identifiable {
    let id: String
    let day: Int?
}

private struct DayData {
    let total: Int
    let breakdown: [(category: String, count: Int)]
    let avgMinutes: Int?

    static func build(from reports: [Report], month: Date) -> [Int: DayData] {
        let calendar = Calendar.ptBR
        let grouped = Dictionary(grouping: reports.filter { calendar.isDate($0.createdAt, equalTo: month, toGranularity: .month) }) {
            calendar.component(.day, from: $0.createdAt)
        }

        return grouped.mapValues { dayReports in
            let categoryCounts = Dictionary(grouping: dayReports, by: \.categoryCode)
                .map { (category: categoryShortLabel(for: $0.key), count: $0.value.count) }
                .sorted {
                    if $0.count == $1.count { return $0.category < $1.category }
                    return $0.count > $1.count
                }

            return DayData(
                total: dayReports.count,
                breakdown: categoryCounts,
                avgMinutes: averageMinutes(for: dayReports)
            )
        }
    }

    private static func averageMinutes(for reports: [Report]) -> Int? {
        guard reports.count > 1 else { return nil }
        let sorted = reports.sorted { $0.createdAt < $1.createdAt }
        let intervals = zip(sorted.dropFirst(), sorted).compactMap { current, previous -> Double? in
            let minutes = current.createdAt.timeIntervalSince(previous.createdAt) / 60
            return minutes <= 30 ? minutes : nil
        }
        guard !intervals.isEmpty else { return nil }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        return Int(average.rounded())
    }

    private static func categoryShortLabel(for code: String) -> String {
        switch ReportCategory(rawValue: code) {
        case .obstetrica: return "Obstet."
        case .dopplerObstetrico: return "Doppler obst."
        case .pelveFeminina: return "Pelve"
        case .abdomenTotal: return "Abdome"
        case .mamaria: return "Mama"
        case .tireoide: return "Tireoide"
        case .morfologico: return "Morfol."
        case .viasUrinarias: return "Vias urin."
        case .musculoesqueletico, .musculoesqueleticoV2, .musculoesqueleticoRaras: return "Músculo"
        case let category?: return category.label
        case nil: return code
        }
    }
}

private struct CalendarDayCell: View {
    let day: Int
    let data: DayData?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .top) {
                if let data {
                    Text("\(data.total)")
                        .font(BrandFont.display(.extraBold, size: 22))
                        .foregroundStyle(BrandColor.primaryDeep)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(day)")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textMuted)
            }

            Spacer(minLength: 0)

            if let data {
                Text(data.breakdown.prefix(2).map { "\($0.count) \($0.category)" }.joined(separator: " · "))
                    .font(BrandFont.body(.medium, size: 9))
                    .foregroundStyle(AppSurface.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                if let avgMinutes = data.avgMinutes {
                    Text("~\(avgMinutes)min")
                        .font(BrandFont.body(.regular, size: 9))
                        .foregroundStyle(AppSurface.textMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(data == nil ? AppSurface.muted : BrandColor.primaryTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(data == nil ? AppSurface.border.opacity(0.5) : BrandColor.primaryBorder, lineWidth: 1)
        )
    }
}

private extension Calendar {
    static var ptBR: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")
        calendar.firstWeekday = 2
        return calendar
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

#Preview {
    DailyCalendarView(reports: Report.analyticsPreviewReports, month: Date())
        .padding()
        .background(AppSurface.background)
}

private extension Report {
    static var analyticsPreviewReports: [Report] {
        let calendar = Calendar.ptBR
        let now = Date()
        return [
            previewReport(id: "1", categoryCode: "OBSTETRICA", createdAt: calendar.date(byAdding: .minute, value: -40, to: now) ?? now),
            previewReport(id: "2", categoryCode: "OBSTETRICA", createdAt: calendar.date(byAdding: .minute, value: -31, to: now) ?? now),
            previewReport(id: "3", categoryCode: "PELVE_FEMININA", createdAt: calendar.date(byAdding: .minute, value: -20, to: now) ?? now),
            previewReport(id: "4", categoryCode: "TIREOIDE", createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now)
        ]
    }

    static func previewReport(id: String, categoryCode: String, createdAt: Date, output: String = "Laudo com nódulo e esteatose.") -> Report {
        Report(
            id: id,
            categoryCode: categoryCode,
            writingStyle: nil,
            status: .generated,
            rawInput: nil,
            consolidatedTranscript: nil,
            generatedOutput: output,
            finalOutput: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
