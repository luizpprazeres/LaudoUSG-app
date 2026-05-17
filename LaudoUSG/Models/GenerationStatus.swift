import Foundation

enum GenerationPhase: Equatable {
    case idle
    case recording
    case transcribing
    case ready
    case generating
    case clarifying(question: String)
    case done(reportId: String)
    case error(message: String)

    var isBusy: Bool {
        switch self {
        case .recording, .transcribing, .generating: return true
        default: return false
        }
    }
}

struct SSEEvent: Equatable {
    let name: String
    let data: String
}

enum GenerationEvent {
    case open(reportId: String)
    case structured(StructuredFindings)
    case validatorOk
    case ragReady
    case token(String)
    case sanity(SanityResult)
    case done(finalText: String)
    case errorMessage(String)
}
