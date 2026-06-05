import SwiftUI
import Combine

struct RecordingOverlay: View {
    @Binding var isPresented: Bool
    @Bindable var deepgram: DeepgramLiveService
    let onCancel: () -> Void
    let onStop: () -> Void

    /// Buffer das últimas amplitudes (32 barras visíveis).
    @State private var barLevels: [CGFloat] = Array(repeating: 0.08, count: 32)
    @State private var isVisible = false

    /// ~12 fps — equilibra fluidez visual com performance.
    private let timer = Timer.publish(every: 0.083, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial.opacity(0.95)).ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                statusEyebrow

                Text(formattedElapsed)
                    .font(TextStyle.display)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                waveform
                    .accessibilityElement()
                    .accessibilityLabel("Gravação em andamento")

                wordCounter

                liveCaption

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
            withAnimation(.easeOut(duration: 0.2)) { isVisible = true }
        }
        .onReceive(timer) { _ in
            guard isPresented else { return }
            deepgram.tick()
            advanceWaveform()
        }
    }

    // MARK: - Status eyebrow

    @ViewBuilder
    private var statusEyebrow: some View {
        HStack(spacing: 8) {
            if deepgram.isReconnecting {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.8))
                Text("RECONECTANDO…")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.15 * 11)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.opacity)
            } else if deepgram.isStreaming {
                Circle()
                    .fill(Color(hex: "EF4444"))
                    .frame(width: 8, height: 8)
                    .modifier(PulseAnimation())
                Text("OUVINDO")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.15 * 11)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.8))
                Text("CONECTANDO…")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.15 * 11)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.1)))
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Waveform (amplitude real do mic)

    private var waveform: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(barLevels.indices, id: \.self) { index in
                Capsule()
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
            }
        }
        .frame(height: 80)
        .animation(.easeOut(duration: 0.12), value: barLevels)
    }

    private func barColor(for index: Int) -> Color {
        let centerDistance = abs(Double(index) - Double(barLevels.count - 1) / 2)
        let centerNormalized = 1.0 - (centerDistance / Double(barLevels.count / 2))
        let opacity = 0.45 + 0.55 * centerNormalized
        return BrandColor.primary.opacity(opacity)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 6
        let maxHeight: CGFloat = 64
        let centerDistance = abs(Double(index) - Double(barLevels.count - 1) / 2)
        let envelope = 1.0 - 0.35 * (centerDistance / Double(barLevels.count / 2))
        let h = minHeight + (maxHeight - minHeight) * barLevels[index] * CGFloat(envelope)
        return max(minHeight, h)
    }

    private func advanceWaveform() {
        let newLevel = CGFloat(deepgram.audioLevel)
        var next = barLevels
        next.removeFirst()
        next.append(newLevel)
        barLevels = next
    }

    // MARK: - Contador

    private var wordCounter: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text("~\(deepgram.wordCount) \(deepgram.wordCount == 1 ? "palavra" : "palavras")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(minHeight: 18)
        .opacity(deepgram.isStreaming ? 1 : 0)
    }

    // MARK: - Legenda ao vivo (estilo lyrics do Spotify — texto sobe, topo some)

    /// ~4 linhas visíveis.
    private let captionHeight: CGFloat = 96

    private var liveCaption: some View {
        Group {
            if deepgram.liveTranscript.isEmpty {
                Text("Comece a ditar — o texto aparece aqui ao vivo.")
                    .font(TextStyle.body)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: captionHeight)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(deepgram.liveTranscript)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .id("captionEnd")
                    }
                    .frame(height: captionHeight)
                    .scrollDisabled(true)
                    .onChange(of: deepgram.liveTranscript) { _, _ in
                        withAnimation(.easeOut(duration: 0.28)) {
                            proxy.scrollTo("captionEnd", anchor: .bottom)
                        }
                    }
                    .mask(
                        // fade no topo: as linhas antigas vão sumindo ao subir
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black.opacity(0.5), location: 0.16),
                                .init(color: .black, location: 0.42),
                                .init(color: .black, location: 1.0),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Buttons

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
        .accessibilityLabel("Parar gravação e usar o texto")
    }

    private var formattedElapsed: String {
        let totalSeconds = Int(deepgram.elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Pulso sutil pro indicador "OUVINDO".
private struct PulseAnimation: ViewModifier {
    @State private var scale: CGFloat = 1
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    scale = 0.6
                }
            }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    let deepgram = DeepgramLiveService()

    return RecordingOverlay(
        isPresented: $isPresented,
        deepgram: deepgram,
        onCancel: {},
        onStop: {}
    )
}
