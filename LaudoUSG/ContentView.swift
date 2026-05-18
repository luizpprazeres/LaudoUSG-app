import SwiftUI

struct ContentView: View {
    let app: AppState

    var body: some View {
        AppShellView(app: app)
    }
}

#Preview {
    ContentView(app: AppState())
}
