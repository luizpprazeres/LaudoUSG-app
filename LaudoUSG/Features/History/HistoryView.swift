import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    var reports: [Report] = []
    var isLoading: Bool = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            reports = try await HistoryService.fetchRecentReports()
        } catch let err as SupabaseError {
            error = err.errorDescription
        } catch let other {
            error = other.localizedDescription
        }
        isLoading = false
    }
}

struct HistoryView: View {
    @State private var vm = HistoryViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.reports.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppSurface.background)
            } else if let error = vm.error, vm.reports.isEmpty {
                errorState(error)
            } else if vm.reports.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Histórico")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(vm.reports) { report in
                    NavigationLink(value: AppDestination.reportDetail(id: report.id)) {
                        reportCard(report)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
    }

    private func reportCard(_ report: Report) -> some View {
        let category = report.category
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: category?.iconSystemName ?? "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(category?.tint ?? BrandColor.primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill((category?.tint ?? BrandColor.primary).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(category?.label ?? report.categoryCode)
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                    Spacer()
                    Text(formattedDate(report.createdAt))
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                }
                Text(reportPreview(report))
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
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

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppSurface.textMuted)
            Text("Nenhum laudo ainda. Crie o primeiro.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
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

    private func reportPreview(_ report: Report) -> String {
        let text = (report.finalOutput ?? report.generatedOutput ?? report.rawInput ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "(Sem conteúdo)" : text
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack { HistoryView() }
}
