import SwiftUI
import Observation

@MainActor
@Observable
final class AnalyticsViewModel {
    var isLoading = false
    var error: String?
    var summary: AnalyticsSummary?
    var reports: [Report] = []

    func load() async {
        isLoading = true
        error = nil

        do {
            async let fetchedSummary = AnalyticsService.fetch()
            async let fetchedReports = HistoryService.fetchRecentReports(limit: 500)
            summary = try await fetchedSummary
            reports = try await fetchedReports
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch let other {
            error = other.localizedDescription
        }

        isLoading = false
    }
}

struct AnalyticsView: View {
    @State private var vm = AnalyticsViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        Group {
            if vm.isLoading && vm.summary == nil {
                loadingState
            } else if let error = vm.error, vm.summary == nil {
                errorState(error)
            } else if let summary = vm.summary, summary.totalReports == 0 {
                emptyState
            } else if let summary = vm.summary {
                content(summary)
            } else {
                emptyState
            }
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(AppSurface.textMuted)

            Text("Gere seu primeiro laudo pra ver suas estatísticas.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(SemanticColor.errorText)

            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            Button("Tentar de novo") {
                Task { await vm.load() }
            }
            .font(TextStyle.bodyMedium)
            .foregroundStyle(BrandColor.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(_ summary: AnalyticsSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    metricCard(title: "Total de laudos", value: "\(summary.totalReports)", icon: "doc.text.fill")
                    metricCard(title: "Últimos 7 dias", value: "\(summary.reportsLast7d)", icon: "calendar")
                    metricCard(title: "Últimos 30 dias", value: "\(summary.reportsLast30d)", icon: "calendar.badge.clock")
                    metricCard(title: "Latência média", value: latency(summary.avgLatencyMs), icon: "speedometer")
                }

                topCategories(summary.topCategories)

                analyticsSection(title: "Calendário") {
                    DailyCalendarView(reports: vm.reports, month: Date())
                }

                analyticsSection(title: "Patologias frequentes") {
                    PathologyListView(aggregations: PathologyExtractor.extract(reports: vm.reports))
                }

                footer(summary)
            }
            .padding(Spacing.md)
        }
        .refreshable { await vm.load() }
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(BrandColor.primaryTint)
                    )

                Spacer()
            }

            Text(value)
                .font(TextStyle.h2)
                .foregroundStyle(AppSurface.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .lineLimit(2)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private func topCategories(_ categories: [CategoryStat]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Top categorias")
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)

            if categories.isEmpty {
                Text("Sem categorias suficientes ainda.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .fill(AppSurface.card)
                    )
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(categories) { category in
                        categoryRow(category, maxCount: categories.map(\.count).max() ?? 1)
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: CategoryStat, maxCount: Int) -> some View {
        let ratio = maxCount > 0 ? CGFloat(category.count) / CGFloat(maxCount) : 0

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(category.label)
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textPrimary)
                Spacer()
                Text("\(category.count)")
                    .font(TextStyle.bodySemibold)
                    .foregroundStyle(AppSurface.textSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppSurface.border)
                    Capsule()
                        .fill(BrandColor.primary)
                        .frame(width: max(6, proxy.size.width * ratio))
                }
            }
            .frame(height: 8)
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

    private func analyticsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)

            content()
        }
    }

    private func footer(_ summary: AnalyticsSummary) -> some View {
        footerItem(title: "Taxa de edição", value: "\(Int((summary.editsRatio * 100).rounded()))%")
    }

    private func footerItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            Text(value)
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(AppSurface.textPrimary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private func latency(_ milliseconds: Int?) -> String {
        guard let milliseconds else { return "-" }
        return String(format: "%.1fs", Double(milliseconds) / 1000)
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
}
