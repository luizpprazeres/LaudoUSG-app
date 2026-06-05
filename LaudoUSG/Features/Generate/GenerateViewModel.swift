import SwiftUI
import Observation

enum GenerateTab: String, Hashable {
    case achados
    case laudo
}

struct GenerateShortcut: Identifiable, Hashable {
    enum Action: Hashable {
        case openIGCalculator
        case openDopplerCalculator
        case calcularPercentis
        case calcularIGporDUM
        case calcularIGporCF
        case insertText(String)
    }
    let id = UUID()
    let label: String
    let action: Action

    static func defaults(for category: ReportCategory) -> [GenerateShortcut] {
        switch category {
        case .obstetrica, .morfologico:
            return [
                GenerateShortcut(label: "Calcular IG pela biometria", action: .calcularIGporCF),
                GenerateShortcut(label: "Calcular IG pela DUM", action: .calcularIGporDUM),
                GenerateShortcut(label: "Calcular percentis", action: .calcularPercentis),
                GenerateShortcut(label: "BCF presentes", action: .insertText("Feto único, em situação longitudinal e apresentação cefálica, com BCF presentes."))
            ]
        case .dopplerObstetrico:
            return [
                GenerateShortcut(label: "Calcular IG pela biometria", action: .calcularIGporCF),
                GenerateShortcut(label: "Calcular IG pela DUM", action: .calcularIGporDUM),
                GenerateShortcut(label: "Calcular percentis", action: .calcularPercentis)
            ]
        case .tireoide:
            return [
                GenerateShortcut(label: "Normal", action: .insertText("Glândula tireoide tópica, contornos regulares, dimensões e ecotextura preservadas, sem nódulos. Vascularização ao Doppler colorido sem alterações.")),
                GenerateShortcut(label: "Hashimoto", action: .insertText("Glândula tireoide tópica, dimensões normais, com ecotextura heterogênea e padrão micronodular difuso, vascularização aumentada ao Doppler colorido — padrão ecográfico compatível com tireoidite crônica linfocítica (Hashimoto)."))
            ]
        case .mamaria:
            return [
                GenerateShortcut(label: "Prótese", action: .insertText("Paciente com próteses mamárias. Próteses íntegras, sem sinais de ruptura intra ou extracapsular.")),
                GenerateShortcut(label: "Linfonodos axilares", action: .insertText("Imagens ovais, com a periferia hipoecoica e o centro hiperecoico nas axilas, compatíveis com linfonodos de morfologia preservada."))
            ]
        case .abdomenTotal, .abdomenSuperior, .abdomenTotalDoppler:
            return [
                GenerateShortcut(label: "Esteatose leve", action: .insertText("Fígado de dimensões normais, contornos regulares, apresentando ecogenicidade discretamente aumentada, com leve atenuação sonora posterior, compatível com esteatose hepática leve.")),
                GenerateShortcut(label: "Colecistectomia", action: .insertText("Ausência da imagem da vesícula biliar (paciente previamente submetida a colecistectomia)."))
            ]
        case .pelveFeminina:
            return [
                GenerateShortcut(label: "Menopausa", action: .insertText("Paciente em menopausa — ovários atróficos. Aplicar substituições padronizadas: (1) no CORPO, descrever cada ovário como \"Ovário direito medindo X x Y x Z cm, apresentando poucas imagens anecoicas.\" e idem pro esquerdo (NUNCA usar apenas \"imagens anecoicas\" — usar SEMPRE \"poucas imagens anecoicas\"); (2) na CONCLUSÃO, item do endométrio: \"O endométrio tem espessura normal para a faixa etária da menopausa.\"; (3) na CONCLUSÃO, item dos ovários: \"Ovários ecograficamente normais (o direito com X cm³ e o esquerdo com Y cm³), ambos praticamente sem folículos.\"")),
                GenerateShortcut(label: "Miomatoso", action: .insertText("Útero miomatoso — múltiplos nódulos coalescentes não individualizáveis. Aplicar substituições: (1) no CORPO, substituir a frase do miométrio por: \"Miométrio apresentando múltiplas imagens hipoecoicas e heterogêneas, coalescentes, ocasionando atenuação sonora, que impede a avaliação individualizada.\"; (2) na CONCLUSÃO, substituir o item de volume + miométrio por: \"Útero globoso (miomatoso), de volume acentuadamente aumentado (X cm³).\" sem classificação FIGO individual."))
            ]
        default:
            return [
                GenerateShortcut(label: "Exame normal", action: .insertText("Exame sem alterações dignas de nota."))
            ]
        }
    }
}

enum GenerateSaveStatus: Equatable {
    case idle
    case saving
    case saved
    case failed(String)
}

@Observable
@MainActor
final class GenerateViewModel {
    var category: ReportCategory = .abdomenTotal
    var writingStyle: WritingStyle = .tradicional
    var inputText: String = ""
    var streamedOutput: String = ""
    var displayedOutput: String = ""
    var currentStatusMessage: String = ""
    var liveTranscript: String = ""

    var phase: GenerationPhase = .idle
    var lastError: String?
    var lastWarning: String?

    var activeTab: GenerateTab = .achados
    var editedLaudoText: String = ""
    var saveStatus: GenerateSaveStatus = .idle

    var isCategorySheetPresented = false
    var isMenuSheetPresented = false
    var isPlusSheetPresented = false
    var isSalaSheetPresented = false
    var isIGCalculatorPresented = false
    var isHadlockCalculatorPresented = false
    var isDopplerCalculatorPresented = false
    var isRecordingOverlayPresented = false
    var isConsultorSheetPresented = false
    var isPaywallPresented = false

    var canOpenConsultor: Bool {
        if case .done = phase {
            return !displayedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    let speech = SpeechService()
    /// Engine de gravação ao vivo (Deepgram streaming) — substitui o Whisper batch
    /// no fluxo de ditado: texto aparece ao vivo e já fica pronto ao parar.
    let deepgram = DeepgramLiveService()
    private var saveTask: Task<Void, Never>?

    var canGenerate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phase.isBusy
    }

    var hasLaudoOutput: Bool {
        !editedLaudoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !streamedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var phaseLabel: String {
        switch phase {
        case .recording: return "Gravando…"
        case .transcribing: return "Transcrevendo…"
        case .generating: return "Gerando…"
        default: return "Gerar laudo"
        }
    }

    var shortcuts: [GenerateShortcut] {
        GenerateShortcut.defaults(for: category)
    }

    func insertSnippet(_ snippet: String) {
        if inputText.isEmpty {
            inputText = snippet
        } else {
            let separator = inputText.hasSuffix("\n") ? "" : "\n"
            inputText += separator + snippet
        }
        isPlusSheetPresented = false
    }

    func runShortcut(_ shortcut: GenerateShortcut) {
        switch shortcut.action {
        case .openIGCalculator:
            isIGCalculatorPresented = true
        case .openDopplerCalculator:
            isDopplerCalculatorPresented = true
        case .calcularPercentis:
            calcularPercentis()
        case .calcularIGporDUM:
            calcularIGporDUM()
        case .calcularIGporCF:
            calcularIGporCF()
        case .insertText(let text):
            insertSnippet(text)
        }
    }

    func calcularIGporDUM() {
        guard let dum = DopplerParser.extractDUM(achados: inputText) else {
            lastWarning = "Adicione a DUM aos achados pra calcular a IG (ex.: \"DUM 20/01/26\")."
            return
        }
        guard let result = GestationalAgeCalculator.calcByDUM(dum: dum) else {
            lastWarning = "DUM inválida ou em data futura. Confira a data nos achados."
            return
        }
        insertSnippet(result.insertBloco)
    }

    func calcularIGporCF() {
        let findings = DopplerParser.parse(achados: inputText)
        guard let ig = findings.ig, ig.source == .biometria else {
            lastWarning = "Adicione o CF (comprimento do fêmur) aos achados pra calcular a IG pela biometria."
            return
        }
        let cfDisplay = extractCFDisplay(from: inputText) ?? "____"
        let text = "Idade gestacional pela biometria: \(ig.weeks) semanas e \(ig.days) dias (CF: \(cfDisplay), Hadlock 1984)."
        insertSnippet(text)
    }

    func calcularPercentis() {
        let findings = DopplerParser.parse(achados: inputText)
        guard let ig = findings.ig, ig.weeks >= 20 && ig.weeks <= 41 else {
            lastWarning = "Adicione a IG aos achados (entre 20 e 41 semanas) pra calcular percentis Doppler."
            return
        }

        let weeks = ig.weeks
        var pieces: [String] = []
        if let ip = findings.umbilicalIP,
           let result = DopplerPercentileTable.calculate(artery: .umbilical, ip: ip, igWeeks: weeks) {
            pieces.append("AU IP \(formatIP(ip)) (\(result.estimatedPercentile))")
        }
        if let ip = findings.cerebralMediaIP,
           let result = DopplerPercentileTable.calculate(artery: .cerebralMedia, ip: ip, igWeeks: weeks) {
            pieces.append("ACM IP \(formatIP(ip)) (\(result.estimatedPercentile))")
        }
        if let ip = findings.uterinasMediaIP,
           let result = DopplerPercentileTable.calculate(artery: .uterinasMedia, ip: ip, igWeeks: weeks) {
            pieces.append("Uterinas média IP \(formatIP(ip)) (\(result.estimatedPercentile))")
        } else if let dir = findings.uterinaDireitaIP, let esq = findings.uterinaEsquerdaIP {
            let media = (dir + esq) / 2
            if let result = DopplerPercentileTable.calculate(artery: .uterinasMedia, ip: media, igWeeks: weeks) {
                pieces.append("Uterinas média IP \(formatIP(media)) (\(result.estimatedPercentile))")
            }
        }

        if pieces.isEmpty {
            lastWarning = "Adicione AU IP, ACM IP ou Uterinas IP aos achados pra calcular percentis."
            return
        }

        let summary = "\n→ Percentis (\(weeks)s\(ig.days)d, Gratacós/FMF): " + pieces.joined(separator: " · ")
        insertSnippet(summary)
    }

    private func formatIP(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func extractCFDisplay(from text: String) -> String? {
        guard let match = text.firstMatch(
            of: /(?i)\b(?:cf|fl|f[eê]mur)\b\s*[:=]?\s*([0-9]+(?:[,.][0-9]+)?)\s*(mm|cm)?/
        ) else {
            return nil
        }
        let rawValue = String(match.1)
        let unit: String
        if let captured = match.2 {
            unit = String(captured).lowercased()
        } else {
            let numeric = Double(rawValue.replacingOccurrences(of: ",", with: ".")) ?? 0
            unit = numeric > 20 ? "mm" : "cm"
        }
        return "\(rawValue) \(unit)"
    }

    func startRecording() {
        guard !phase.isBusy else { return }
        // Mostra o overlay JÁ (estado "Conectando…") — resposta instantânea ao
        // toque, sem esperar token + conexão + áudio (vira "Ouvindo" quando pronto).
        liveTranscript = ""
        phase = .recording
        isRecordingOverlayPresented = true
        Task { @MainActor in
            await deepgram.start()   // pede permissão + conecta internamente
            if !deepgram.isStreaming {
                isRecordingOverlayPresented = false
                phase = inputText.isEmpty ? .idle : .ready
                lastError = deepgram.errorMessage ?? "Não foi possível iniciar a gravação."
            }
        }
    }

    func cancelRecording() {
        Task { @MainActor in await deepgram.stop() }
        liveTranscript = ""
        isRecordingOverlayPresented = false
        phase = inputText.isEmpty ? .idle : .ready
    }

    func finishRecording() {
        isRecordingOverlayPresented = false
        Task { @MainActor in
            await deepgram.stop()
            // Streaming: o texto JÁ está pronto ao parar (sem espera de transcrição).
            // Usa liveTranscript (final + último parcial) pra não perder o fim da fala.
            let transcript = deepgram.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                if inputText.isEmpty {
                    inputText = transcript
                } else {
                    let separator = inputText.hasSuffix("\n") ? "" : "\n"
                    inputText += separator + transcript
                }
            } else if let err = deepgram.errorMessage {
                lastError = err
            }
            liveTranscript = ""
            phase = inputText.isEmpty ? .idle : .ready
        }
    }

    var lastReportId: String?
    var sanityIssues: [LocalSanityIssue] = []

    func generate(writingStyleId: String) {
        guard canGenerate else { return }
        streamedOutput = ""
        displayedOutput = ""
        editedLaudoText = ""
        saveStatus = .idle
        lastError = nil
        lastWarning = nil
        sanityIssues = []
        phase = .generating
        startStreamingFeedback()
        withAnimation(.easeOut(duration: 0.18)) { activeTab = .laudo }

        let req = GenerateRequest(
            rawInput: inputText,
            categoryHint: category,
            writingStyleId: writingStyleId
        )

        Task { @MainActor in
            do {
                let stream = try await ReportService.generateStream(request: req)
                for try await event in stream {
                    handle(event: event)
                }
            } catch let error as APIError {
                if case .unauthorized = error {
                    lastError = "Sessão expirada. Faça login novamente."
                } else {
                    lastError = error.errorDescription
                }
                phase = .error(message: lastError ?? "Erro")
                stopStreamingFeedback()
            } catch {
                lastError = error.localizedDescription
                phase = .error(message: lastError ?? "Erro")
                stopStreamingFeedback()
            }
        }
    }

    func laudoTextChanged(_ newValue: String) {
        editedLaudoText = newValue
        saveStatus = .saving
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await persistLaudo()
        }
    }

    private func persistLaudo() async {
        guard let reportId = lastReportId else {
            saveStatus = .failed("Aguardando criação do laudo.")
            return
        }
        do {
            // Salva LIMPO (sem marcadores [REVISAR — ...]) — o que vai pra Sala
            // (pushReport usa o relatório salvo) e pro histórico fica final.
            try await HistoryService.updateFinalOutput(reportId: reportId, finalText: editedLaudoText.strippedReviewMarkers)
            saveStatus = .saved
        } catch {
            saveStatus = .failed(error.localizedDescription)
        }
    }

    private func handle(event: GenerateSSEEvent) {
        switch event {
        case .open(let payload):
            lastReportId = payload.reportId
        case .heartbeat:
            break
        case .structured:
            break
        case .validator(let payload):
            if !payload.ok && payload.issuesCount > 0 {
                // Sprint 8: tratar clarify questions
            }
        case .clarify(let payload):
            phase = .clarifying(question: payload.questions.first?.text ?? "Esclarecimento necessário")
        case .rag:
            break
        case .warning(let payload):
            lastWarning = payload.message
        case .token(let payload):
            if activeTab != .laudo {
                withAnimation(.easeOut(duration: 0.18)) { activeTab = .laudo }
            }
            if !currentStatusMessage.isEmpty {
                currentStatusMessage = ""
            }
            streamedOutput += payload.delta
            displayedOutput = streamedOutput
        case .sanity:
            break
        case .done(let payload):
            streamedOutput = payload.finalText
            displayedOutput = payload.finalText
            editedLaudoText = payload.finalText
            lastReportId = payload.reportId
            sanityIssues = SanityChecker.check(text: payload.finalText, category: category)
            phase = .done(reportId: payload.reportId)
            activeTab = .laudo
            stopStreamingFeedback()
        case .blocked(let payload):
            lastError = payload.reason
            phase = .error(message: payload.reason)
            stopStreamingFeedback()
        case .error(let payload):
            lastError = payload.message
            phase = .error(message: payload.message)
            stopStreamingFeedback()
        }
    }

    func reset() {
        stopStreamingFeedback()
        inputText = ""
        streamedOutput = ""
        displayedOutput = ""
        editedLaudoText = ""
        liveTranscript = ""
        phase = .idle
        activeTab = .achados
        saveStatus = .idle
        lastError = nil
        currentStatusMessage = ""
    }

    private func startStreamingFeedback() {
        currentStatusMessage = "Analisando achados…"
    }

    private func stopStreamingFeedback() {
        currentStatusMessage = ""
    }
}
