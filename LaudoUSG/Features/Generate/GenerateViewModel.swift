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
        case insertText(String)
    }
    let id = UUID()
    let label: String
    let action: Action

    static func defaults(for category: ReportCategory) -> [GenerateShortcut] {
        switch category {
        case .obstetrica, .dopplerObstetrico, .morfologico:
            return [
                GenerateShortcut(label: "Calcular IG pela DUM", action: .calcularIGporDUM),
                GenerateShortcut(label: "Calcular percentis", action: .calcularPercentis),
                GenerateShortcut(label: "BCF presentes", action: .insertText("Feto único, em situação longitudinal e apresentação cefálica, com BCF presentes."))
            ]
        case .tireoide:
            return [
                GenerateShortcut(label: "Glândula normal", action: .insertText("Glândula tireoide tópica, contornos regulares, dimensões e ecotextura preservadas.")),
                GenerateShortcut(label: "Doppler normal", action: .insertText("Vascularização ao Doppler colorido sem alterações.")),
                GenerateShortcut(label: "Sem nódulos", action: .insertText("Sem nódulos detectados ao exame."))
            ]
        case .mamaria:
            return [
                GenerateShortcut(label: "Mamas normais", action: .insertText("Parênquima mamário sem alterações.")),
                GenerateShortcut(label: "BI-RADS 1", action: .insertText("Categoria BI-RADS 1.")),
                GenerateShortcut(label: "Sem nódulos", action: .insertText("Sem nódulos sólidos ou císticos identificados."))
            ]
        case .abdomenTotal, .abdomenSuperior, .abdomenTotalDoppler:
            return [
                GenerateShortcut(label: "Fígado normal", action: .insertText("Fígado de dimensões normais, contornos regulares, ecogenicidade preservada.")),
                GenerateShortcut(label: "Vesícula sem cálculos", action: .insertText("Vesícula biliar de paredes finas, sem cálculos.")),
                GenerateShortcut(label: "Rins normais", action: .insertText("Rins de dimensões e ecotextura normais."))
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
    var isDopplerCalculatorPresented = false
    var isRecordingOverlayPresented = false

    let speech = SpeechService()
    private var saveTask: Task<Void, Never>?
    private var statusRotationTimer: Timer?
    private var typingTimer: Timer?
    private var statusIndex: Int = 0

    // 10 mensagens únicas × 1.0s/cada = ~10s total. Backend leva 7-15s típico.
    // Não ciclar — parar na última e ficar fixa até primeiro token chegar.
    private let statusMessages = [
        "Buscando bases de dados...",
        "Lendo suas preferências...",
        "Corrigindo vocabulário...",
        "Aplicando regras clínicas...",
        "Verificando faixas de normalidade...",
        "Estruturando achados...",
        "Selecionando frases padrão...",
        "Montando a conclusão...",
        "Validando coerência...",
        "Finalizando..."
    ]

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
        case .insertText(let text):
            insertSnippet(text)
        }
    }

    func calcularIGporDUM() {
        guard let dum = DopplerParser.extractDUM(achados: inputText) else {
            // Sem DUM detectada — fallback: abre IGCalculator pra usuário digitar manualmente
            isIGCalculatorPresented = true
            return
        }
        guard let result = GestationalAgeCalculator.calcByDUM(dum: dum) else {
            // DUM no futuro ou diff inválido — fallback pra calculator
            isIGCalculatorPresented = true
            return
        }
        // Insere o bloco já formatado: "Idade gestacional de X semanas e Y dias (DUM: DD/MM/AAAA). DPP: DD/MM/AAAA."
        insertSnippet(result.insertBloco)
    }

    func calcularPercentis() {
        let findings = DopplerParser.parse(achados: inputText)
        guard let ig = findings.ig, ig.weeks >= 20 && ig.weeks <= 41 else {
            // Sem IG ou IG fora da faixa de tabelas (20-41 sem) — abre calculator pra inserir manual
            isDopplerCalculatorPresented = true
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
            // Sem IPs reconhecidos — abre calculator pra digitar
            isDopplerCalculatorPresented = true
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

    func startRecording() {
        guard !phase.isBusy else { return }
        Task { @MainActor in
            let granted = await speech.requestPermissions()
            guard granted else {
                lastError = speech.lastError?.errorDescription ?? "Sem permissão para gravar."
                return
            }
            do {
                liveTranscript = ""
                try await speech.start()
                phase = .recording
                isRecordingOverlayPresented = true
            } catch {
                lastError = (error as? SpeechServiceError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func cancelRecording() {
        speech.cancel()
        liveTranscript = ""
        isRecordingOverlayPresented = false
        phase = inputText.isEmpty ? .idle : .ready
    }

    func finishRecording() {
        isRecordingOverlayPresented = false
        phase = .transcribing
        Task { @MainActor in
            let transcript = await speech.stop()
            if !transcript.isEmpty {
                if inputText.isEmpty {
                    inputText = transcript
                } else {
                    let separator = inputText.hasSuffix("\n") ? "" : "\n"
                    inputText += separator + transcript
                }
            } else if let err = speech.lastError {
                lastError = err.errorDescription
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
            try await HistoryService.updateFinalOutput(reportId: reportId, finalText: editedLaudoText)
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
            stopStatusRotation()
            streamedOutput += payload.delta
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
        stopStreamingFeedback()
        statusIndex = 0
        currentStatusMessage = statusMessages[statusIndex]
        startStatusRotation()
        startTypingAnimation()
    }

    private func startStatusRotation() {
        // 1.4s por mensagem (legível confortável). Lista tem 10 únicas → 14s totais.
        // Quando chegar na última, fica fixa até primeiro token (NÃO cicla).
        statusRotationTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rotateStatusMessage()
            }
        }
    }

    private func startTypingAnimation() {
        // 8ms × 3 chars = ~375 chars/s (visualmente bem rápido, fluido)
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceDisplayedOutput()
            }
        }
    }

    private func rotateStatusMessage() {
        // Se já está na última mensagem, para de rodar (mantém última fixa).
        // Evita repetição irritante quando backend leva mais que 10s.
        if statusIndex >= statusMessages.count - 1 {
            statusRotationTimer?.invalidate()
            statusRotationTimer = nil
            return
        }
        statusIndex += 1
        currentStatusMessage = statusMessages[statusIndex]
    }

    private func advanceDisplayedOutput() {
        guard displayedOutput.count < streamedOutput.count else { return }

        // 3 chars por tick (em vez de 2) — mais sensação de "digitação rápida"
        let advanceBy = min(3, streamedOutput.count - displayedOutput.count)
        let endIndex = streamedOutput.index(
            streamedOutput.startIndex,
            offsetBy: displayedOutput.count + advanceBy
        )
        displayedOutput = String(streamedOutput[..<endIndex])
    }

    private func stopStatusRotation() {
        statusRotationTimer?.invalidate()
        statusRotationTimer = nil
        currentStatusMessage = ""
    }

    private func stopStreamingFeedback() {
        stopStatusRotation()
        typingTimer?.invalidate()
        typingTimer = nil
    }
}
