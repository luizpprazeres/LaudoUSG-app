import Foundation
import Observation
import os

@Observable
@MainActor
final class ConsultorViewModel {
    var messages: [ConsultorMessage] = []
    var draftText: String = ""
    var pendingImagesBase64: [String] = []
    var isStreaming: Bool = false
    var lastError: String?

    let report: String
    let findings: String
    let category: ReportCategory?
    let reportId: String?

    private static let logger = Logger(subsystem: "com.laudousg.LaudoUSG", category: "consultor")
    private static let maxImagesPerMessage = 5
    private static let greeting = "Olá! Tenho acesso ao laudo e achados deste caso. Tem alguma dúvida clínica? Precisa de diagnósticos diferenciais ou referências sobre o tema? Fique à vontade para detalhar o caso no chat ou anexar imagens (até 5)."

    private var hasSharedContext: Bool = false
    private var streamTask: Task<Void, Never>?

    init(report: String, findings: String, category: ReportCategory?, reportId: String?) {
        self.report = report
        self.findings = findings
        self.category = category
        self.reportId = reportId
        self.messages = [
            ConsultorMessage(role: .assistant, text: Self.greeting)
        ]
    }

    var canSend: Bool {
        !isStreaming && (
            !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pendingImagesBase64.isEmpty
        )
    }

    var canAddImage: Bool {
        pendingImagesBase64.count < Self.maxImagesPerMessage
    }

    func attachImage(_ imageData: Data) {
        guard canAddImage else { return }
        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"
        pendingImagesBase64.append(dataURL)
    }

    func removeImage(at index: Int) {
        guard pendingImagesBase64.indices.contains(index) else { return }
        pendingImagesBase64.remove(at: index)
    }

    func send() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !pendingImagesBase64.isEmpty else { return }
        guard !isStreaming else { return }

        let userText = trimmed.isEmpty ? "(imagens enviadas)" : trimmed
        let images = pendingImagesBase64

        let displayMessage = ConsultorMessage(
            role: .user,
            text: userText,
            imagesBase64: images
        )
        messages.append(displayMessage)
        draftText = ""
        pendingImagesBase64 = []
        lastError = nil

        let assistantPlaceholder = ConsultorMessage(role: .assistant, text: "")
        messages.append(assistantPlaceholder)
        let placeholderId = assistantPlaceholder.id

        let wireText: String
        if !hasSharedContext {
            wireText = buildContextBlock(userQuestion: userText)
            hasSharedContext = true
        } else {
            wireText = userText
        }

        let wireMessages = buildWireHistory(
            replacingLastUserWith: ConsultorMessage(role: .user, text: wireText, imagesBase64: images)
        )

        isStreaming = true
        streamTask = Task { @MainActor in
            defer { isStreaming = false }
            do {
                let stream = try await ConsultorService.sendMessage(
                    history: wireMessages,
                    category: category?.rawValue,
                    reportId: reportId
                )
                var accumulated = ""
                for try await event in stream {
                    if Task.isCancelled { return }
                    switch event {
                    case .content(let text):
                        accumulated += text
                        updateMessage(id: placeholderId, text: accumulated)
                    case .done:
                        return
                    case .error(let message):
                        lastError = message
                        Self.logger.error("consultor stream error: \(message, privacy: .public)")
                        updateMessage(id: placeholderId, text: accumulated.isEmpty ? "_(erro: \(message))_" : accumulated)
                        return
                    }
                }
            } catch {
                lastError = error.localizedDescription
                Self.logger.error("consultor send failure: \(error.localizedDescription, privacy: .public)")
                updateMessage(id: placeholderId, text: "_(falha ao consultar IA: \(error.localizedDescription))_")
            }
        }
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    private func updateMessage(id: UUID, text: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text = text
    }

    private func buildContextBlock(userQuestion: String) -> String {
        let categoryLabel = category?.label ?? "Outra"
        return """
        [CONTEXTO DO CASO]
        Categoria: \(categoryLabel)
        Achados clínicos: \(findings)
        Laudo gerado:
        \(report)

        [PERGUNTA DO MÉDICO]
        \(userQuestion)
        """
    }

    private func buildWireHistory(replacingLastUserWith replacement: ConsultorMessage) -> [ConsultorMessage] {
        var history = messages.filter { msg in
            !(msg.role == .assistant && msg.text.isEmpty)
        }
        if let lastIdx = history.lastIndex(where: { $0.role == .user }) {
            history[lastIdx] = replacement
        }
        return history
    }
}
