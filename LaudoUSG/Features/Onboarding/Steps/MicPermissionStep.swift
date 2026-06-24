import SwiftUI

struct MicPermissionStep: View {
    let isRequesting: Bool
    let permissionDenied: Bool
    let onRequestPermission: () -> Void
    let onClose: () -> Void

    @State private var bounceTrigger = 0
    @State private var successTrigger = 0

    var body: some View {
        OnboardingStepContainer {
            Spacer(minLength: Spacing.lg)

            Image(systemName: permissionDenied ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(permissionDenied ? SemanticColor.errorText : BrandColor.primary)
                .frame(width: 92, height: 92)
                .background(
                    Circle().fill(permissionDenied ? SemanticColor.errorBg : BrandColor.primaryTint)
                )
                .symbolEffect(.bounce, value: bounceTrigger)
                .sensoryFeedback(.success, trigger: successTrigger)

            VStack(spacing: Spacing.sm) {
                Text(permissionDenied ? "Microfone bloqueado." : "Pra você ditar, preciso do microfone.")
                    .font(TextStyle.h2)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.center)

                Text(permissionDenied ? "Abra Ajustes do iOS, entre em LaudoUSG e ative Microfone. Você pode fechar o onboarding agora e voltar depois." : "O áudio é usado para transcrição. Não armazenamos áudio nem dados de paciente.")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                checklistItem("Áudio não vira dado de paciente no banco.")
                checklistItem("Você revisa e assina o laudo final.")
                checklistItem("A permissão pode ser revogada nos Ajustes.")
            }
            .padding(.vertical, Spacing.sm)

            Spacer()

            if permissionDenied {
                SecondaryButton(title: "Fechar onboarding", icon: "xmark") {
                    onClose()
                }
            } else {
                PrimaryButton(
                    title: "Continuar",
                    icon: "arrow.right",
                    isLoading: isRequesting,
                    isDisabled: isRequesting
                ) {
                    bounceTrigger += 1
                    successTrigger += 1
                    onRequestPermission()
                }
            }
        }
    }

    private func checklistItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BrandColor.primary)
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            Spacer(minLength: 0)
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
