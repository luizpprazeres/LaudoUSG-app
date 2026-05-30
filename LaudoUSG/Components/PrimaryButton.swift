import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var showsCompletion = false
    @State private var completionTask: Task<Void, Never>?

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: Spacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(TextStyle.bodySemibold)
                }
                .opacity(isLoading || showsCompletion ? 0 : 1)
                .scaleEffect(
                    x: isLoading || showsCompletion ? 0.94 : 1,
                    y: isLoading || showsCompletion ? 0.85 : 1
                )

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .controlSize(.small)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }

                if showsCompletion {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .transition(
                            .symbolEffect(.appear)
                                .combined(with: .scale(0.82))
                        )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(isDisabled ? BrandColor.primary.opacity(0.5) : BrandColor.primary)
            )
            .animation(.laudousgSmooth, value: isLoading)
            .animation(.laudousgSmooth, value: showsCompletion)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96))
        .disabled(isDisabled || isLoading || showsCompletion)
        .onChange(of: isLoading) { wasLoading, loading in
            guard wasLoading && !loading else { return }
            completionTask?.cancel()
            showsCompletion = true
            completionTask = Task {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                showsCompletion = false
            }
        }
        .onDisappear {
            completionTask?.cancel()
        }
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
    var pressedScale: CGFloat = 0.98

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton(title: "Gerar laudo", icon: "sparkles") {}
        PrimaryButton(title: "Gerando...", isLoading: true) {}
    }
    .padding()
    .background(AppSurface.background)
}
