import Foundation

/// Quem faz o ajuste incremental. Protocolo para a tela poder rodar com um mock
/// (testes e o modo de demonstração de DEBUG) sem tocar no backend.
@MainActor
protocol ReportEditing: AnyObject {
    func edit(reportId: String, instruction: String, target: AdjustTarget) async throws -> EditReportResponse
}

enum ReportEditError: LocalizedError, Equatable {
    case disabled
    case reportNotFound
    case reportWithoutText
    case other(String)

    var errorDescription: String? {
        switch self {
        case .disabled: return "O ajuste por voz está desligado no servidor no momento."
        case .reportNotFound: return "Este laudo não foi encontrado no servidor."
        case .reportWithoutText: return "O laudo ainda não tem texto salvo para ajustar."
        case .other(let message): return message
        }
    }

    /// Traduz o erro do `APIClient` nos casos que o `/api/edit` devolve.
    static func from(_ error: Error) -> ReportEditError {
        if let apiError = error as? APIError, case .http(let status, let body) = apiError {
            let body = body ?? ""
            if status == 404 && body.contains("edit_incremental_disabled") { return .disabled }
            if status == 404 && body.contains("report_not_found") { return .reportNotFound }
            if status == 409 { return .reportWithoutText }
            return .other("O servidor não conseguiu ajustar o laudo (erro \(status)). Tente de novo.")
        }
        if let local = error as? LocalizedError, let description = local.errorDescription {
            return .other(description)
        }
        return .other(error.localizedDescription)
    }
}

@MainActor
final class LiveReportEditor: ReportEditing {
    nonisolated init() {}

    func edit(reportId: String, instruction: String, target: AdjustTarget) async throws -> EditReportResponse {
        do {
            return try await APIClient.shared.post(
                "/api/edit",
                body: EditReportRequest(reportId: reportId, instruction: instruction, target: target.rawValue),
                as: EditReportResponse.self
            )
        } catch {
            throw ReportEditError.from(error)
        }
    }
}
