import SwiftUI

@main
struct LaudoUSGWatchApp: App {
    @State private var appState = WatchAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}
