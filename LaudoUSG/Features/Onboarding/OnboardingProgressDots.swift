import SwiftUI

/// Indicador de progresso do onboarding. O ponto ativo vira uma cápsula alongada.
/// `onDark` adapta as cores para uso sobre foto (telas emocionais) ou sobre o
/// fundo claro do app (telas funcionais).
struct OnboardingProgressDots: View {
    let index: Int
    let count: Int
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: i == index ? 18 : 6, height: 6)
                    .animation(.spring(duration: 0.35, bounce: 0.2), value: index)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Passo \(index + 1) de \(count)")
    }

    private func color(for i: Int) -> Color {
        if i == index { return onDark ? Color(hex: "34D399") : BrandColor.primary }
        return onDark ? Color.white.opacity(0.4) : AppSurface.border
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingProgressDots(index: 0, count: 6)
        OnboardingProgressDots(index: 2, count: 6, onDark: true)
            .padding()
            .background(.black)
    }
    .padding()
}
