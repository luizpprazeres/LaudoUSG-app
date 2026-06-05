import SwiftUI

/// Lista os ditados de áudio gravados no Apple Watch. Ao escolher um, transcreve
/// (Whisper) e preenche o input do Gerar. Modelo complemento — o médico finaliza
/// no iPhone (imagens, ajustes).
struct WatchDitadosSheet: View {
    @Bindable var inbox: WatchAudioInbox
    var onInsert: (String) -> Void
    var onDismiss: () -> Void

    @State private var busyID: String?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if inbox.pending.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.sm) {
                            ForEach(inbox.pending) { d in row(d) }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Ditados do Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { onDismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(.red)
                        .padding(.bottom, Spacing.sm)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 40)).foregroundStyle(AppSurface.textSecondary)
            Text("Nenhum ditado do Watch").font(TextStyle.bodyLargeMedium)
            Text("Grave no Apple Watch — o áudio aparece aqui quando o iPhone reconectar.")
                .font(.footnote).foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func row(_ d: WatchDitado) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BrandColor.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(BrandColor.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(d.receivedAt.formatted(date: .omitted, time: .shortened))
                    .font(TextStyle.bodyMedium)
                Text(durationLabel(d)).font(.caption).foregroundStyle(AppSurface.textSecondary)
            }
            Spacer()

            if busyID == d.id {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await use(d) }
                } label: {
                    Text("Usar").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm).frame(minHeight: 32)
                        .background(Capsule().fill(BrandColor.primary))
                }
                Button(role: .destructive) {
                    inbox.remove(d)
                } label: {
                    Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .padding(Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(AppSurface.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(AppSurface.border, lineWidth: 1))
        .disabled(busyID != nil)
    }

    private func durationLabel(_ d: WatchDitado) -> String {
        guard let s = d.duration, s > 0 else { return "Áudio do Watch" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }

    private func use(_ d: WatchDitado) async {
        busyID = d.id; errorText = nil
        defer { busyID = nil }
        do {
            let transcript = try await AudioTranscriber.transcribe(fileURL: d.url)
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { errorText = "Transcrição vazia."; return }
            onInsert(trimmed)
            inbox.remove(d)
            Haptics.success()
            onDismiss()
        } catch {
            errorText = "Falha ao transcrever. Tente de novo."
        }
    }
}
