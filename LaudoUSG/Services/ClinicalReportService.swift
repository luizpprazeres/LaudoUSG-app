import Foundation

enum ClinicalReportService {
    struct CreateRequest: Encodable, Equatable, Sendable {
        let contract: ClinicalModelDraft
        let writingStyleId: String?

        private enum CodingKeys: String, CodingKey {
            case contract
            case writingStyleId = "writing_style_id"
        }
    }

    struct CreateResponse: Decodable, Sendable { let report: Report }

    struct Report: Decodable, Sendable {
        let id: String
        let categoryCode: String
        let status: String
        let contentRevision: Int
        let reviewStatus: String
        let physicianReviewed: Bool
        let generatedOutput: String
        let contract: ClinicalModelDraft
        let warnings: [ClinicalContractIssue]
        let createdAt: Date

        // Chaves explícitas: o contrato aninhado é camelCase e `psvCms` usa o
        // nome do vaso como chave, que `convertFromSnakeCase` reescreveria.
        private enum CodingKeys: String, CodingKey {
            case id
            case categoryCode = "category_code"
            case status
            case contentRevision = "content_revision"
            case reviewStatus = "review_status"
            case physicianReviewed = "physician_reviewed"
            case generatedOutput = "generated_output"
            case contract
            case warnings
            case createdAt = "created_at"
        }
    }

    struct ReviewRequest: Encodable, Equatable, Sendable {
        let expectedRevision: Int
        let expectedText: String
    }

    struct ReviewResponse: Decodable, Sendable {
        let ok: Bool
        let contentRevision: Int
        let reviewStatus: String
        let reviewedAt: Date
    }

    struct ErrorBody: Decodable, Sendable {
        let error: String
        let issues: [ClinicalContractIssue]?
    }

    /// Chaves ordenadas: o renderer do servidor percorre `psvCms` na ordem do
    /// JSON recebido, e a prévia local lista as VPS na mesma ordem.
    static let requestEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = JSONDecoder.api.dateDecodingStrategy
        return decoder
    }()

    static func create(
        draft: ClinicalModelDraft,
        writingStyleId: String?
    ) async throws -> Report {
        let request = CreateRequest(
            contract: draft.normalizedForSubmission.settingPhysicianReviewed(false),
            writingStyleId: writingStyleId
        )
        let data = try await mappingServerErrors {
            try await APIClient.shared.postRawJSON(
                "/api/v1/clinical-reports",
                body: requestEncoder.encode(request)
            )
        }
        return try decoder.decode(CreateResponse.self, from: data).report
    }

    static func review(
        reportId: String,
        expectedRevision: Int,
        expectedText: String
    ) async throws -> ReviewResponse {
        let request = ReviewRequest(
            expectedRevision: expectedRevision,
            expectedText: expectedText
        )
        let data = try await mappingServerErrors {
            try await APIClient.shared.postRawJSON(
                "/api/v1/clinical-reports/\(reportId)/review",
                body: JSONEncoder().encode(request)
            )
        }
        return try decoder.decode(ReviewResponse.self, from: data)
    }

    private static func mappingServerErrors(_ operation: () async throws -> Data) async throws -> Data {
        do {
            return try await operation()
        } catch APIError.http(let status, let body) {
            throw ClinicalReportServiceError(status: status, body: body)
        }
    }
}

/// Respostas conhecidas de `/api/v1/clinical-reports`. O servidor é a
/// autoridade dos bloqueios clínicos: os `issues` de um 422 são exibidos como
/// vieram, mesmo que o espelho local tenha deixado passar.
struct ClinicalReportServiceError: LocalizedError, Equatable {
    let status: Int
    let code: String?
    let issues: [ClinicalContractIssue]

    init(status: Int, body: String?) {
        let parsed = body
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? ClinicalReportService.decoder.decode(ClinicalReportService.ErrorBody.self, from: $0) }
        self.status = status
        self.code = parsed?.error
        self.issues = parsed?.issues ?? []
    }

    var errorDescription: String? {
        switch code {
        case "clinical_models_v1_unavailable":
            return "Os modelos clínicos estruturados ainda não foram liberados no servidor."
        case "clinical_contract_incomplete":
            let details = issues.map { "• \($0.message)" }.joined(separator: "\n")
            return details.isEmpty
                ? "O servidor bloqueou o laudo por dados clínicos incompletos."
                : "O servidor bloqueou o laudo:\n\(details)"
        case "invalid_clinical_contract":
            return "O servidor recusou o formato dos dados. Atualize o app antes de gerar este laudo."
        case "clinical_category_unavailable":
            return "Esta categoria ainda não está ativa no servidor."
        case "writing_style_unavailable":
            return "O estilo de redação escolhido não está disponível. Revise o estilo nas configurações."
        case "content_changed":
            return "O texto mudou no servidor desde a última versão exibida. Gere a prévia novamente antes de revisar."
        case "report_not_ready":
            return "O laudo ainda não pode ser liberado. Confira pendências marcadas para revisão."
        case "not_found":
            return "O laudo não foi encontrado no servidor."
        default:
            return "Não foi possível concluir a operação (erro \(status))."
        }
    }
}
