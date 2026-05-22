import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    var reports: [Report] = []
    var isLoading: Bool = false
    var error: String?
    var filter: HistoryFilter = HistoryFilter()
    var availableCategories: [ReportCategory] = []
    var sendingToSalaIds: Set<String> = []
    var lastSalaResult: SalaPushResult?

    func load() async {
        isLoading = true
        error = nil
        do {
            reports = try await HistoryService.fetchRecentReports(filter: filter)
            updateAvailableCategories()
        } catch let err as SupabaseError {
            error = err.errorDescription
        } catch let other {
            error = other.localizedDescription
        }
        isLoading = false
    }

    func applyFilterAndReload() {
        Task { await load() }
    }

    private func updateAvailableCategories() {
        let inFilter = filter.categories
        let inResults = Set(reports.compactMap { $0.category })
        let union = inFilter.union(inResults)
        if union.isEmpty {
            availableCategories = ReportCategory.allCases
        } else {
            let extras = ReportCategory.allCases.filter { !union.contains($0) }
            availableCategories = Array(union).sorted { $0.label < $1.label } + extras
        }
    }
}

struct SalaPushResult: Identifiable, Equatable {
    let id = UUID()
    let success: Bool
    let message: String
}

struct HistoryView: View {
    @State private var vm = HistoryViewModel()
    @State private var hasAppeared: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HistoryFilterBar(
                filter: Binding(
                    get: { vm.filter },
                    set: { vm.filter = $0 }
                ),
                availableCategories: vm.availableCategories.isEmpty ? ReportCategory.allCases : vm.availableCategories,
                onChange: vm.applyFilterAndReload
            )
            .padding(.top, Spacing.xs)

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
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Histórico")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.reports.count) { _, newCount in
            if newCount > 0 && !hasAppeared {
                hasAppeared = true
            }
        }
        .overlay(alignment: .bottom) {
            if let result = vm.lastSalaResult {
                salaToast(result)
                    .padding(.bottom, Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: vm.lastSalaResult)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(Array(vm.reports.enumerated()), id: \.element.id) { index, report in
                    reportRow(report: report, index: index)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
    }

    @ViewBuilder
    private func reportRow(report: Report, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: AppDestination.reportDetail(id: report.id)) {
                reportCard(report)
            }
            .buttonStyle(PressableButtonStyle())

            sendToSalaButton(report: report)
                .padding(.top, Spacing.sm)
                .padding(.trailing, Spacing.sm)
        }
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
        .animation(.easeOut(duration: 0.28).delay(min(Double(index) * 0.05, 0.5)), value: hasAppeared)
    }

    private func sendToSalaButton(report: Report) -> some View {
        let isSending = vm.sendingToSalaIds.contains(report.id)
        return Button {
            sendToSala(report)
        } label: {
            Group {
                if isSending {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "paperplane")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(AppSurface.background)
            )
            .overlay(
                Circle().stroke(AppSurface.border, lineWidth: 1)
            )
            .foregroundStyle(AppSurface.textSecondary)
        }
        .accessibilityLabel("Enviar à sala")
        .disabled(isSending)
    }

    private func sendToSala(_ report: Report) {
        guard !vm.sendingToSalaIds.contains(report.id) else { return }
        vm.sendingToSalaIds.insert(report.id)
        Task {
            defer { vm.sendingToSalaIds.remove(report.id) }
            do {
                try await SalaService.pushReport(id: report.id)
                vm.lastSalaResult = SalaPushResult(success: true, message: "Enviado à sala")
            } catch {
                vm.lastSalaResult = SalaPushResult(
                    success: false,
                    message: "Falha ao enviar: \(error.localizedDescription)"
                )
            }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            vm.lastSalaResult = nil
        }
    }

    private func salaToast(_ result: SalaPushResult) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(result.success ? SemanticColor.successText : SemanticColor.errorText)
            Text(result.message)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(AppSurface.card)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
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
                        .padding(.trailing, 32)
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
            Image(systemName: vm.filter.isActive ? "line.3.horizontal.decrease.circle" : "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppSurface.textMuted)
            Text(vm.filter.isActive
                ? "Nenhum laudo bate com esses filtros."
                : "Nenhum laudo ainda. Crie o primeiro.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            if vm.filter.isActive {
                Button("Limpar filtros") {
                    vm.filter = HistoryFilter()
                    vm.applyFilterAndReload()
                }
                .font(TextStyle.bodyMedium)
                .foregroundStyle(BrandColor.primary)
            }
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
