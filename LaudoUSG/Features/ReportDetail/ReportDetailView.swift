import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class ReportDetailViewModel {
    let reportId: String
    var report: Report?
    var editingText: String = ""
    var isLoading: Bool = true
    var isSaving: Bool = false
    var error: String?
    var saveStatus: SaveStatus = .idle

    enum SaveStatus { case idle, saved, failed }

    private var saveTask: Task<Void, Never>?

    init(reportId: String) {
        self.reportId = reportId
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let fetched = try await HistoryService.fetchReport(id: reportId)
            self.report = fetched
            self.editingText = fetched.finalOutput ?? fetched.generatedOutput ?? ""
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func textChanged(_ newValue: String) {
        editingText = newValue
        saveStatus = .idle
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    func save() async {
        guard let report else { return }
        isSaving = true
        do {
            try await HistoryService.updateFinalOutput(reportId: report.id, finalText: editingText)
            saveStatus = .saved
        } catch {
            saveStatus = .failed
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

struct ReportDetailView: View {
    let reportId: String
    @State private var vm: ReportDetailViewModel
    @State private var selectedTab: Tab = .laudo
    @State private var didCopy: Bool = false
    @StateObject private var editorBridge = MarkdownEditorBridge()

    init(reportId: String) {
        self.reportId = reportId
        self._vm = State(initialValue: ReportDetailViewModel(reportId: reportId))
    }

    enum Tab: String, CaseIterable, Identifiable {
        case laudo, entendido, rag, meta
        var id: String { rawValue }
        var label: String {
            switch self {
            case .laudo: return "Laudo"
            case .entendido: return "Entendido"
            case .rag: return "RAG"
            case .meta: return "Meta"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            content
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle(vm.report?.category?.label ?? "Laudo")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: Spacing.xxs) {
                        Text(tab.label)
                            .font(TextStyle.bodyMedium)
                            .foregroundStyle(selectedTab == tab ? BrandColor.primary : AppSurface.textSecondary)
                        Rectangle()
                            .fill(selectedTab == tab ? BrandColor.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xs)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .background(AppSurface.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppSurface.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.error, vm.report == nil {
            VStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(SemanticColor.errorText)
                Text(error)
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                Button("Tentar de novo") { Task { await vm.load() } }
                    .foregroundStyle(BrandColor.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedTab == .laudo {
            laudoTab
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    switch selectedTab {
                    case .entendido: entendidoTab
                    case .rag: ragTab
                    case .meta: metaTab
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
        }
    }

    private var laudoTab: some View {
        VStack(spacing: 0) {
            formattingToolbar
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
            Divider()
            MarkdownTextEditor(
                text: Binding(get: { vm.editingText }, set: { vm.textChanged($0) }),
                bridge: editorBridge
            )
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            Divider()
            bottomActions
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
        }
    }

    private var formattingToolbar: some View {
        HStack(spacing: Spacing.xs) {
            toolbarButton(systemImage: "bold", label: "Negrito") {
                editorBridge.toggleBold()
            }
            toolbarButton(systemImage: "italic", label: "Itálico") {
                editorBridge.toggleItalic()
            }
            Divider().frame(height: 22)
            Button {
                Haptics.tap()
                applyHeadingHighlights()
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Destacar títulos")
                        .font(TextStyle.captionMedium)
                }
                .foregroundStyle(BrandColor.primary)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 32)
                .background(
                    Capsule().fill(BrandColor.primaryTint)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Destacar títulos do laudo em negrito")
            Spacer()
            saveIndicator
        }
    }

    private func toolbarButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppSurface.textPrimary)
                .frame(width: 36, height: 32)
        }
        .accessibilityLabel(label)
    }

    private func applyHeadingHighlights() {
        let next = MarkdownFormatter.highlightHeadings(vm.editingText)
        if next != vm.editingText {
            editorBridge.replaceAllText(next)
            Haptics.success()
        }
    }

    private var bottomActions: some View {
        HStack(spacing: Spacing.xs) {
            SecondaryButton(
                title: didCopy ? "Copiado" : "Copiar",
                icon: didCopy ? "checkmark" : "doc.on.doc"
            ) {
                performCopy()
            }
            Spacer()
        }
    }

    private func performCopy() {
        #if canImport(UIKit)
        UIPasteboard.general.string = vm.editingText
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        withAnimation(.easeOut(duration: 0.18)) { didCopy = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.18)) { didCopy = false }
        }
    }

    private var saveIndicator: some View {
        HStack(spacing: Spacing.xxs) {
            if vm.isSaving {
                ProgressView().controlSize(.mini)
                Text("Salvando…")
            } else {
                switch vm.saveStatus {
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SemanticColor.successText)
                    Text("Salvo")
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SemanticColor.errorText)
                    Text("Falha ao salvar")
                case .idle:
                    Image(systemName: "pencil")
                        .foregroundStyle(AppSurface.textMuted)
                    Text("Edite e o app salva automaticamente.")
                }
            }
            Spacer()
        }
        .font(TextStyle.caption)
        .foregroundStyle(AppSurface.textSecondary)
    }

    private var entendidoTab: some View {
        infoCard(
            title: "Entrada bruta",
            body: vm.report?.rawInput ?? "—"
        )
    }

    private var ragTab: some View {
        infoCard(
            title: "Conhecimento usado",
            body: "Blocos RAG aplicados estão disponíveis no laudo. Próximos sprints expõem lista detalhada."
        )
    }

    private var metaTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            row("Categoria", vm.report?.category?.label ?? vm.report?.categoryCode ?? "—")
            row("Status", vm.report?.status.rawValue ?? "—")
            row("Criado", formatted(vm.report?.createdAt))
            row("Atualizado", formatted(vm.report?.updatedAt))
            row("ID", reportId)
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

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            Spacer()
            Text(value)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func infoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(AppSurface.textPrimary)
            Text(body)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack { ReportDetailView(reportId: "preview-id") }
}
