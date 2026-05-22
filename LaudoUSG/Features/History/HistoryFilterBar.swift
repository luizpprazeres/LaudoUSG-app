import SwiftUI

struct HistoryFilterBar: View {
    @Binding var filter: HistoryFilter
    let availableCategories: [ReportCategory]
    let onChange: () -> Void

    @State private var isCategorySheetPresented = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(HistoryDateRange.allCases) { range in
                    chip(
                        label: range.label,
                        isActive: filter.dateRange == range
                    ) {
                        filter.dateRange = range
                        onChange()
                    }
                }

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, Spacing.xxs)

                Button {
                    isCategorySheetPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.system(size: 11, weight: .medium))
                        Text(categoryLabel)
                            .font(TextStyle.caption)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(filter.categories.isEmpty ? AppSurface.card : BrandColor.primary.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(filter.categories.isEmpty ? AppSurface.border : BrandColor.primary.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundStyle(filter.categories.isEmpty ? AppSurface.textPrimary : BrandColor.primaryDeep)
                }

                if filter.isActive {
                    Button {
                        filter = HistoryFilter()
                        onChange()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppSurface.textMuted)
                    }
                    .padding(.leading, Spacing.xxs)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(height: 44)
        .background(AppSurface.background)
        .sheet(isPresented: $isCategorySheetPresented) {
            CategoryPickerSheet(
                available: availableCategories,
                selected: Binding(
                    get: { filter.categories },
                    set: { filter.categories = $0; onChange() }
                ),
                onDone: { isCategorySheetPresented = false }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var categoryLabel: String {
        if filter.categories.isEmpty {
            return "Categoria"
        }
        if filter.categories.count == 1, let only = filter.categories.first {
            return only.label
        }
        return "\(filter.categories.count) categorias"
    }

    @ViewBuilder
    private func chip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TextStyle.caption)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(isActive ? BrandColor.primary : AppSurface.card)
                )
                .overlay(
                    Capsule()
                        .stroke(isActive ? BrandColor.primary : AppSurface.border, lineWidth: 1)
                )
                .foregroundStyle(isActive ? Color.white : AppSurface.textPrimary)
        }
    }
}

private struct CategoryPickerSheet: View {
    let available: [ReportCategory]
    @Binding var selected: Set<ReportCategory>
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(available) { cat in
                        Button {
                            toggle(cat)
                        } label: {
                            HStack {
                                Image(systemName: cat.iconSystemName)
                                    .foregroundStyle(cat.tint)
                                    .frame(width: 24)
                                Text(cat.label)
                                    .foregroundStyle(AppSurface.textPrimary)
                                Spacer()
                                if selected.contains(cat) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(BrandColor.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtrar por categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") { selected.removeAll() }
                        .disabled(selected.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Pronto", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggle(_ cat: ReportCategory) {
        if selected.contains(cat) {
            selected.remove(cat)
        } else {
            selected.insert(cat)
        }
    }
}
