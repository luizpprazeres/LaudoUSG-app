import Foundation
import os

/// Envia um esquema visual (PNG + PDF base64) pra Sala do Auxiliar.
/// Genérico — usado por miomas, mama e tireoide. Substitui o esquema anterior
/// do mesmo (report × tipo) no backend.
enum SalaSchemaUploader {
    private static let log = Logger(subsystem: "com.laudousg.LaudoUSG", category: "sala-schema")

    static func upload(
        png: Data, pdf: Data?, examType: String, examLabel: String, reportId: String?,
        myomaContract: MyomaSchemeContract? = nil
    ) async -> Bool {
        guard let body = try? makePayloadData(
            png: png, pdf: pdf, examType: examType, examLabel: examLabel,
            reportId: reportId, myomaContract: myomaContract
        ) else { return false }
        do {
            let data = try await APIClient.shared.postRawJSON("/api/sala/push-schema", body: body)
            let s = String(data: data, encoding: .utf8) ?? ""
            return s.contains("\"ok\":true") || s.contains("\"ok\": true")
        } catch {
            log.error("upload de esquema falhou: \(error.localizedDescription)")
            return false
        }
    }

    static func makePayloadData(
        png: Data, pdf: Data?, examType: String, examLabel: String, reportId: String?,
        myomaContract: MyomaSchemeContract? = nil
    ) throws -> Data {
        var payload: [String: Any] = [
            "examType": examType,
            "examLabel": examLabel,
            "png": png.base64EncodedString(),
        ]
        if let pdf { payload["pdf"] = pdf.base64EncodedString() }
        if let reportId { payload["reportId"] = reportId }
        if examType == MyomaSchemeContract.myomaExamType, let myomaContract {
            let encoded = try JSONEncoder().encode(myomaContract)
            let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            payload["contractVersion"] = object?["contractVersion"]
            payload["findings"] = object?["findings"]
        }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// Conveniência: lê os PNG/PDF de URLs temporárias (saída dos exporters).
    static func upload(
        pngURL: URL?, pdfURL: URL?, examType: String, examLabel: String, reportId: String?
    ) async -> Bool {
        guard let pngURL, let png = try? Data(contentsOf: pngURL) else { return false }
        let pdf = pdfURL.flatMap { try? Data(contentsOf: $0) }
        return await upload(png: png, pdf: pdf, examType: examType, examLabel: examLabel, reportId: reportId)
    }
}
