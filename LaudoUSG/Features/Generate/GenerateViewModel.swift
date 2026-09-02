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
                GenerateShortcut(label: "Sem vitalidade", action: .insertText("Gestação sem vitalidade embrionária/fetal. Manter o mesmo modelo do exame obstétrico (diâmetro médio do saco gestacional e CCN). Aplicar substituições padronizadas: (1) na frequência cardíaca, substituir a frase pela seguinte: \"Batimentos cardíacos fetais não visualizados pelo modo B e nem pelo modo Doppler.\"; (2) na CONCLUSÃO, no item da idade gestacional, escrever: \"gestação em torno de X semanas e Y dias, contendo embrião/feto sem vitalidade.\" (usar \"embrião\" ou \"feto\" conforme a idade gestacional ditada)."))
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

enum FeedbackState: Equatable {
    case idle
    case submitting(String)
    case submitted(String)
    case error(String)

    var selectedVerdict: String? {
        switch self {
        case .submitting(let verdict), .submitted(let verdict):
            return verdict
        case .idle, .error:
            return nil
        }
    }
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
    var generationFindings: [String] = []
    var latestVenousScheme: VenousSchemePayload?
    var liveTranscript: String = ""
    var hardMode: Bool = false

    var phase: GenerationPhase = .idle
    var lastError: String?
    var lastWarning: String?

    var activeTab: GenerateTab = .achados
    var editedLaudoText: String = ""
    var saveStatus: GenerateSaveStatus = .idle
    var feedbackState: FeedbackState = .idle

    var isCategorySheetPresented = false
    var isMenuSheetPresented = false
    var isPlusSheetPresented = false
    var isSalaSheetPresented = false
    var isCompanionSheetPresented = false
    var isIGCalculatorPresented = false
    var isHadlockCalculatorPresented = false
    var isDopplerCalculatorPresented = false
    var isRecordingOverlayPresented = false
    var isConsultorSheetPresented = false
    var isPaywallPresented = false
    var isMiomaEditorPresented = false
    var isVenousSchemaPresented = false
    var companionConnection: CompanionConnection?
    var pendingCompanionImageData: BiometricData?
    var pendingCompanionImageSummary = ""
    var pendingCompanionImageText = ""

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

    /// Motor on-device da Apple (`SpeechTranscriber`, iOS 26+). Criado sob demanda
    /// e guardado como existencial — o tipo concreto só pode ser nomeado dentro de
    /// um `if #available`, já que o alvo mínimo do app é iOS 17.6.
    private var onDeviceEngine: (any LiveMicEngine)?

    /// Motor que está de fato gravando. A UI lê daqui e não sabe qual é.
    private(set) var activeEngine: any LiveMicEngine

    init() {
        activeEngine = deepgram
    }

    /// Motor escolhido pelo usuário em Preferências → Ditado. A View empurra o
    /// valor pra cá porque o ViewModel não tem acesso ao `AppState`.
    var transcriptionEngine: TranscriptionEngine = .laudousg

    /// Bancada de comparação de modelo (Ajustes → Desenvolvedor, escondido).
    var experimentalModel = false

    /// O `mode` mandado ao backend.
    ///
    /// `experimental` vence `hard` de propósito: quando se está comparando
    /// provider, misturar o modelo grande da casa invalida a comparação. E é um
    /// modo de bancada — quem ligou sabe o que ligou.
    private var generationMode: String {
        if experimentalModel { return "experimental" }
        return hardMode ? "hard" : "standard"
    }

    /// Resolve o motor para esta gravação.
    ///
    /// `effective` já rebaixa "nativa" para "LaudoUSG" em iOS < 26, então aqui não
    /// há caminho em que o usuário fique sem ditado por ter escolhido algo que o
    /// aparelho não suporta.
    private func engine(for category: ReportCategory) -> any LiveMicEngine {
        // O backend usa a categoria pra enxugar os keyterms — precisa estar
        // setada ANTES do prewarm, que já busca o token.
        deepgram.categoryCode = category.rawValue
        guard transcriptionEngine.effective == .nativa else { return deepgram }
        if #available(iOS 26.0, *) {
            if onDeviceEngine == nil { onDeviceEngine = AppleSpeechLiveService() }
            return onDeviceEngine ?? deepgram
        }
        return deepgram
    }

    private var saveTask: Task<Void, Never>?

    var canGenerate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phase.isBusy
    }

    var isCompanionConnected: Bool {
        guard let companionConnection else { return false }
        return companionConnection.expiresAt > Date()
    }

    var canPerformPrimaryAction: Bool { canGenerate }

    var primaryActionLabel: String {
        if isCompanionConnected { return phase.isBusy ? "Enviando…" : "Enviar para a web" }
        return phaseLabel
    }

    func restoreCompanionConnection() async {
        do { companionConnection = try await CompanionService.restoreConnection() }
        catch { companionConnection = nil }
    }

    func receiveCompanionImageFindings(_ results: [BiometricData], summary: String, insertedText: String) {
        pendingCompanionImageData = ImageAnalysisService.merge(results)
        pendingCompanionImageSummary = summary
        pendingCompanionImageText = insertedText
        insertSnippet(insertedText)
    }

    func performPrimaryAction(writingStyleId: String) {
        guard isCompanionConnected else {
            generate(writingStyleId: writingStyleId)
            return
        }
        Task { await sendCurrentFindingsToWeb() }
    }

    private func sendCurrentFindingsToWeb() async {
        guard let connection = companionConnection else { return }
        let fullText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullText.isEmpty else { return }
        phase = .generating
        lastError = nil
        do {
            if let data = pendingCompanionImageData {
                try await CompanionService.sendStructuredFindings(
                    data,
                    summary: pendingCompanionImageSummary,
                    category: category,
                    connection: connection
                )
            }
            let imageText = pendingCompanionImageText.trimmingCharacters(in: .whitespacesAndNewlines)
            let remainingText = imageText.isEmpty
                ? fullText
                : fullText.replacingOccurrences(of: imageText, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainingText.isEmpty {
                try await CompanionService.sendText(remainingText, connection: connection)
            }
            inputText = ""
            pendingCompanionImageData = nil
            pendingCompanionImageSummary = ""
            pendingCompanionImageText = ""
            lastWarning = "Enviado para a web."
            phase = .idle
        } catch {
            phase = .idle
            lastError = error.localizedDescription
            if connection.expiresAt <= Date() { companionConnection = nil }
        }
    }

    var hasLaudoOutput: Bool {
        !editedLaudoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !streamedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canShowFeedback: Bool {
        lastReportId != nil && hasLaudoOutput && !phase.isBusy
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
        guard let ig = findings.ig, ig.weeks >= 11 && ig.weeks <= 44 else {
            lastWarning = "Adicione a IG aos achados (entre 11 e 44 semanas) pra calcular percentis Doppler."
            return
        }

        let weeks = ig.weeks
        var pieces: [String] = []
        if let ip = findings.umbilicalIP,
           let result = DopplerPercentileTable.calculate(artery: .umbilical, ip: ip, igWeeks: weeks, igDays: ig.days) {
            pieces.append("AU IP \(formatIP(ip)) (\(result.estimatedPercentile))")
        }
        if let ip = findings.cerebralMediaIP,
           let result = DopplerPercentileTable.calculate(artery: .cerebralMedia, ip: ip, igWeeks: weeks, igDays: ig.days) {
            pieces.append("ACM IP \(formatIP(ip)) (\(result.estimatedPercentile))")
        }
        if let ip = findings.ductoVenosoIP,
           let result = DopplerPercentileTable.calculate(artery: .ductoVenoso, ip: ip, igWeeks: weeks, igDays: ig.days) {
            pieces.append("Ducto venoso IP \(formatIP(ip)) (\(result.estimatedPercentile))")
        }
        if let ip = findings.uterinasMediaIP,
           let result = DopplerPercentileTable.calculate(artery: .uterinasMedia, ip: ip, igWeeks: weeks, igDays: ig.days) {
            pieces.append("Uterinas média IP \(formatIP(ip)) (\(result.estimatedPercentile))")
        } else if let dir = findings.uterinaDireitaIP, let esq = findings.uterinaEsquerdaIP {
            let media = (dir + esq) / 2
            if let result = DopplerPercentileTable.calculate(artery: .uterinasMedia, ip: media, igWeeks: weeks, igDays: ig.days) {
                pieces.append("Uterinas média IP \(formatIP(media)) (\(result.estimatedPercentile))")
            }
        }

        if pieces.isEmpty {
            lastWarning = "Adicione IP de uterinas, AU, ACM ou ducto venoso aos achados pra calcular percentis."
            return
        }

        let summary = "\n→ Percentis (\(weeks)s\(ig.days)d, Fetal Medicine Barcelona v2021): " + pieces.joined(separator: " · ")
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

    /// Pré-aquece o motor da categoria atual ao abrir a tela — o toque no mic fica
    /// instantâneo. No Deepgram isso busca o token; no motor da Apple, garante que
    /// o modelo de pt-BR já está baixado (o download é caro na primeira vez).
    func prewarmMic() {
        let target = engine(for: category)
        Task { @MainActor in await target.prewarm() }
    }

    func startRecording() {
        guard !phase.isBusy else { return }
        // Escolhe o motor ANTES de mostrar o overlay — a UI já abre lendo o certo.
        activeEngine = engine(for: category)
        // Mostra o overlay JÁ (estado "Conectando…") — resposta instantânea ao
        // toque, sem esperar token + conexão + áudio (vira "Ouvindo" quando pronto).
        liveTranscript = ""
        phase = .recording
        isRecordingOverlayPresented = true
        let mic = activeEngine
        Task { @MainActor in
            await mic.start()   // pede permissão + conecta/prepara internamente
            if !mic.isStreaming {
                isRecordingOverlayPresented = false
                phase = inputText.isEmpty ? .idle : .ready
                lastError = mic.errorMessage ?? "Não foi possível iniciar a gravação."
            }
        }
    }

    func cancelRecording() {
        let mic = activeEngine
        Task { @MainActor in await mic.stop() }
        liveTranscript = ""
        isRecordingOverlayPresented = false
        phase = inputText.isEmpty ? .idle : .ready
    }

    func finishRecording() {
        isRecordingOverlayPresented = false
        let mic = activeEngine
        Task { @MainActor in
            await mic.stop()
            // Streaming: o texto JÁ está pronto ao parar (sem espera de transcrição).
            // Usa liveTranscript (final + último parcial) pra não perder o fim da fala.
            let transcript = mic.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                if inputText.isEmpty {
                    inputText = transcript
                } else {
                    let separator = inputText.hasSuffix("\n") ? "" : "\n"
                    inputText += separator + transcript
                }
            } else if let err = mic.errorMessage {
                lastError = err
            }
            liveTranscript = ""
            phase = inputText.isEmpty ? .idle : .ready
        }
    }

    var lastReportId: String?
    var sanityIssues: [LocalSanityIssue] = []

    /// #1: task da geração em voo — cancelada em reset/nova geração para o
    /// stream antigo não sobrescrever o laudo da geração nova (risco clínico).
    private var generateTask: Task<Void, Never>?

    func generate(writingStyleId: String) {
        guard canGenerate else { return }
        lastReportId = nil
        streamedOutput = ""
        displayedOutput = ""
        editedLaudoText = ""
        generationFindings = []
        latestVenousScheme = nil
        saveStatus = .idle
        feedbackState = .idle
        lastError = nil
        lastWarning = nil
        sanityIssues = []
        phase = .generating
        startStreamingFeedback()
        withAnimation(.easeOut(duration: 0.18)) { activeTab = .laudo }

        let req = GenerateRequest(
            rawInput: inputText,
            categoryHint: category,
            writingStyleId: writingStyleId,
            mode: generationMode
        )

        generateTask?.cancel()
        generateTask = Task { @MainActor in
            do {
                let stream = try await ReportService.generateStream(request: req)
                for try await event in stream {
                    guard !Task.isCancelled else { return }
                    handle(event: event)
                }
                // #11: stream terminou sem `done`/`error`/`blocked` (corte/frame
                // descartado) → não deixar a UI presa em .generating pra sempre.
                if case .generating = phase {
                    lastError = "A geração foi interrompida antes de concluir. Tente novamente."
                    phase = .error(message: lastError ?? "Erro")
                    stopStreamingFeedback()
                }
            } catch is CancellationError {
                // cancelada por reset/nova geração — encerra silenciosamente.
            } catch let error as APIError {
                guard !Task.isCancelled else { return }
                if case .unauthorized = error {
                    lastError = "Sessão expirada. Faça login novamente."
                } else {
                    lastError = error.errorDescription
                }
                phase = .error(message: lastError ?? "Erro")
                stopStreamingFeedback()
            } catch {
                guard !Task.isCancelled else { return }
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
            // 0,6s — correção próxima do envio chega rápido na Sala (4B).
            try? await Task.sleep(nanoseconds: 600_000_000)
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

    func submitFeedback(verdict: String, comment: String?) async {
        guard let reportId = lastReportId else { return }
        feedbackState = .submitting(verdict)

        do {
            try await FeedbackService.submit(
                reportId: reportId,
                categoryCode: category.rawValue,
                verdict: verdict,
                comment: comment
            )
            feedbackState = .submitted(verdict)
            Haptics.success()
        } catch {
            feedbackState = .error(error.localizedDescription)
            Haptics.error()
        }
    }

    private func handle(event: GenerateSSEEvent) {
        switch event {
        case .open(let payload):
            lastReportId = payload.reportId
        case .heartbeat:
            break
        case .stage(let payload):
            handle(stage: payload)
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
        case .sanity(let payload):
            /**
             * As issues do SERVIDOR entram no mesmo card das locais.
             *
             * O card "N pontos a revisar" era alimentado só pelo
             * `SanityChecker` local, e por isso avisos que só o backend conhece
             * — o principal deles: "a sua personalização não pôde ser aplicada,
             * este laudo saiu com a redação padrão" — não chegavam ao médico.
             *
             * O evento `sanity` chega DEPOIS do `done`, que já preencheu as
             * locais; daí o append. Dedupe por mensagem para o caso de as duas
             * fontes apontarem a mesma coisa.
             */
            let jaTem = Set(sanityIssues.map(\.message))
            sanityIssues.append(contentsOf: payload.result.issues
                .filter { !jaTem.contains($0.message) }
                .map { LocalSanityIssue(
                    code: $0.code ?? "servidor",
                    severity: $0.severity ?? "warning",
                    message: $0.message,
                    range: $0.range
                ) })
        case .done(let payload):
            // #10: se o `done` vier vazio/truncado, preserva o texto já
            // transmitido por tokens em vez de zerar o laudo do usuário.
            let resolved = payload.finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? streamedOutput
                : payload.finalText
            streamedOutput = resolved
            displayedOutput = resolved
            editedLaudoText = resolved
            lastReportId = payload.reportId
            sanityIssues = SanityChecker.check(text: resolved, category: category)
            phase = .done(reportId: payload.reportId)
            activeTab = .laudo
            stopStreamingFeedback()
        case .scheme(let payload):
            if payload.examType == "VENOSO_MMII" {
                latestVenousScheme = payload
            }
        case .blocked(let payload):
            lastError = payload.reason
            phase = .error(message: payload.reason)
            stopStreamingFeedback()
        case .error(let payload):
            lastError = payload.message
            phase = .error(message: payload.message)
            // DESCARTA o texto parcial já transmitido.
            //
            // O backend só emite `error` depois de recusar o laudo — por estar
            // vazio ou TRUNCADO (finish_reason=length). Mas os tokens até o
            // ponto do corte já chegaram aqui e ficariam na tela atrás do card
            // vermelho, parecendo laudo editável. Uma frase interrompida no meio
            // de uma medida ou de uma lateralidade é pior que nenhuma.
            streamedOutput = ""
            displayedOutput = ""
            stopStreamingFeedback()
        }
    }

    func reset() {
        generateTask?.cancel()
        stopStreamingFeedback()
        lastReportId = nil
        inputText = ""
        streamedOutput = ""
        displayedOutput = ""
        editedLaudoText = ""
        liveTranscript = ""
        generationFindings = []
        latestVenousScheme = nil
        phase = .idle
        activeTab = .achados
        saveStatus = .idle
        feedbackState = .idle
        lastError = nil
        currentStatusMessage = ""
    }

    private func startStreamingFeedback() {
        currentStatusMessage = "Interpretando o ditado…"
        generationFindings = []
    }

    private func stopStreamingFeedback() {
        currentStatusMessage = ""
    }

    private func handle(stage payload: StagePayload) {
        switch payload.stage {
        case "achado":
            appendGenerationFinding(payload.label)
        default:
            currentStatusMessage = payload.label
        }
    }

    private func appendGenerationFinding(_ label: String) {
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard !generationFindings.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) else {
            return
        }
        generationFindings.append(cleaned)
    }
}
