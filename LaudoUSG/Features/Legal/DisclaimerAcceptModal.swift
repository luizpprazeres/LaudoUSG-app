import SwiftUI

struct DisclaimerAcceptModal: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let onAccepted: () -> Void

    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @State private var acceptedDisclaimer = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var presentedDoc: LegalDocKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Image("LaudoUSGLogoFont")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .accessibilityLabel("LaudoUSG")

                    VStack(spacing: Spacing.xs) {
                        Text("Antes de começar")
                            .font(TextStyle.h2)
                            .foregroundStyle(AppSurface.textPrimary)
                        Text("Para usar o LaudoUSG, leia e aceite os documentos abaixo.")
                            .font(TextStyle.body)
                            .foregroundStyle(AppSurface.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: Spacing.sm) {
                        documentCard(.termsOfUse, icon: "doc.text.fill")
                        documentCard(.privacyPolicy, icon: "lock.fill")
                        documentCard(.medicalDisclaimer, icon: "cross.case.fill")
                    }

                    VStack(spacing: Spacing.sm) {
                        checkbox("Li e aceito os Termos de Uso", isOn: $acceptedTerms)
                        checkbox("Li e aceito a Política de Privacidade", isOn: $acceptedPrivacy)
                        checkbox("Li e aceito o Disclaimer Médico", isOn: $acceptedDisclaimer)
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    PrimaryButton(
                        title: "Entendi e aceito",
                        icon: nil,
                        isLoading: isSaving,
                        isDisabled: !canAccept || isSaving
                    ) {
                        accept()
                    }

                    SecondaryButton(title: "Sair") {
                        Haptics.tap()
                        app.signOut()
                        dismiss()
                    }
                }
                .padding(Spacing.lg)
            }
            .background(AppSurface.background.ignoresSafeArea())
            .interactiveDismissDisabled(true)
            .sheet(item: $presentedDoc) { doc in
                NavigationStack {
                    MarkdownDocumentView(title: doc.title, resourceName: doc.bundleResourceName)
                }
            }
        }
    }

    private var canAccept: Bool {
        acceptedTerms && acceptedPrivacy && acceptedDisclaimer
    }

    private func documentCard(_ doc: LegalDocKind, icon: String) -> some View {
        Button {
            Haptics.tap()
            presentedDoc = doc
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(BrandColor.primaryTint)
                    )
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(doc.title)
                        .font(TextStyle.bodyLargeMedium)
                        .foregroundStyle(AppSurface.textPrimary)
                    Text("Versão \(doc.currentVersion)")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurface.textMuted)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func checkbox(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            Haptics.tap()
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn.wrappedValue ? BrandColor.primary : AppSurface.textMuted)
                Text(title)
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.errorText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(SemanticColor.errorText)
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(SemanticColor.errorBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(SemanticColor.errorBorder, lineWidth: 1)
        )
    }

    private func accept() {
        guard canAccept, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let acceptedAt = try await ProfileService.recordLegalAcceptance(
                    termsVersion: LegalVersions.termsOfUse,
                    privacyVersion: LegalVersions.privacyPolicy,
                    disclaimerVersion: LegalVersions.medicalDisclaimer
                )
                app.markLegalAccepted(at: acceptedAt)
                Haptics.success()
                dismiss()
                onAccepted()
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    DisclaimerAcceptModal(onAccepted: {})
        .environment(AppState())
}
