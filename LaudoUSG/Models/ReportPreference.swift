import Foundation

struct ReportPreferenceRecord: Codable, Sendable, Hashable {
    let categoryCode: String
    let defaultVariantId: String?
    let variantKey: String?
}

struct ReportTemplateVariantRecord: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let categoryCode: String
    let writingStyleId: String
    let variantKey: String
    let name: String
}

struct ReportPreferencesResponse: Decodable, Sendable {
    let preferences: [ReportPreferenceRecord]
    let availableVariants: [ReportTemplateVariantRecord]
}
