import SwiftUI
import Combine

struct RecordingOverlay: View {
    @Binding var isPresented: Bool
    @Bindable var speech: SpeechService
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
                    .accessibilityLabel(speech.isTranscribing ? "Transcrevendo" : "Gravação em andamento")

                wordCounter

                bottomMessage

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
            speech.tick()
            advanceWaveform()
        }
    }

    // MARK: - Status eyebrow

    @ViewBuilder
    private var statusEyebrow: some View {
        HStack(spacing: 8) {
            if speech.isRecording {
                Circle()
                    .fill(Color(hex: "EF4444"))
                    .frame(width: 8, height: 8)
                    .modifier(PulseAnimation())
                Text("OUVINDO")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.15 * 11)
                    .foregroundStyle(.white.opacity(0.9))
            } else if speech.isTranscribing {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.8))
                Text(transcribingLabel)
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

    private var transcribingLabel: String {
        switch speech.transcribingStage {
        case .uploading: return "ENVIANDO ÁUDIO"
        case .processing: return "TRANSCREVENDO COM IA"
        case .idle: return "PROCESSANDO"
        }
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
        // Centro mais brilhante, bordas mais sutis (envelope visual)
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
        let newLevel = CGFloat(speech.currentLevel)
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
            Text("~\(speech.estimatedWordCount) \(speech.estimatedWordCount == 1 ? "palavra" : "palavras")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(minHeight: 18)
        .opacity(speech.isRecording ? 1 : 0)
    }

    // MARK: - Bottom message

    private var bottomMessage: some View {
        Text(messageText)
            .font(TextStyle.body)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: 40)
            .contentTransition(.opacity)
    }

    private var messageText: String {
        if speech.isTranscribing {
            switch speech.transcribingStage {
            case .uploading: return "Enviando seu áudio com segurança…"
            case .processing: return "A IA está transcrevendo. Isso costuma levar 2–3 segundos."
            case .idle: return "Processando…"
            }
        }
        return "Toque em Parar e usar quando terminar. A transcrição leva 2–3 segundos após parar."
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
        .disabled(speech.isTranscribing)
        .opacity(speech.isTranscribing ? 0.5 : 1.0)
        .accessibilityLabel("Cancelar gravação")
    }

    private var stopButton: some View {
        Button {
            isPresented = false
            onStop()
        } label: {
            Text(speech.isTranscribing ? "Aguarde…" : "Parar e usar")
                .font(TextStyle.bodySemibold)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(Color(hex: "FF3B30"))
                )
                .contentTransition(.opacity)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(speech.isTranscribing)
        .opacity(speech.isTranscribing ? 0.5 : 1.0)
        .accessibilityLabel("Parar gravação e usar áudio")
    }

    private var formattedElapsed: String {
        let totalSeconds = Int(speech.elapsed)
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
    let speech = SpeechService()

    return RecordingOverlay(
        isPresented: $isPresented,
        speech: speech,
        onCancel: {},
        onStop: {}
    )
}
