#if DEBUG
import SwiftUI
import Observation

/// Modo de demonstração do "Ajustar laudo" — só em DEBUG.
///
/// Abre a tela do laudo com um laudo FICTÍCIO (sem paciente), um `/api/edit` simulado
/// e um microfone que "ouve" uma frase pronta. Não toca no backend nem no banco.
/// Serve para screenshots do fluxo no simulador.
///
/// Argumentos de execução:
///   -AjusteLaudoDemo YES
///   -AjusteDemoState dica|selecionado|aberto|previa|recusa|aplicado
/// "dica" zera o "já viu" da dica; os outros estados a dão por vista.
enum AdjustLaudoDemo {
    static var isActive: Bool {
        UserDefaults.standard.bool(forKey: "AjusteLaudoDemo")
    }

    static var state: String {
        UserDefaults.standard.string(forKey: "AjusteDemoState") ?? "dica"
    }

    static let reportId = "00000000-0000-4000-8000-000000000238"

    static let instruction = "acrescente cisto simples de 2 cm no rim direito"

    static let laudo = """
    ULTRASSONOGRAFIA DE ABDOME TOTAL

    TÉCNICA: Exame realizado com transdutor convexo multifrequencial.

    ACHADOS:
    Fígado de dimensões normais, contornos regulares e ecotextura homogênea.
    Vesícula biliar normodistendida, de paredes finas, sem cálculos.
    Vias biliares intra e extra-hepáticas não dilatadas.
    Pâncreas de dimensões e ecotextura normais nas porções visualizadas.
    Baço de dimensões normais e ecotextura homogênea.
    Rins tópicos, de dimensões normais, sem imagens de cálculos ou cistos.
    Bexiga com boa repleção, paredes finas e conteúdo anecoico.
    Aorta abdominal de calibre normal.
    Ausência de líquido livre na cavidade.

    CONCLUSÃO:
    Exame dentro dos limites da normalidade.
    """

    static let rimLinha = "Rins tópicos, de dimensões normais, sem imagens de cálculos ou cistos."
    static let rimEditado = "Rins tópicos, de dimensões normais, sem imagens de cálculos. Cisto simples no rim direito, medindo 2,0 cm."

    static var laudoEditado: String {
        laudo
            .replacingOccurrences(of: rimLinha, with: rimEditado)
            .replacingOccurrences(of: "Exame dentro dos limites da normalidade.", with: "Cisto simples no rim direito.")
    }

    @MainActor
    static func makeViewModel() -> GenerateViewModel {
        let rejects = state == "recusa"
        UserDefaults.standard.set(state != "dica", forKey: AdjustHint.seenKey)
        let vm = GenerateViewModel(reportEditor: DemoReportEditor(rejects: rejects))
        vm.skipsRemoteBootstrap = true
        vm.saveFinalOutput = { _, _ in }
        vm.micEngineOverride = DemoMicEngine(script: instruction)
        vm.category = .abdomenTotal
        vm.inputText = "abdome total normal"
        vm.streamedOutput = laudo
        vm.displayedOutput = laudo
        vm.editedLaudoText = laudo
        vm.lastReportId = reportId
        vm.phase = .done(reportId: reportId)
        vm.saveStatus = .saved
        vm.activeTab = .laudo
        if state == "ditado" { prepareDitado(vm) }
        return vm
    }

    /// Estudo de transcrição 12/10 (opção D): achados com erros típicos do Deepgram e a revisão simulada.
    static let ditado = "Rim direito medindo 10,2 x 4,5 x 4,1 cm, sem dilatação. Vesícula com cálculo de 1,2 cm, 6 sinais de colecistite. Mama esquerda C e nódulos. Cisto de Baker na fossa apoplítea. Útero medindo 7.34 0,1 x 5,2 cm. Pico sistólico de 6 e 20 cm/s."

    @MainActor
    private static func prepareDitado(_ vm: GenerateViewModel) {
        vm.activeTab = .achados
        vm.phase = .ready
        vm.inputText = ditado
        vm.ditadoReviewer = { text, _ in
            let ns = text as NSString
            func at(_ o: String, _ r: String?, _ k: String, auto: Bool, conf: Double) -> DitadoSuggestion {
                let g = ns.range(of: o)
                return DitadoSuggestion(start: g.location, end: g.location + g.length, original: o, replacement: r, kind: k, confidence: conf, automatic: auto)
            }
            return [
                at("C e", "sem", "negacao", auto: true, conf: 0.84),
                at("apoplítea", "poplítea", "grafia", auto: true, conf: 0.91),
                at("6", "sem", "negacao", auto: false, conf: 0.62),
                at("6 e 20", "120", "centena", auto: false, conf: 0.76),
                at("7.34 0,1", nil, "medida", auto: false, conf: 1),
            ]
        }
    }

    /// Leva a tela ao estado pedido. Os atrasos imitam o uso real (o sheet precisa
    /// estar na tela antes do microfone "ouvir").
    @MainActor
    static func drive(_ vm: GenerateViewModel) async {
        let rimIndex = laudo.components(separatedBy: "\n").firstIndex(of: rimLinha)
        let anchor: String? = rimLinha
        switch state {
        case "ditado":
            await pause(0.4)
            vm.requestDitadoReview()
        case "selecionado":
            vm.adjust.selectedLine = rimIndex
        case "aberto":
            vm.adjust.selectedLine = rimIndex
            await pause(0.6)
            vm.presentAdjust(anchor: anchor, listen: true)
        case "previa", "recusa", "aplicado":
            await pause(0.6)
            vm.presentAdjust(anchor: anchor, listen: true)
            await pause(2.4)
            await vm.submitAdjust()
            if state == "aplicado" {
                await pause(0.8)
                vm.applyAdjust()
            }
        default:
            break
        }
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

/// Raiz do app no modo de demonstração (sem login, sem rede).
struct AdjustLaudoDemoHost: View {
    @State private var app = AppState()
    @State private var vm = AdjustLaudoDemo.makeViewModel()

    var body: some View {
        GenerateView(viewModel: vm)
            .environment(app)
            .task { await AdjustLaudoDemo.drive(vm) }
    }
}

/// `/api/edit` simulado com a resposta que o backend da W17 daria para o pedido
/// de demonstração (corpo + conclusão normal trocados).
@MainActor
final class DemoReportEditor: ReportEditing {
    let rejects: Bool

    init(rejects: Bool) {
        self.rejects = rejects
    }

    func edit(reportId: String, instruction: String, target: AdjustTarget) async throws -> EditReportResponse {
        try await Task.sleep(nanoseconds: 700_000_000)
        if rejects {
            return EditReportResponse(
                editedText: AdjustLaudoDemo.laudo,
                changedLines: [
                    EditReportChangedLine(line: 11, before: AdjustLaudoDemo.rimLinha, after: AdjustLaudoDemo.rimEditado, section: "body"),
                ],
                accepted: false,
                reason: "achado novo com conclusão normal — confirme"
            )
        }
        return EditReportResponse(
            editedText: AdjustLaudoDemo.laudoEditado,
            changedLines: [
                EditReportChangedLine(line: 11, before: AdjustLaudoDemo.rimLinha, after: AdjustLaudoDemo.rimEditado, section: "body"),
                EditReportChangedLine(line: 17, before: "Exame dentro dos limites da normalidade.", after: "Cisto simples no rim direito.", section: "conclusion"),
            ],
            accepted: true,
            reason: nil
        )
    }
}

/// Microfone de mentira: "ouve" o roteiro palavra a palavra.
@Observable
@MainActor
final class DemoMicEngine: LiveMicEngine {
    private let script: String
    private var feedTask: Task<Void, Never>?

    var isStreaming = false
    var isReconnecting = false
    var status = "Ouvindo — fale…"
    var liveTranscript = ""
    var errorMessage: String?
    var audioLevel: Float = 0.3
    var elapsed: TimeInterval = 0
    var wordCount: Int { liveTranscript.split(separator: " ").count }
    var engineLabel: String? { "Demonstração" }

    init(script: String) {
        self.script = script
    }

    func tick() {
        if isStreaming { elapsed += 0.1 }
    }

    func prewarm() async {}

    func start() async {
        liveTranscript = ""
        elapsed = 0
        isStreaming = true
        let words = script.split(separator: " ").map(String.init)
        feedTask?.cancel()
        feedTask = Task { @MainActor [weak self] in
            for word in words {
                try? await Task.sleep(nanoseconds: 160_000_000)
                guard let self, !Task.isCancelled, self.isStreaming else { return }
                self.liveTranscript = self.liveTranscript.isEmpty ? word : self.liveTranscript + " " + word
            }
        }
    }

    func stop() async {
        isStreaming = false
        feedTask?.cancel()
        liveTranscript = script
    }
}
#endif
