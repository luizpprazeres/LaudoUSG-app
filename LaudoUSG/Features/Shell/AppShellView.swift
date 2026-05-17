import SwiftUI

struct AppShellView: View {
    @State private var app = AppState()

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
    }

    private func loadPostLogin() async {
        async let profile = ProfileService.fetchProfile()
        async let styles = ProfileService.fetchWritingStyles()
        if let profileValue = try? await profile,
           let styleId = profileValue.defaultWritingStyleId {
            app.defaultWritingStyleId = styleId
        }
        if let stylesValue = try? await styles {
            app.availableStyles = stylesValue
        }
    }

    private var splashView: some View {
        ZStack {
            AppSurface.background.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                BrandLogo(size: .large)
                ProgressView()
                    .tint(BrandColor.primary)
            }
        }
    }
}

#Preview {
    AppShellView()
}
