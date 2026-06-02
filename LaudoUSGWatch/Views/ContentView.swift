import SwiftUI

struct ContentView: View {
    @Environment(WatchAppState.self) private var app

    var body: some View {
        switch app.route {
        case .setup:
            SetupSalaView()
        case .categories:
            CategoryListView()
        case .recording(let category):
            RecordingView(category: category)
        case .generating(let category):
            GeneratingView(category: category)
        }
    }
}

#Preview {
    ContentView()
        .environment(WatchAppState())
}
