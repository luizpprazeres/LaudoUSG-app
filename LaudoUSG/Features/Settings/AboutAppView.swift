import SwiftUI

struct AboutAppView: View {
    /// Contador do gesto escondido que destrava Ajustes → Desenvolvedor.
    /// Ver `AppExperiments.developerToolsUnlocked` para o porquê de ser um gesto.
    @State private var versionTaps = 0
    @State private var unlockToast: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.sm) {
                    Image("LaudoUSGLogoFont")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .accessibilityLabel("LaudoUSG")
                    Text("Laudos médicos com IA")
                        .font(TextStyle.bodyLargeMedium)
                        .foregroundStyle(AppSurface.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)

                section(title: "Aplicativo") {
                    infoRow("Versão", appVersion)
                        // Nada indica que isto é tocável — é essa a intenção.
                        .contentShape(Rectangle())
                        .onTapGesture { registerVersionTap() }
                    Divider().padding(.leading, Spacing.md)
                    infoRow("Build", buildNumber)
                }

                if let unlockToast {
                    Text(unlockToast)
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textSecondary)
                        .transition(.opacity)
                }

                section(title: "Documentos legais") {
                    legalLink(.termsOfUse)
                    Divider().padding(.leading, Spacing.md)
                    legalLink(.privacyPolicy)
                    Divider().padding(.leading, Spacing.md)
                    legalLink(.medicalDisclaimer)
                }

                Text("© 2026 LaudoUSG. Contato: contato@laudousg.com")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Sobre o LaudoUSG")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 7 toques na versão alternam a seção Desenvolvedor. Silencioso até o fim:
    /// quem tocar sem querer não vê nada e o contador é descartado ao sair.
    private func registerVersionTap() {
        versionTaps += 1
        guard versionTaps >= AppExperiments.developerUnlockTapCount else { return }
        versionTaps = 0
        let enabling = !AppExperiments.developerToolsUnlocked
        AppExperiments.setDeveloperToolsUnlocked(enabling)
        Haptics.tap()
        withAnimation {
            unlockToast = enabling
                ? "Ferramentas de desenvolvedor ativadas."
                : "Ferramentas de desenvolvedor desativadas."
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
            Text(value)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
    }

    private func legalLink(_ doc: LegalDocKind) -> some View {
        NavigationLink {
            MarkdownDocumentView(title: doc.title, resourceName: doc.bundleResourceName)
        } label: {
            HStack {
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
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 56)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    NavigationStack {
        AboutAppView()
    }
    .environment(AppState())
}
