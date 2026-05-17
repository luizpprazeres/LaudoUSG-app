import SwiftUI

struct CategorySheet: View {
    @Binding var selection: ReportCategory?
    let onDismiss: () -> Void

    @State private var search = ""

    private var priorityCategories: [ReportCategory] {
        filtered(ReportCategory.priority)
    }

    private var otherCategories: [ReportCategory] {
        let prioritySet = Set(ReportCategory.priority)
        return filtered(ReportCategory.allCases.filter { !prioritySet.contains($0) })
    }

    private var hasResults: Bool {
        !priorityCategories.isEmpty || !otherCategories.isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            header
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)

            searchField
                .padding(.horizontal, Spacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if !priorityCategories.isEmpty {
                        categorySection(title: "Mais usadas", categories: priorityCategories)
                    }

                    if !otherCategories.isEmpty {
                        categorySection(title: "Todas as categorias", categories: otherCategories)
                    }

                    if !hasResults {
                        emptyState
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(AppSurface.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("Escolher categoria")
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)

            Spacer()

            SecondaryButton(title: "Fechar", action: onDismiss)
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppSurface.textMuted)

            TextField("Buscar categoria", text: $search)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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

    private func categorySection(title: String, categories: [ReportCategory]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: Spacing.xs) {
                ForEach(categories) { category in
                    categoryRow(category)
                }
            }
        }
    }

    private func categoryRow(_ category: ReportCategory) -> some View {
        Button {
            selection = category
            onDismiss()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: category.iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(category.tint)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .fill(category.tint.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(category.label)
                        .font(TextStyle.bodyLargeMedium)
                        .foregroundStyle(AppSurface.textPrimary)

                    Text(category.subtitle)
                        .font(TextStyle.footnote)
                        .foregroundStyle(AppSurface.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSurface.textMuted)
            }
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
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(category.label), \(category.subtitle)")
    }

    private var emptyState: some View {
        Text("Nenhuma categoria encontrada")
            .font(TextStyle.bodyMedium)
            .foregroundStyle(AppSurface.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
    }

    private func filtered(_ categories: [ReportCategory]) -> [ReportCategory] {
        let query = normalized(search)
        guard !query.isEmpty else { return categories }

        return categories.filter { category in
            normalized(category.label).contains(query) ||
                normalized(category.subtitle).contains(query)
        }
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
    }
}

#Preview {
    @Previewable @State var selection: ReportCategory? = .tireoide

    CategorySheet(selection: $selection) {}
}
