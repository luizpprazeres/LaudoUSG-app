import SwiftUI

@MainActor
struct TourFlowView: View {
    let onFinish: () -> Void

    @State private var selectedPage: Int = 0
    private let totalPages: Int = 4

    var body: some View {
        ZStack {
            AppSurface.background.ignoresSafeArea()
            VStack(spacing: 0) {
                skipBar
                TabView(selection: $selectedPage) {
                    pageWelcome.tag(0)
                    pageGenerate.tag(1)
                    pageConsultor.tag(2)
                    pageReady.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeOut(duration: 0.18), value: selectedPage)
                pageControl
                ctaButton
            }
        }
    }

    private var skipBar: some View {
        HStack {
            Spacer()
            if selectedPage < totalPages - 1 {
                Button("Pular", action: onFinish)
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
            }
        }
    }

    private var pageWelcome: some View {
        tourPage(
            icon: "stethoscope",
            iconTint: BrandColor.primary,
            title: "Bem-vindo ao LaudoUSG",
            subtitle: "Geração de laudos de ultrassonografia em segundos. Feito por médico, pra médico.",
            highlights: []
        )
    }

    private var pageGenerate: some View {
        tourPage(
            icon: "mic.circle.fill",
            iconTint: BrandColor.primary,
            title: "Dite, a IA estrutura",
            subtitle: "Fale seus achados. Em segundos você tem o laudo formatado, com biometria, percentis e Doppler calculados automaticamente.",
            highlights: ["13+ categorias de USG", "Atalhos clínicos rápidos", "Análise de imagem por IA"]
        )
    }

    private var pageConsultor: some View {
        tourPage(
            icon: "sparkles",
            iconTint: Color(hex: "8B5CF6"),
            title: "Consultor IA",
            subtitle: "No plano PRO, abra um chat com a IA que recebe seu laudo como contexto e sugere diagnósticos diferenciais, conduta e referências.",
            highlights: ["Até 5 imagens por consulta", "Modo thinking (raciocínio aprofundado)", "Embasado em literatura clínica"]
        )
    }

    private var pageReady: some View {
        tourPage(
            icon: "checkmark.seal.fill",
            iconTint: BrandColor.primary,
            title: "Comece com 3 dias grátis",
            subtitle: "Teste tudo sem compromisso. Cancele em 1 clique a qualquer momento antes do fim do trial.",
            highlights: ["Sem cartão até o fim do trial", "Suporte direto via WhatsApp", "Cancele em 1 toque"]
        )
    }

    private func tourPage(icon: String, iconTint: Color, title: String, subtitle: String, highlights: [String]) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.lg)
            Image(systemName: icon)
                .font(.system(size: 72, weight: .medium))
                .foregroundStyle(iconTint)
                .frame(width: 120, height: 120)
                .background(
                    Circle().fill(iconTint.opacity(0.12))
                )
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(TextStyle.h2)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(highlights, id: \.self) { item in
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(BrandColor.primary)
                            Text(item)
                                .font(TextStyle.bodyLarge)
                                .foregroundStyle(AppSurface.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var pageControl: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<totalPages, id: \.self) { idx in
                Capsule()
                    .fill(idx == selectedPage ? BrandColor.primary : AppSurface.textMuted.opacity(0.4))
                    .frame(width: idx == selectedPage ? 24 : 8, height: 8)
                    .animation(.easeOut(duration: 0.18), value: selectedPage)
            }
        }
        .padding(.bottom, Spacing.md)
    }

    private var ctaButton: some View {
        Button {
            Haptics.tap()
            if selectedPage < totalPages - 1 {
                withAnimation(.easeOut(duration: 0.18)) { selectedPage += 1 }
            } else {
                onFinish()
            }
        } label: {
            Text(selectedPage < totalPages - 1 ? "Próximo" : "Ver planos")
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(BrandColor.primary)
                )
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.lg)
    }
}

#Preview {
    TourFlowView(onFinish: {})
}
