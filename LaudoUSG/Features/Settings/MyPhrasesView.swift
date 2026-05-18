import SwiftUI

@MainActor
@Observable
final class MyPhrasesViewModel {
    var phrases: [UserPhrase] = []
    var isLoading: Bool = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let fetchedPhrases = try await UserPhrasesService.fetch()
            withAnimation(.easeOut(duration: 0.25)) {
                phrases = fetchedPhrases
            }
        } catch let err as SupabaseError {
            error = err.errorDescription
            phrases = []
        } catch let other {
            error = other.localizedDescription
            phrases = []
        }
    }

    func delete(id: String) async {
        do {
            try await UserPhrasesService.delete(id: id)
            withAnimation(.easeOut(duration: 0.22)) {
                phrases.removeAll { $0.id == id }
            }
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func move(from source: IndexSet, to destination: Int) async {
        withAnimation(.easeInOut(duration: 0.2)) {
            phrases.move(fromOffsets: source, toOffset: destination)
        }
        await persistPositions()
    }

    private func persistPositions() async {
        let snapshot = phrases.enumerated().map { ($0.element.id, $0.offset, $0.element) }
        await withTaskGroup(of: Void.self) { group in
            for (id, position, phrase) in snapshot where phrase.position != position {
                let draft = UserPhraseDraft(
                    title: phrase.title,
                    body: phrase.body,
                    categoryCode: phrase.categoryCode,
                    position: position
                )
                group.addTask {
                    try? await UserPhrasesService.update(id: id, draft: draft)
                }
            }
        }
        Haptics.tap()
    }
}

struct MyPhrasesView: View {
    @State private var vm = MyPhrasesViewModel()
    @State private var editingPhrase: UserPhrase?
    @State private var isCreating: Bool = false

    var body: some View {
        Group {
            if vm.isLoading && vm.phrases.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error, vm.phrases.isEmpty {
                errorState(error)
            } else if vm.phrases.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Minhas frases")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(BrandColor.primary)
                }
                .accessibilityLabel("Nova frase")
            }
            if !vm.phrases.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $isCreating) {
            PhraseEditorSheet(
                draft: UserPhraseDraft(title: "", body: "", categoryCode: nil, position: vm.phrases.count),
                onSaved: { Task { await vm.load() } }
            )
        }
        .sheet(item: $editingPhrase) { phrase in
            PhraseEditorSheet(
                existingId: phrase.id,
                draft: UserPhraseDraft(
                    title: phrase.title,
                    body: phrase.body,
                    categoryCode: phrase.categoryCode,
                    position: phrase.position
                ),
                onSaved: { Task { await vm.load() } }
            )
        }
    }

    private var list: some View {
        List {
            ForEach(vm.phrases) { phrase in
                phraseRow(phrase)
                    .listRowBackground(AppSurface.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Spacing.xxs, leading: Spacing.md, bottom: Spacing.xxs, trailing: Spacing.md))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await vm.delete(id: phrase.id) }
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
            }
            .onMove { source, destination in
                Task { await vm.move(from: source, to: destination) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppSurface.background)
    }

    private func phraseRow(_ phrase: UserPhrase) -> some View {
        Button {
            editingPhrase = phrase
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(phrase.title)
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(phrase.body)
                        .font(TextStyle.body)
                        .foregroundStyle(AppSurface.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let categoryCode = phrase.categoryCode,
                       let category = ReportCategory(rawValue: categoryCode) {
                        Text(category.label)
                            .font(TextStyle.caption)
                            .foregroundStyle(category.tint)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(category.tint.opacity(0.12)))
                    }
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurface.textMuted)
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
        .buttonStyle(PressableButtonStyle())
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "text.append")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppSurface.textMuted)
            Text("Nenhuma frase salva ainda.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            Text("Toque em + acima para criar a primeira.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(SemanticColor.errorText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            Button("Tentar de novo") {
                Task { await vm.load() }
            }
            .foregroundStyle(BrandColor.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PhraseEditorSheet: View {
    var existingId: String?
    @State var draft: UserPhraseDraft
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    field(label: "Título") {
                        TextField("Ex: Tireoide normal", text: $draft.title)
                            .font(TextStyle.bodyLarge)
                    }
                    field(label: "Corpo da frase") {
                        TextEditor(text: $draft.body)
                            .font(TextStyle.bodyLarge)
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                    }
                    categoryPicker
                    if let errorMessage {
                        Text(errorMessage)
                            .font(TextStyle.body)
                            .foregroundStyle(SemanticColor.errorText)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .background(AppSurface.background.ignoresSafeArea())
            .navigationTitle(existingId == nil ? "Nova frase" : "Editar frase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(AppSurface.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Salvar")
                                .font(TextStyle.bodySemibold)
                                .foregroundStyle(canSave ? BrandColor.primary : AppSurface.textMuted)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Categoria (opcional)")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            Menu {
                Button("Todas as categorias") {
                    draft.categoryCode = nil
                }
                Divider()
                ForEach(ReportCategory.priority) { category in
                    Button(category.label) {
                        draft.categoryCode = category.rawValue
                    }
                }
            } label: {
                HStack {
                    Text(currentCategoryLabel)
                        .font(TextStyle.bodyLarge)
                        .foregroundStyle(AppSurface.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppSurface.textMuted)
                }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(AppSurface.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(AppSurface.border, lineWidth: 1)
                )
            }
        }
    }

    private var currentCategoryLabel: String {
        guard let code = draft.categoryCode,
              let category = ReportCategory(rawValue: code) else {
            return "Todas as categorias"
        }
        return category.label
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            content()
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(AppSurface.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(AppSurface.border, lineWidth: 1)
                )
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let existingId {
                try await UserPhrasesService.update(id: existingId, draft: draft)
            } else {
                try await UserPhrasesService.create(draft)
            }
            Haptics.success()
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

#Preview {
    NavigationStack { MyPhrasesView() }
}
