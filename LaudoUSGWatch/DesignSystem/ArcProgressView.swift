import SwiftUI

struct ArcProgressView: View {
    let size: CGFloat

    @State private var rotation = 0.0

    init(size: CGFloat = 72) {
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(WatchTheme.brand.opacity(0.15), lineWidth: 2)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(WatchTheme.brand, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    ArcProgressView()
}
