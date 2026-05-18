import SwiftUI

struct DotTrioLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(BrandColor.primary)
                    .frame(width: 8, height: 8)
                    .opacity(reduceMotion ? 1.0 : (animating ? 1.0 : 0.3))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

#Preview {
    VStack(spacing: 32) {
        DotTrioLoader()
        DotTrioLoader()
            .scaleEffect(1.5)
    }
    .padding(40)
    .background(AppSurface.background)
}
