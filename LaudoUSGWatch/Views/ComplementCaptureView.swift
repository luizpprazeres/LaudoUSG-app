import SwiftUI
import WatchKit

/// Captura complementar com FILA — grava ditados (1 por exame/paciente) e envia
/// cada um pro iPhone pareado. Mostra a fila da sessão com status de entrega.
/// O médico recupera + transcreve + finaliza no iPhone. Sem auth, sem geração.
struct ComplementCaptureView: View {
    @State private var recorder = AudioRecorder()
    @State private var session = WatchSessionManager.shared
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: WatchTheme.s3) {
                Text("Ditados")
                    .font(.headline)
                    .foregroundStyle(WatchTheme.textPrimary)

                MicCaptureButton(isRecording: recorder.isRecording) { toggle() }

                statusLine

                if !session.queue.isEmpty {
                    queueList
                }
            }
            .padding(WatchTheme.s2)
            .frame(maxWidth: .infinity)
        }
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
        } else {
            Text("Toque pra gravar o ditado")
                .font(.footnote).foregroundStyle(WatchTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var queueList: some View {
        VStack(spacing: WatchTheme.s1) {
            HStack {
                Text("\(session.queue.count) na sessão")
                    .font(.caption2).foregroundStyle(WatchTheme.textMuted)
                Spacer()
                if session.pendingCount > 0 {
                    Label("\(session.pendingCount)", systemImage: "arrow.up.circle")
                        .font(.caption2).foregroundStyle(WatchTheme.textMuted)
                }
            }
            .padding(.top, WatchTheme.s2)

            ForEach(session.queue) { d in queueRow(d) }
        }
    }

    private func queueRow(_ d: QueuedDitado) -> some View {
        HStack(spacing: WatchTheme.s2) {
            Image(systemName: d.delivered ? "checkmark.circle.fill" : "arrow.up.circle")
                .font(.system(size: 14))
                .foregroundStyle(d.delivered ? WatchTheme.brand : WatchTheme.textMuted)
            Text(d.recordedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption).foregroundStyle(WatchTheme.textPrimary)
            Spacer()
            Text(timeString(d.duration))
                .font(.caption2).foregroundStyle(WatchTheme.textMuted)
        }
        .padding(.vertical, WatchTheme.s1)
        .padding(.horizontal, WatchTheme.s2)
        .background(RoundedRectangle(cornerRadius: 8).fill(WatchTheme.surfaceRaised))
    }

    private func toggle() {
        if recorder.isRecording {
            let dur = recorder.elapsed
            do {
                let url = try recorder.stop()
                session.send(fileURL: url, duration: dur)
                WKInterfaceDevice.current().play(.success)
            } catch {
                errorText = "Gravação muito curta."
                WKInterfaceDevice.current().play(.failure)
            }
        } else {
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
