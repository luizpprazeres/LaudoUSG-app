import SwiftUI
import Combine

struct RecordingOverlay: View {
    @Binding var isPresented: Bool
    let liveTranscript: String
    let onCancel: () -> Void
    let onStop: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var barHeights = Array(repeating: CGFloat(18), count: 32)
    @State private var isVisible = false

    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.95))
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text(formattedElapsed)
                    .font(TextStyle.display)
                    .foregroundStyle(.white)
                    .monospacedDigit()

                waveform
                    .accessibilityElement()
                    .accessibilityLabel("Gravação em andamento")

                transcriptArea

                HStack(spacing: Spacing.sm) {
                    cancelButton
                    stopButton
                }
                .padding(.horizontal, Spacing.lg)
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = true
            }
        }
        .onReceive(timer) { _ in
            guard isPresented else { return }
            elapsed += 0.08

            withAnimation(.easeInOut(duration: 0.08)) {
                barHeights = barHeights.map { _ in CGFloat.random(in: 8...60) }
            }
        }
    }

    private var transcriptArea: some View {
        Text("Toque em Parar e usar quando terminar. A transcrição leva 2-3 segundos após parar.")
            .font(TextStyle.body)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(barHeights.indices, id: \.self) { index in
                Capsule()
                    .fill(BrandColor.primary)
                    .frame(width: 4, height: barHeights[index])
            }
        }
        .frame(height: 72)
    }

    private var cancelButton: some View {
        Button {
            isPresented = false
            onCancel()
        } label: {
            Text("Cancelar")
                .font(TextStyle.bodySemibold)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(NeutralColor.gray600.opacity(0.9))
                )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Cancelar gravação")
    }

    private var stopButton: some View {
        Button {
            isPresented = false
            onStop()
        } label: {
            Text("Parar e usar")
                .font(TextStyle.bodySemibold)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(Color(hex: "FF3B30"))
                )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Parar gravação e usar áudio")
    }

    private var formattedElapsed: String {
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    @Previewable @State var isPresented = true

    RecordingOverlay(
        isPresented: $isPresented,
        liveTranscript: "Fígado de dimensões normais, contornos regulares.",
        onCancel: {},
        onStop: {}
    )
}
