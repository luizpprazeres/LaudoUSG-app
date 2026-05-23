import SwiftUI

struct PathologyListView: View {
    let aggregations: [PathologyAggregation]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if aggregations.isEmpty {
                Text("Sem patologias suficientes detectadas")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(cardBackground)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(aggregations) { aggregation in
                        pathologySection(aggregation)
                    }
                }
            }
        }
    }

    private func pathologySection(_ aggregation: PathologyAggregation) -> some View {
        DisclosureGroup {
            VStack(spacing: Spacing.sm) {
                ForEach(aggregation.pathologies, id: \.label) { item in
                    pathologyRow(item, maxCount: aggregation.pathologies.map(\.count).max() ?? 1)
                }
            }
            .padding(.top, Spacing.sm)
        } label: {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(categoryLabel(for: aggregation.categoryCode))
                        .font(TextStyle.bodyMedium)
                        .foregroundStyle(AppSurface.textPrimary)

                    Text("\(aggregation.totalReports) laudos")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
        .font(TextStyle.bodyMedium)
        .tint(AppSurface.textSecondary)
        .padding(Spacing.md)
        .background(cardBackground)
    }

    private func pathologyRow(_ item: (label: String, count: Int), maxCount: Int) -> some View {
        let ratio = maxCount > 0 ? CGFloat(item.count) / CGFloat(maxCount) : 0

        return HStack(spacing: Spacing.sm) {
            Text(item.label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textPrimary)
                .lineLimit(2)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BrandColor.primaryTint)

                    Capsule()
                        .fill(BrandColor.primary)
                        .frame(width: max(Spacing.xs, proxy.size.width * min(1, ratio)))
                }
            }
            .frame(height: 6)

            Text("\(item.count)")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .frame(minWidth: 24, alignment: .trailing)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
            .fill(AppSurface.card)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
    }

    private func categoryLabel(for code: String) -> String {
        ReportCategory(rawValue: code)?.label ?? code
    }
}

#Preview {
    PathologyListView(
        aggregations: [
            PathologyAggregation(
                id: "TIREOIDE",
                categoryCode: "TIREOIDE",
                totalReports: 24,
                pathologies: [
                    (label: "Nódulo tireoidiano", count: 12),
                    (label: "Bócio", count: 6),
                    (label: "Tireoidite", count: 3)
                ]
            ),
            PathologyAggregation(
                id: "ABDOMEN_TOTAL",
                categoryCode: "ABDOMEN_TOTAL",
                totalReports: 18,
                pathologies: [
                    (label: "Esteatose hepática", count: 8),
                    (label: "Litíase biliar", count: 4)
                ]
            )
        ]
    )
    .padding()
    .background(AppSurface.background)
}
