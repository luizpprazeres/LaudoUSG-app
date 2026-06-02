import SwiftUI

struct MicCaptureButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(WatchTheme.danger.opacity(0.5), lineWidth: 2)
                            .frame(width: WatchTheme.touchHero, height: WatchTheme.touchHero)
                            .scaleEffect(isPulsing ? 1.45 : 0.92)
                            .opacity(isPulsing ? 0 : 0.65)
                            .animation(
                                .easeOut(duration: 1.6)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.4),
                                value: isPulsing
                            )
                    }
                }

                Circle()
                    .fill(isRecording ? WatchTheme.danger : WatchTheme.brand)
                    .frame(width: WatchTheme.touchHero, height: WatchTheme.touchHero)
                    .shadow(
                        color: (isRecording ? WatchTheme.danger : WatchTheme.brand).opacity(0.5),
                        radius: 12
                    )

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: isRecording)
            }
            .frame(width: WatchTheme.touchHero, height: WatchTheme.touchHero)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .heavy), trigger: isRecording)
        .onAppear {
            isPulsing = isRecording
        }
        .onChange(of: isRecording) { _, newValue in
            isPulsing = newValue
        }
    }
}

#Preview {
    VStack {
        MicCaptureButton(isRecording: false) {}
        MicCaptureButton(isRecording: true) {}
    }
}
