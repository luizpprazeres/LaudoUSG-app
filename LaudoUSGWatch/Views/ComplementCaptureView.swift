import SwiftUI
import WatchKit

/// Captura complementar — grava um ditado e envia pro iPhone pareado. O médico
/// recupera + transcreve + finaliza no iPhone. Sem auth, sem geração no watch.
struct ComplementCaptureView: View {
    @State private var recorder = AudioRecorder()
    @State private var session = WatchSessionManager.shared
    @State private var justSent = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: WatchTheme.s3) {
            Text("Ditado")
                .font(.headline)
                .foregroundStyle(WatchTheme.textPrimary)

            MicCaptureButton(isRecording: recorder.isRecording) { toggle() }

            statusLine
        }
        .padding(WatchTheme.s2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchTheme.surface)
        .onAppear { session.activate() }
    }

    @ViewBuilder
    private var statusLine: some View {
        if recorder.isRecording {
            Text(timeString(recorder.elapsed))
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(WatchTheme.textPrimary)
        } else if let errorText {
            Text(errorText).font(.caption2).foregroundStyle(WatchTheme.danger)
                .multilineTextAlignment(.center)
        } else if justSent {
            Label("Enviado pro iPhone", systemImage: "checkmark.circle.fill")
                .font(.footnote).foregroundStyle(WatchTheme.brand)
        } else {
            Text("Toque pra gravar o ditado")
                .font(.footnote).foregroundStyle(WatchTheme.textMuted)
                .multilineTextAlignment(.center)
        }

        if session.pending > 0 {
            Text("\(session.pending) enviando…")
                .font(.caption2).foregroundStyle(WatchTheme.textMuted)
        }
    }

    private func toggle() {
        if recorder.isRecording {
            let dur = recorder.elapsed
            do {
                let url = try recorder.stop()
                session.send(fileURL: url, duration: dur)
                justSent = true
                WKInterfaceDevice.current().play(.success)
            } catch {
                errorText = "Gravação muito curta."
                WKInterfaceDevice.current().play(.failure)
            }
        } else {
            justSent = false
            errorText = nil
            Task {
                do { try await recorder.start() }
                catch { errorText = "Sem acesso ao microfone." }
            }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
