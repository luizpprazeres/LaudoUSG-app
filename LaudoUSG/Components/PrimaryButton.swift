import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(TextStyle.bodySemibold)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(isDisabled ? BrandColor.primary.opacity(0.5) : BrandColor.primary)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isDisabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(TextStyle.bodyMedium)
            }
            .frame(minHeight: 40)
            .padding(.horizontal, Spacing.sm)
            .foregroundStyle(AppSurface.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
