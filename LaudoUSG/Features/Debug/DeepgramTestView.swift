import SwiftUI
import UIKit

/// Tela de PROTÓTIPO pra testar a fluidez do streaming Deepgram nativo.
/// Objetivo do teste: o mic ativa na hora? fica fluido? permissão só uma vez?
/// 1º interim em 1-2s? start/stop 10× sem travar? Se cair, erro claro?
struct DeepgramTestView: View {
    @State private var service = DeepgramLiveService()

    var body: some View {
        VStack(spacing: 0) {
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(service.isStreaming ? Color.green : Color.secondary)
                    .frame(width: 10, height: 10)
                Text(service.status)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            if let err = service.errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            // Transcript ao vivo
            ScrollView {
                Text(service.liveTranscript.isEmpty ? "O transcrito aparece aqui enquanto você fala…" : service.liveTranscript)
                    .font(.body)
                    .foregroundStyle(service.liveTranscript.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)

            // Controles
            HStack(spacing: 16) {
                Button {
                    UIPasteboard.general.string = service.liveTranscript
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(service.liveTranscript.isEmpty)

                Button {
                    Task {
                        if service.isStreaming { await service.stop() }
                        else { await service.start() }
                    }
                } label: {
                    Label(
                        service.isStreaming ? "Parar" : "Falar",
                        systemImage: service.isStreaming ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(service.isStreaming ? .red : .green)
            }
            .padding()
        }
        .navigationTitle("Deepgram (teste)")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Task { await service.stop() } }
    }
}

#Preview {
    NavigationStack { DeepgramTestView() }
}
