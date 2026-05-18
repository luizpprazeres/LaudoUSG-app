import SwiftUI

struct AppShellView: View {
    let app: AppState
    @State private var presentingLegalAcceptance = false
    @State private var presentingOnboarding = false

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
            if let session = await AuthService.shared.restoreSession() {
                app.signIn(email: session.email, name: nil)
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
        .fullScreenCover(isPresented: $presentingLegalAcceptance) {
            DisclaimerAcceptModal {
                presentOnboardingIfNeeded()
            }
            .environment(app)
        }
        .fullScreenCover(isPresented: $presentingOnboarding) {
            OnboardingView {
                presentingOnboarding = false
            }
            .environment(app)
        }
    }

    private func loadPostLogin() async {
        async let profile = ProfileService.fetchProfile()
        async let styles = ProfileService.fetchWritingStyles()
        if let profileValue = try? await profile {
            app.updateProfile(profileValue)
        }
        if let stylesValue = try? await styles {
            app.availableStyles = stylesValue
        }
        presentRequiredPostLoginFlow()
    }

    private func presentRequiredPostLoginFlow() {
        guard app.session == .authenticated else { return }
        if app.needsLegalAcceptance {
            presentingOnboarding = false
            presentingLegalAcceptance = true
        } else {
            presentOnboardingIfNeeded()
        }
    }

    private func presentOnboardingIfNeeded() {
        presentingLegalAcceptance = false
        guard app.session == .authenticated, app.needsOnboarding else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            presentingOnboarding = true
        }
    }

    private var splashView: some View {
        ZStack {
            AppSurface.background.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Image("LaudoUSGLogoFont")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .accessibilityLabel("LaudoUSG")
                ProgressView()
                    .tint(BrandColor.primary)
            }
        }
    }
}

#Preview {
    AppShellView(app: AppState())
}
