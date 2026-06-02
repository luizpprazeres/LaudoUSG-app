import SwiftUI

struct CategoryRow: View {
    let category: CategoryWatch

    var body: some View {
        HStack(spacing: WatchTheme.s3) {
            Circle()
                .fill(category.accent.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: category.symbolNew)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(category.accent)
                }
            Text(category.label)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(WatchTheme.textPrimary)
            Spacer()
        }
        .padding(.vertical, WatchTheme.s1)
    }
}

extension CategoryWatch {
    var symbolNew: String {
        switch self {
        case .obstetrica:        return "figure.2.and.child.holdinghands"
        case .pelveFeminina:     return "heart.text.clipboard"
        case .tireoide:          return "drop.fill"
        case .mamaria:           return "circle.lefthalf.filled"
        case .dopplerObstetrico: return "waveform.path.ecg"
        case .abdomenTotal:      return "rectangle.split.3x1.fill"
        case .morfologico:       return "scope"
        }
    }

    var accent: Color {
        switch self {
        case .obstetrica, .dopplerObstetrico, .morfologico:
            return Color(red: 0.95, green: 0.55, blue: 0.62)
        case .pelveFeminina:
            return Color(red: 0.85, green: 0.45, blue: 0.78)
        case .tireoide:
            return Color(red: 0.42, green: 0.65, blue: 0.95)
        case .mamaria:
            return Color(red: 0.92, green: 0.42, blue: 0.55)
        case .abdomenTotal:
            return WatchTheme.brand
        }
    }
}

#Preview {
    CategoryRow(category: .obstetrica)
}
