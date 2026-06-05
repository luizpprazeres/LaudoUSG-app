//
//  LaudoUSGApp.swift
//  LaudoUSG
//
//  Created by Luiz Prazeres on 16/05/26.
//

import SwiftUI

@main
struct LaudoUSGApp: App {
    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "light"
    @State private var appState = AppState()
    @State private var linkErrorMessage: String?
    @State private var recoverySession: AuthSession?

    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(app: appState)
                .preferredColorScheme(colorScheme)
                .task { WatchAudioInbox.shared.activate() }
                .onOpenURL { url in
                    guard url.scheme == "laudousg" else { return }
                    Task {
                        do {
                            let result = try await AuthService.shared.handleMagicLink(url)
                            await MainActor.run {
                                switch result {
                                case .signedIn(let session):
                                    appState.signIn(email: session.email, name: nil)
                                    Haptics.success()
                                case .passwordRecovery(let session):
                                    recoverySession = session
                                    Haptics.tap()
                                }
                            }
                        } catch {
                            await MainActor.run {
                                linkErrorMessage = "Este link é inválido ou expirou."
                                Haptics.error()
                            }
                        }
                    }
                }
                .fullScreenCover(item: $recoverySession) { session in
                    ResetPasswordView(session: session)
                }
                .alert("Link inválido", isPresented: Binding(
                    get: { linkErrorMessage != nil },
                    set: { if !$0 { linkErrorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {
                        linkErrorMessage = nil
                    }
                } message: {
                    Text(linkErrorMessage ?? "")
                }
        }
    }
}

extension AuthSession: Identifiable {
    var id: String { accessToken }
}
