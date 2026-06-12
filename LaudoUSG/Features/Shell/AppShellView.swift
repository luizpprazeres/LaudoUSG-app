import SwiftUI

struct AppShellView: View {
    let app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var splashLogoScale: CGFloat = 0.96
    @State private var splashLogoOpacity: Double = 0
    @State private var splashStatusText = "Verificando sessão…"

    @AppStorage("laudousg.hasSeenTour") private var hasSeenTour: Bool = false
    @State private var isTourPresented: Bool = false
    @State private var isPostTourPaywallPresented: Bool = false

    // Apresentação reativa: modais aparecem/fecham automaticamente conforme
    // o estado do AppState muda. Sem timing race entre loadPostLogin e UI.
    private var showLegalGate: Binding<Bool> {
        Binding(
            get: {
                app.session == .authenticated
                && app.profile != nil
                && app.needsLegalAcceptance
            },
            set: { _ in }
        )
    }

    private var showOnboardingGate: Binding<Bool> {
        Binding(
            get: {
                app.session == .authenticated
                && app.profile != nil
                && !app.needsLegalAcceptance
                && app.needsOnboarding
            },
            set: { _ in }
        )
    }

    var body: some View {
        Group {
            switch app.session {
            case .checking:
                splashView
            case .signedOut:
                LoginView()
            case .authenticated:
                GenerateView()
            }
        }
        .environment(app)
        .task {
            splashStatusText = "Verificando sessão…"
            if let session = await AuthService.shared.restoreSession() {
                app.signIn(email: session.email, name: nil)
                splashStatusText = "Carregando perfil…"
                await loadPostLogin()
            } else {
                app.markChecked(signedIn: false)
            }
        }
        .onChange(of: app.session) { _, newValue in
            if newValue == .authenticated {
                Task { await loadPostLogin() }
            }
        }
        .fullScreenCover(isPresented: showLegalGate) {
            DisclaimerAcceptModal(onAccepted: {})
                .environment(app)
        }
        .fullScreenCover(isPresented: showOnboardingGate) {
            OnboardingFlow(onCompleted: {})
                .environment(app)
        }
        .fullScreenCover(isPresented: $isTourPresented) {
            TourFlowView {
                hasSeenTour = true
                isTourPresented = false
                if app.profile?.hasEssencialOrAbove != true {
                    isPostTourPaywallPresented = true
                }
            }
        }
        .sheet(isPresented: $isPostTourPaywallPresented) {
            PaywallSheet(
                onSuccess: {
                    isPostTourPaywallPresented = false
                    Task { await app.refreshProfile() }
                },
                onDismiss: { isPostTourPaywallPresented = false }
            )
        }
        .onChange(of: app.session) { _, newValue in
            guard newValue == .authenticated else { return }
            if !hasSeenTour
                && app.profile != nil
                && !app.needsLegalAcceptance
                && !app.needsOnboarding {
                isTourPresented = true
            }
        }
    }

    private func loadPostLogin() async {
        async let profile = ProfileService.fetchProfile()
        async let styles = ProfileService.fetchWritingStyles()
        async let reportPreferences = ProfileService.fetchReportPreferences()
        if let profileValue = try? await profile {
            app.updateProfile(profileValue)
        }
        if let stylesValue = try? await styles {
            app.availableStyles = stylesValue
        }
        if let preferencesValue = try? await reportPreferences, app.session == .authenticated {
            app.reportPreferences = preferencesValue.preferences
            app.availableVariants = preferencesValue.availableVariants
        }
    }

    private var splashView: some View {
        ZStack {
            AppSurface.background.ignoresSafeArea()
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    Image("LaudoUSGLogoFont")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .accessibilityLabel("LaudoUSG")
                        .scaleEffect(splashLogoScale)
                        .opacity(splashLogoOpacity)

                    Rectangle()
                        .fill(AppSurface.textPrimary.opacity(0.08))
                        .frame(width: 40, height: 0.5)
                        .opacity(splashLogoOpacity)

                    Text("Laudos em segundos.")
                        .font(TextStyle.bodyMedium)
                        .foregroundStyle(AppSurface.textPrimary)
                        .opacity(splashLogoOpacity)
                }

                VStack(spacing: Spacing.sm) {
                    DotTrioLoader()
                    Text(splashStatusText)
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                        .animation(.easeInOut(duration: 0.25), value: splashStatusText)
                }
                .opacity(splashLogoOpacity)
            }
        }
        .onAppear {
            if reduceMotion {
                splashLogoScale = 1.0
                splashLogoOpacity = 1.0
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    splashLogoScale = 1.0
                    splashLogoOpacity = 1.0
                }
            }
        }
    }
}

#Preview {
    AppShellView(app: AppState())
}
