import Foundation
import Observation

/// Estado do "Ajustar laudo" (edição incremental via `/api/edit`).
///
/// Fluxo: ditar (ou digitar) → "Ajustar" → prévia do que mudou → "Aplicar" ou
/// "Descartar". Recusa do servidor mostra o motivo e deixa o laudo intacto.
///
/// O texto do laudo e o autosave continuam no `GenerateViewModel`; aqui fica só o
/// que é do ajuste.
@Observable
@MainActor
final class AdjustLaudoModel {
    enum Phase: Equatable {
        case composing
        case submitting
        /// O servidor aceitou (e já gravou). `editedText` só entra na tela no "Aplicar".
        case preview(editedText: String, changes: [LaudoDiff.Change])
        /// Recusa do diff-guard: nada foi gravado; `proposal` é só para consulta.
        case rejected(AdjustRejection, proposal: [LaudoDiff.Change])
        case failed(String)
    }

    var isPresented = false
    var phase: Phase = .composing
    /// Linha marcada no toque longo, antes de abrir o ajuste.
    var selectedLine: Int?
    var instruction = ""
    var targetChoice: AdjustTargetChoice = .automatic
    /// Trecho do laudo escolhido no toque longo. Vai junto do pedido.
    private(set) var anchor: String?
    private(set) var isListening = false
    private(set) var micError: String?
    private(set) var mic: (any LiveMicEngine)?
    /// Instrução efetivamente enviada (com o trecho, se houver) — para o eco na prévia.
    private(set) var sentInstruction = ""
    private(set) var sentTarget: AdjustTarget = .body

    var editor: any ReportEditing

    init(editor: any ReportEditing) {
        self.editor = editor
    }

    var trimmedInstruction: String {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        switch phase {
        case .composing, .failed: return trimmedInstruction.count >= 2
        default: return false
        }
    }

    // MARK: - Abrir / fechar

    func present(anchor: String? = nil, mic: (any LiveMicEngine)?, listen: Bool) {
        self.anchor = anchor?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.mic = mic
        selectedLine = nil
        instruction = ""
        targetChoice = .automatic
        phase = .composing
        micError = nil
        isPresented = true
        if listen { Task { await startListening() } }
    }

    /// Fecha sem aplicar nada. Para o microfone se estiver ligado.
    func close() async {
        await stopListening()
        isPresented = false
        phase = .composing
        anchor = nil
    }

    // MARK: - Voz

    func startListening() async {
        guard let mic, !isListening else { return }
        micError = nil
        instruction = ""
        isListening = true
        await mic.start()
        if !mic.isStreaming {
            isListening = false
            micError = mic.errorMessage ?? "Microfone indisponível. Digite o ajuste."
        }
    }

    func stopListening() async {
        guard isListening, let mic else { return }
        isListening = false
        await mic.stop()
        let transcript = mic.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty { instruction = transcript }
    }

    func toggleListening() async {
        if isListening { await stopListening() } else { await startListening() }
    }

    /// Chamado a cada tick da tela: o texto ao vivo vira a instrução.
    func tick() {
        guard let mic else { return }
        mic.tick()
        if isListening { instruction = mic.liveTranscript }
    }

    // MARK: - Enviar

    /// Instrução que vai ao servidor. O contrato do `/api/edit` não tem campo de
    /// trecho, então ele vai no texto, antes do pedido — mas SÓ O COMEÇO da linha.
    ///
    /// O servidor lê a instrução inteira com regex (acréscimo/substituição/achado).
    /// Com a linha toda, um trecho normal que NEGA achado ("sem imagens de cálculos
    /// ou cistos") ligava o guard de achado novo e a conclusão normal era trocada
    /// por uma medida normal (bancada W18: 0/2). Com o começo da linha: 12/12.
    func composedInstruction() -> String {
        guard let anchor else { return trimmedInstruction }
        return "No trecho que começa com \u{201C}\(Self.anchorStart(anchor))\u{201D}: \(trimmedInstruction)"
    }

    /// Começo da linha até a 1ª vírgula/ponto (máx. 5 palavras), sem a numeração
    /// de item ("1.", "2)") — é o que basta para o modelo achar a linha.
    static func anchorStart(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        if let range = text.range(of: #"^\d+\s*[.)\-]\s*"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        let head = text.split(whereSeparator: { ",.;:".contains($0) }).first.map(String.init) ?? text
        let words = head.split(whereSeparator: \.isWhitespace).prefix(5)
        let start = words.joined(separator: " ")
        return start.isEmpty ? text.split(whereSeparator: \.isWhitespace).prefix(5).joined(separator: " ") : start
    }

    /// - Parameters:
    ///   - currentText: texto do laudo como está salvo (sem marcadores de revisão).
    ///   - flush: salva o que estiver pendente ANTES do ajuste — o servidor edita a
    ///     versão armazenada, não a da tela.
    func submit(reportId: String, currentText: String, targetOverride: AdjustTarget? = nil, flush: () async -> Bool) async {
        await stopListening()
        guard trimmedInstruction.count >= 2 else { return }
        let instruction = composedInstruction()
        let target = targetOverride ?? targetChoice.resolve(for: trimmedInstruction)
        sentInstruction = trimmedInstruction
        sentTarget = target
        phase = .submitting

        guard await flush() else {
            phase = .failed("Não foi possível salvar a versão atual do laudo antes do ajuste. Nada foi alterado.")
            return
        }

        do {
            let response = try await editor.edit(reportId: reportId, instruction: instruction, target: target)
            if response.accepted {
                let changes = LaudoDiff.changes(from: currentText, to: response.editedText)
                if changes.isEmpty {
                    phase = .rejected(AdjustRejection.from(reason: "sem alteração", target: target), proposal: [])
                } else {
                    phase = .preview(editedText: response.editedText, changes: changes)
                }
                Haptics.success()
            } else {
                phase = .rejected(
                    AdjustRejection.from(reason: response.reason, target: target),
                    proposal: LaudoDiff.proposal(from: response.changedLines)
                )
                Haptics.error()
            }
        } catch {
            phase = .failed(ReportEditError.from(error).errorDescription ?? "Não foi possível ajustar o laudo.")
            Haptics.error()
        }
    }

    /// Volta para ditar de novo, mantendo o trecho e o alvo escolhidos.
    func restart(listen: Bool) {
        phase = .composing
        instruction = ""
        if listen { Task { await startListening() } }
    }

    /// Texto a aplicar quando o médico confirma a prévia. Fecha o ajuste.
    func takeAcceptedText() -> String? {
        guard case .preview(let editedText, _) = phase else { return nil }
        isPresented = false
        phase = .composing
        anchor = nil
        return editedText
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
