import SwiftUI

@MainActor
struct CalculatorsSheet: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var path: [CalculatorDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: Spacing.md) {
                header
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                VStack(spacing: Spacing.xs) {
                    calculatorLink(
                        title: "Idade gestacional",
                        subtitle: "DUM ou primeira ultrassonografia",
                        icon: "calendar",
                        destination: .ig
                    )

                    calculatorLink(
                        title: "Doppler obstétrico",
                        subtitle: "Umbilical, ACM, uterinas e RCP",
                        icon: "waveform.path.ecg",
                        destination: .doppler
                    )

                    disabledRow(
                        title: "Anemia",
                        subtitle: "Em breve",
                        icon: "drop"
                    )
                }
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
            .background(AppSurface.background.ignoresSafeArea())
            .navigationDestination(for: CalculatorDestination.self) { destination in
                switch destination {
                case .ig:
                    IGCalculatorSheet(onInsert: handleInsert, onDismiss: onDismiss)
                case .doppler:
                    DopplerCalculatorSheet(onInsert: handleInsert, onDismiss: onDismiss)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("Calculadoras")
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)

            Spacer()

            SecondaryButton(title: "Fechar", action: onDismiss)
        }
    }

    private func calculatorLink(
        title: String,
        subtitle: String,
        icon: String,
        destination: CalculatorDestination
    ) -> some View {
        NavigationLink(value: destination) {
            rowContent(title: title, subtitle: subtitle, icon: icon, tint: BrandColor.primary, disabled: false)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func disabledRow(title: String, subtitle: String, icon: String) -> some View {
        rowContent(title: title, subtitle: subtitle, icon: icon, tint: AppSurface.textMuted, disabled: true)
            .opacity(0.55)
            .accessibilityLabel("\(title), \(subtitle)")
    }

    private func rowContent(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        disabled: Bool
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(TextStyle.bodyLargeMedium)
                    .foregroundStyle(AppSurface.textPrimary)

                Text(subtitle)
                    .font(TextStyle.footnote)
                    .foregroundStyle(AppSurface.textSecondary)
            }

            Spacer()

            Image(systemName: disabled ? "lock" : "chevron.right")
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

    private func handleInsert(_ text: String) {
        onInsert(text)
        onDismiss()
    }
}

private enum CalculatorDestination: Hashable {
    case ig
    case doppler
}

#Preview {
    CalculatorsSheet(onInsert: { _ in }, onDismiss: {})
}
