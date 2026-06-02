import SwiftUI

struct RecordingView: View {
    @Environment(WatchAppState.self) private var app
    let category: CategoryWatch

    var body: some View {
        VStack(spacing: WatchTheme.s2) {
            Text(category.label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(WatchTheme.brand)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(duration)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(app.recorder.reachedLimit ? .orange : WatchTheme.textPrimary)
                .contentTransition(.numericText())

            MicCaptureButton(isRecording: app.recorder.isRecording) {
                Task { await app.toggleRecording() }
            }

            if app.recorder.reachedLimit {
                Text("Limite 60s")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.orange)
            }

            if let error = app.errorMessage {
                VStack(spacing: WatchTheme.s1) {
                    Text(error)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(WatchTheme.danger)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if app.transcribeError {
                        Button("Tentar novamente") {
                            Task { await app.retryTranscription(category: category) }
                        }
                        .buttonStyle(.plain)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(WatchTheme.brandSoft)
                    }
                }
                .padding(.horizontal, WatchTheme.s1)
            }

            HStack(spacing: WatchTheme.s2) {
                Button("Cancelar") {
                    app.cancelRecording()
                }
                .buttonStyle(.plain)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(WatchTheme.textMuted)
                .frame(maxWidth: .infinity)

                Button("Gerar") {
                    Task { await app.generate(category: category) }
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchTheme.brand)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .disabled(!app.canGenerate || app.recorder.isRecording)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, WatchTheme.s1)
    }

    private var duration: String {
        let seconds = Int(app.recorder.elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    RecordingView(category: .obstetrica)
        .environment(WatchAppState())
}
