import Foundation

struct GenerateRequest: Codable, Sendable {
    static let defaultWritingStyleId = "11111111-1111-4111-8111-111111111111"

    let rawInput: String
    let categoryHint: ReportCategory?
    let writingStyleId: String
    let consolidatedTranscript: String?
    let resumeFromReportId: String?
    let clarifyAnswers: [ClarifyAnswer]?

    init(
        rawInput: String,
        categoryHint: ReportCategory? = nil,
        writingStyleId: String = GenerateRequest.defaultWritingStyleId,
        consolidatedTranscript: String? = nil,
        resumeFromReportId: String? = nil,
        clarifyAnswers: [ClarifyAnswer]? = nil
    ) {
        self.rawInput = rawInput
        self.categoryHint = categoryHint
        self.writingStyleId = writingStyleId
        self.consolidatedTranscript = consolidatedTranscript
        self.resumeFromReportId = resumeFromReportId
        self.clarifyAnswers = clarifyAnswers
    }
}

struct ClarifyAnswer: Codable, Sendable, Hashable {
    let questionId: String
    let answer: String
}
