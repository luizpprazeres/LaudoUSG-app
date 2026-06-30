import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Fundo fotográfico full-bleed das telas emocionais do onboarding: foto cobrindo
/// a tela, gradiente escuro inferior (garante contraste do texto independente da
/// foto) e um slot de conteúdo ancorado embaixo. Fallback escuro se a imagem faltar.
/// O conteúdo (textos/botões) deve usar cores claras — o fundo é sempre escuro.
struct OnboardingPhotoBackdrop<Content: View>: View {
    let imageName: String
    @ViewBuilder var content: Content

    private var imageExists: Bool {
        #if canImport(UIKit)
        UIImage(named: imageName) != nil
        #else
        true
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if imageExists {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(hex: "0B0B0F")
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.md) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingPhotoBackdrop(imageName: "OnboardingWelcome") {
        Text("Bem-vindo,\nLuiz.")
            .font(TextStyle.h1)
            .foregroundStyle(.white)
        Text("Vamos fazer seu primeiro laudo agora. Em 60 segundos você entende o fluxo inteiro.")
            .font(TextStyle.bodyLarge)
            .foregroundStyle(.white.opacity(0.9))
        PrimaryButton(title: "Vamos lá", icon: "arrow.right") {}
    }
}
