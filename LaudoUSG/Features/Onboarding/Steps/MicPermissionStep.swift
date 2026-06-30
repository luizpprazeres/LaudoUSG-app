import SwiftUI

struct MicPermissionStep: View {
    let isRequesting: Bool
    let permissionDenied: Bool
    let onRequestPermission: () -> Void
    let onClose: () -> Void

    @State private var successTrigger = 0

    var body: some View {
        OnboardingPhotoBackdrop(imageName: "OnboardingMic") {
            Text(permissionDenied ? "Microfone bloqueado." : "Pra ditar, preciso do microfone.")
                .font(TextStyle.h2)
                .foregroundStyle(.white)

            Text(permissionDenied
                 ? "Abra Ajustes do iOS, entre em LaudoUSG e ative Microfone. Você pode fechar o onboarding agora e voltar depois."
                 : "O áudio vira texto na hora. Não guardamos áudio nem dado de paciente.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)

            if permissionDenied {
                SecondaryButton(title: "Fechar onboarding", icon: "xmark") {
                    onClose()
                }
                .padding(.top, Spacing.xs)
            } else {
                PrimaryButton(
                    title: "Continuar",
                    icon: "mic.fill",
                    isLoading: isRequesting,
                    isDisabled: isRequesting
                ) {
                    successTrigger += 1
                    onRequestPermission()
                }
                .padding(.top, Spacing.xs)
                .sensoryFeedback(.success, trigger: successTrigger)
            }
        }
    }
}

#Preview("Permit") {
    MicPermissionStep(isRequesting: false, permissionDenied: false, onRequestPermission: {}, onClose: {})
        .background(AppSurface.background)
}

#Preview("Denied") {
    MicPermissionStep(isRequesting: false, permissionDenied: true, onRequestPermission: {}, onClose: {})
        .background(AppSurface.background)
}
