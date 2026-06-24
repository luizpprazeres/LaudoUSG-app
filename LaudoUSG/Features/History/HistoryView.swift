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

    var isSelectionMode: Bool = false
    var selectedIds: Set<String> = []
    var isDeleting: Bool = false

    var visibleReports: [Report] {
        let q = filter.trimmedSearch.lowercased()
        guard !q.isEmpty else { return reports }
        return reports.filter { report in
            let categoryLabel = report.category?.label.lowercased() ?? report.categoryCode.lowercased()
            if categoryLabel.contains(q) { return true }
            let bodies = [report.finalOutput, report.generatedOutput, report.rawInput]
            return bodies.contains { ($0 ?? "").lowercased().contains(q) }
        }
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            reports = try await HistoryService.fetchRecentReports(filter: filter)
            updateAvailableCategories()
            // #U5: descarta da seleção IDs que sumiram após o reload, pra o
            // contador e o delete em lote não operarem sobre itens fantasma.
            selectedIds.formIntersection(Set(reports.map { $0.id }))
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

    func enterSelectionMode() {
        isSelectionMode = true
        selectedIds.removeAll()
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedIds.removeAll()
    }

    func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    func selectAllVisible() {
        selectedIds = Set(visibleReports.map { $0.id })
    }

    func deleteSelected() async -> Bool {
        guard !selectedIds.isEmpty else { return true }
        isDeleting = true
        defer { isDeleting = false }
        do {
            let toDelete = Array(selectedIds)
            try await HistoryService.deleteReports(ids: toDelete)
            reports.removeAll { selectedIds.contains($0.id) }
            updateAvailableCategories()
            exitSelectionMode()
            return true
        } catch {
            self.error = (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
            return false
        }
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
    @State private var isConfirmingDelete: Bool = false
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
                } else if vm.visibleReports.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Histórico")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: Binding(
                get: { vm.filter.searchText },
                set: { vm.filter.searchText = $0 }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Buscar em laudos"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.isSelectionMode {
                    Button("Cancelar") { vm.exitSelectionMode() }
                } else {
                    Button {
                        vm.enterSelectionMode()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .disabled(vm.reports.isEmpty)
                    .accessibilityLabel("Selecionar laudos")
                }
            }
            if vm.isSelectionMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Todos") { vm.selectAllVisible() }
                        .disabled(vm.visibleReports.isEmpty)
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onChange(of: vm.reports.count) { _, newCount in
            if newCount > 0 && !hasAppeared {
                hasAppeared = true
            }
        }
        .overlay(alignment: .bottom) {
            if vm.isSelectionMode {
                deleteBar
                    .padding(.bottom, Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let result = vm.lastSalaResult {
                salaToast(result)
                    .padding(.bottom, Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: vm.lastSalaResult)
        .animation(.snappy, value: vm.isSelectionMode)
        .confirmationDialog(
            "Excluir \(vm.selectedIds.count) \(vm.selectedIds.count == 1 ? "laudo" : "laudos")?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) {
                Task { _ = await vm.deleteSelected() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(Array(vm.visibleReports.enumerated()), id: \.element.id) { index, report in
                    reportRow(report: report, index: index)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .padding(.bottom, vm.isSelectionMode ? 80 : 0)
        }
    }

    @ViewBuilder
    private func reportRow(report: Report, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if vm.isSelectionMode {
                Button {
                    Haptics.tap()
                    vm.toggleSelection(report.id)
                } label: {
                    selectableCard(report: report)
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                NavigationLink(value: AppDestination.reportDetail(id: report.id)) {
                    reportCard(report)
                }
                .buttonStyle(PressableButtonStyle())
                sendToSalaButton(report: report)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
        .animation(.easeOut(duration: 0.28).delay(min(Double(index) * 0.05, 0.5)), value: hasAppeared)
    }

    private func selectableCard(report: Report) -> some View {
        let isSelected = vm.selectedIds.contains(report.id)
        return HStack(spacing: Spacing.sm) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isSelected ? BrandColor.primary : AppSurface.textMuted)
            reportCard(report)
        }
    }

    private var deleteBar: some View {
        let count = vm.selectedIds.count
        let disabled = count == 0 || vm.isDeleting
        return HStack(spacing: Spacing.sm) {
            Text("\(count) selecionado\(count == 1 ? "" : "s")")
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
            Button {
                isConfirmingDelete = true
            } label: {
                HStack(spacing: 6) {
                    if vm.isDeleting {
                        ProgressView().controlSize(.mini).tint(.white)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Excluir")
                }
                .font(TextStyle.bodyMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Capsule().fill(disabled ? AppSurface.textMuted : SemanticColor.errorText))
            }
            .disabled(disabled)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(AppSurface.card)
                .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
        )
        .padding(.horizontal, Spacing.md)
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
                        .padding(.trailing, vm.isSelectionMode ? 0 : 32)
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
        let searchActive = !vm.filter.trimmedSearch.isEmpty
        let filterActive = vm.filter.isActive
        return VStack(spacing: Spacing.md) {
            Image(systemName: filterActive ? "line.3.horizontal.decrease.circle" : "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppSurface.textMuted)
            Text(searchActive
                ? "Nenhum laudo bate com “\(vm.filter.trimmedSearch)”."
                : filterActive
                    ? "Nenhum laudo bate com esses filtros."
                    : "Nenhum laudo ainda. Crie o primeiro.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            if filterActive {
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
