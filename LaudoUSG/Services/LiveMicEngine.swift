import Foundation
import Observation

/// Contrato mínimo que a UI de gravação (`RecordingOverlay` + `GenerateViewModel`)
/// precisa de um motor de ditado ao vivo.
///
/// Existe pra permitir TROCAR o motor por categoria sem que a tela saiba qual
/// está rodando. Hoje há duas implementações:
///
/// - `DeepgramLiveService`   — streaming pela nuvem (padrão, todas as categorias)
/// - `AppleSpeechLiveService` — `SpeechTranscriber` on-device (iOS 26+, categoria TESTE)
///
/// A UI só lê; quem decide qual motor usar é o `GenerateViewModel`.
@MainActor
protocol LiveMicEngine: AnyObject, Observable {
    var isStreaming: Bool { get }
    var isReconnecting: Bool { get }
    /// Mensagem de estado legível ("Ouvindo — fale…", "Baixando modelo…").
    var status: String { get }
    /// Texto completo pra exibir: confirmado + parcial ao vivo.
    var liveTranscript: String { get }
    var errorMessage: String? { get }
    /// Nível RMS 0–1 pra waveform.
    var audioLevel: Float { get }
    var elapsed: TimeInterval { get }
    var wordCount: Int { get }

    /// Rótulo curto do motor, mostrado no overlay quando NÃO é o padrão.
    /// `nil` = motor padrão, não precisa anunciar.
    var engineLabel: String? { get }

    func tick()
    /// Prepara o motor antes do toque no mic (token, download de modelo…).
    func prewarm() async
    func start() async
    func stop() async
}

extension DeepgramLiveService: LiveMicEngine {
    /// Motor padrão — o overlay não anuncia nada.
    var engineLabel: String? { nil }
}
