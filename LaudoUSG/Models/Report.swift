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
    var id: String { code }
    let code: String
    let severity: String
    let message: String
    let range: String?
}

struct SanityResult: Codable, Hashable {
    let verdict: String
    let issues: [SanityIssue]
    let summary: String?
}
