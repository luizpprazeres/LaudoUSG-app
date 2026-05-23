import Foundation

enum ReportStatus: String, Codable {
    case draft
    case awaitingClarify = "awaiting_clarify"
    case generated
    case blocked
    case published
    case discarded
}

struct Report: Identifiable, Codable, Hashable {
    let id: String
    var categoryCode: String
    var writingStyle: String?
    var status: ReportStatus
    var rawInput: String?
    var consolidatedTranscript: String?
    var generatedOutput: String?
    var finalOutput: String?
    var createdAt: Date
    var updatedAt: Date

    var category: ReportCategory? {
        ReportCategory(rawValue: categoryCode)
    }

    var displayText: String {
        finalOutput ?? generatedOutput ?? ""
    }
}

struct StructuredFindings: Codable, Hashable {
    var category: String?
    var measurements: [Measurement]?
    var laterality: String?
    var commands: [String]?
    var confidence: Double?
}

struct Measurement: Codable, Hashable {
    var label: String
    var value: Double
    var unit: String
}

struct SanityIssue: Identifiable, Codable, Hashable {
    var id: String { code ?? message }
    let code: String?
    let severity: String?
    let message: String
    let range: String?

    // Backend (deterministicSanity.ts) emite `detail` no lugar de `message` e `type` no
    // lugar de `code`. Decode tolerante pra aceitar ambos — alinhamento futuro fica no
    // backend, mas o stream não pode quebrar pra issues sanity.
    private enum CodingKeys: String, CodingKey {
        case code, severity, message, range
        case type, detail, trechoLaudo = "trecho_laudo"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let codeValue = try c.decodeIfPresent(String.self, forKey: .code)
        let typeValue = try c.decodeIfPresent(String.self, forKey: .type)
        self.code = codeValue ?? typeValue
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity)
        let messageValue = try c.decodeIfPresent(String.self, forKey: .message)
        let detailValue = try c.decodeIfPresent(String.self, forKey: .detail)
        self.message = messageValue ?? detailValue ?? ""
        let rangeValue = try c.decodeIfPresent(String.self, forKey: .range)
        let trechoValue = try c.decodeIfPresent(String.self, forKey: .trechoLaudo)
        self.range = rangeValue ?? trechoValue
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(code, forKey: .code)
        try c.encodeIfPresent(severity, forKey: .severity)
        try c.encode(message, forKey: .message)
        try c.encodeIfPresent(range, forKey: .range)
    }
}

struct SanityResult: Codable, Hashable {
    let verdict: String
    let issues: [SanityIssue]
    let summary: String?
}
