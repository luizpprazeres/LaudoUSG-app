import SwiftUI

@MainActor @Observable
final class CompanionViewModel {
    var code = ""
    var message = ""
    var connection: CompanionConnection?
    var isBusy = false
    var error: String?
    var sent = false
    var dictated = false
    var imageData: BiometricData?
    var imageSummary = ""
    let speech = SpeechService()

    func connect() async {
        await run { self.connection = try await CompanionService.connect(code: self.code) }
    }

    func restore() async {
        guard connection == nil else { return }
        do { connection = try await CompanionService.restoreConnection() }
        catch { /* O pareamento manual continua disponível se a restauração falhar. */ }
    }

    func send() async {
        guard let connection else { return }
        await run {
            if self.dictated {
                try await CompanionService.sendTranscript(self.message, connection: connection)
            } else {
                try await CompanionService.sendText(self.message, connection: connection)
            }
            self.message = ""
            self.dictated = false
            self.sent = true
        }
    }

    func toggleDictation() async {
        error = nil
        sent = false
        if speech.isRecording {
            let transcript = await speech.stop()
            if transcript.isEmpty {
                error = speech.lastError?.localizedDescription ?? "Não consegui transcrever o ditado."
            } else {
                message = transcript
                dictated = true
            }
            return
        }

        do {
            guard await speech.requestPermissions() else {
                error = speech.lastError?.localizedDescription
                return
            }
            try await speech.start()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cancelRecording() {
        if speech.isRecording || speech.isTranscribing { speech.cancel() }
    }

    func receiveImageFindings(_ results: [BiometricData], summary: String) {
        imageData = ImageAnalysisService.merge(results)
        imageSummary = summary
        sent = false
    }

    func sendImageFindings(category: ReportCategory) async {
        guard let connection, let imageData else { return }
        await run {
            try await CompanionService.sendStructuredFindings(
                imageData,
                summary: self.imageSummary,
                category: category,
                connection: connection
            )
            self.imageData = nil
            self.imageSummary = ""
            self.sent = true
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) async {
        isBusy = true; error = nil
        do { try await operation() }
        catch { self.error = error.localizedDescription }
        isBusy = false
    }
}

struct CompanionSheet: View {
    let category: ReportCategory
    let onDismiss: () -> Void
    @State private var vm = CompanionViewModel()
    @State private var imageAnalysisOpen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if vm.connection == nil { pairingContent } else { connectedContent }
                    if let error = vm.error {
                        Text(error).font(TextStyle.caption).foregroundStyle(SemanticColor.errorAccent)
                            .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(SemanticColor.errorBg))
                    }
                }
                .padding(Spacing.md)
            }
            .background(AppSurface.background)
            .navigationTitle("Conectar à web")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fechar", action: onDismiss) } }
            .task { await vm.restore() }
            .onDisappear { vm.cancelRecording() }
            .sheet(isPresented: $imageAnalysisOpen) {
                NavigationStack {
                    ImageAnalysisSheet(
                        category: category,
                        onInsert: { _ in },
                        onDismiss: { imageAnalysisOpen = false },
                        onExtract: { results, summary in
                            vm.receiveImageFindings(results, summary: summary)
                        }
                    )
                }
            }
        }
    }

    private var pairingContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Digite o código mostrado no computador").font(TextStyle.h3).foregroundStyle(AppSurface.textPrimary)
            Text("Abra Celular no LaudoUSG Web. O código vale por 10 minutos e só funciona nesta mesma conta.")
                .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
            TextField("ABC 234", text: $vm.code)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .font(.system(size: 28, weight: .bold, design: .monospaced)).multilineTextAlignment(.center)
                .padding().background(RoundedRectangle(cornerRadius: Radius.xl).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(AppSurface.border))
            primaryButton("Conectar") { await vm.connect() }
        }
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("Celular conectado", systemImage: "checkmark.circle.fill")
                .font(TextStyle.bodyLargeSemibold).foregroundStyle(BrandColor.primary)
            Text("A mensagem aparece na web como entrada pendente. A auxiliar decide quando acrescentar ao laudo.")
                .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
            TextEditor(text: $vm.message)
                .frame(minHeight: 150).padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.xl).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(AppSurface.border))
                .onChange(of: vm.message) { _, _ in vm.sent = false }
            if ImageAnalysisService.canAnalyze(category: category) {
                Button {
                    Haptics.tap()
                    imageAnalysisOpen = true
                } label: {
                    Label("Foto com biometria/Doppler", systemImage: "camera.viewfinder")
                        .font(TextStyle.bodyLargeSemibold).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BrandColor.primary)
                .background(Capsule().stroke(BrandColor.primary))
                .disabled(vm.isBusy || vm.speech.isRecording || vm.speech.isTranscribing)
            }
            if vm.imageData != nil {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Medidas encontradas — revise antes de enviar")
                        .font(TextStyle.captionMedium).foregroundStyle(BrandColor.primary)
                    Text(vm.imageSummary)
                        .font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
                    primaryButton("Enviar medidas para a web") { await vm.sendImageFindings(category: category) }
                }
                .padding(Spacing.md)
                .background(RoundedRectangle(cornerRadius: Radius.xl).fill(AppSurface.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(AppSurface.border))
            }
            Button { Task { await vm.toggleDictation() } } label: {
                Group {
                    if vm.speech.isTranscribing {
                        HStack { ProgressView(); Text("Transcrevendo…") }
                    } else {
                        Label(vm.speech.isRecording ? "Parar ditado" : "Ditar para a web",
                              systemImage: vm.speech.isRecording ? "stop.fill" : "mic.fill")
                    }
                }
                .font(TextStyle.bodyLargeSemibold).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(vm.speech.isRecording ? SemanticColor.errorAccent : BrandColor.primary)
            .background(Capsule().stroke(vm.speech.isRecording ? SemanticColor.errorAccent : BrandColor.primary))
            .disabled(vm.isBusy || vm.speech.isTranscribing)
            if vm.speech.isTranscribing {
                Text("O áudio será descartado após a transcrição.")
                    .font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            primaryButton("Enviar para a web") { await vm.send() }
                .disabled(vm.speech.isRecording || vm.speech.isTranscribing || vm.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if vm.sent { Text("Mensagem enviada.").font(TextStyle.captionMedium).foregroundStyle(BrandColor.primary) }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Group { if vm.isBusy { ProgressView().tint(.white) } else { Text(title) } }
                .font(TextStyle.bodyLargeSemibold).frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain).foregroundStyle(.white).background(Capsule().fill(BrandColor.primary)).disabled(vm.isBusy)
    }
}
