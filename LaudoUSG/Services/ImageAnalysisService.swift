import Foundation
import os

enum ImageAnalysisError: Error, LocalizedError {
    case unsupportedCategory
    case emptyImage
    case emptyResult(String?)
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCategory:
            return "Análise de imagem disponível apenas para obstétrica, Doppler obstétrico e morfológico."
        case .emptyImage:
            return "Não consegui ler a imagem selecionada."
        case .emptyResult(let message):
            return message ?? "Não encontrei medidas nessa imagem."
        case .backend(let message):
            return message
        }
    }
}

enum ImageAnalysisService {
    private static let logger = Logger(subsystem: "com.laudousg.LaudoUSG", category: "image-analysis")

    static func canAnalyze(category: ReportCategory) -> Bool {
        switch category {
        case .obstetrica, .dopplerObstetrico, .morfologico:
            return true
        default:
            return false
        }
    }

    static func analyze(images: [Data], category: ReportCategory) async throws -> [BiometricData] {
        guard canAnalyze(category: category) else { throw ImageAnalysisError.unsupportedCategory }
        guard !images.isEmpty else { throw ImageAnalysisError.emptyImage }

        var results: [BiometricData] = []
        for image in images.prefix(3) {
            let result = try await analyze(image: image, category: category)
            results.append(result)
        }
        return results
    }

    static func format(_ results: [BiometricData], category: ReportCategory) -> String {
        let merged = merge(results)
        var sections: [String] = []

        let biometria = rows([
            ("DBP", merged.dbp),
            ("CC", merged.cc),
            ("CA", merged.ca),
            ("CF", merged.cf),
            ("Peso fetal estimado", merged.weight),
            ("Variação do peso", merged.weightVariation),
            ("Percentil", merged.percentile),
            ("IG", merged.gestAge),
            ("IG pela DUM", merged.gestAgeLMP),
            ("IG pela biometria", merged.gestAgeBiometry)
        ])
        if !biometria.isEmpty {
            sections.append("Biometria fetal:\n" + biometria.joined(separator: "\n"))
        }

        let doppler = rows([
            ("IP uterina direita", merged.ipRightUterine),
            ("IP uterina esquerda", merged.ipLeftUterine),
            ("IP artéria umbilical", merged.ipUmbilical),
            ("IP artéria cerebral média", merged.ipMCA),
            ("IP ducto venoso", merged.ipDuctusVenosus)
        ])
        if !doppler.isEmpty {
            sections.append("Doppler obstétrico:\n" + doppler.joined(separator: "\n"))
        }

        let morfologico = rows([
            ("Tíbia", merged.tibia),
            ("Fíbula", merged.fibula),
            ("Úmero", merged.humerus),
            ("Rádio", merged.radius),
            ("Ulna", merged.ulna),
            ("Cerebelo", merged.cerebellum),
            ("Cisterna magna", merged.cisternaMagna),
            ("Distância binocular", merged.binocularDistance),
            ("ILA", merged.ila),
            ("Sexo fetal", merged.gender)
        ])
        if category == .morfologico || !morfologico.isEmpty {
            if !morfologico.isEmpty {
                sections.append("Medidas morfológicas:\n" + morfologico.joined(separator: "\n"))
            }
        }

        return sections.joined(separator: "\n\n")
    }

    private static func analyze(image: Data, category: ReportCategory) async throws -> BiometricData {
        guard !image.isEmpty else { throw ImageAnalysisError.emptyImage }
        logger.info("Uploading compressed image: \(image.count, privacy: .public) bytes")

        let request = AnalyzeImageRequest(
            imageBase64: image.base64EncodedString(),
            category: category.rawValue,
            gemelar: false
        )
        let encoder = JSONEncoder()
        let body = try encoder.encode(request)
        logger.info("Image analysis request body: \(body.count, privacy: .public) bytes")
        let data = try await APIClient.shared.postRawJSON("/api/analyze-image", body: body)
        let response = try JSONDecoder().decode(AnalyzeImageResponse.self, from: data)

        guard response.success else {
            logger.error("Image analysis backend error: \(response.error ?? "unknown", privacy: .public)")
            throw ImageAnalysisError.backend(response.error ?? "Falha ao analisar imagem.")
        }
        if response.empty == true {
            throw ImageAnalysisError.emptyResult(response.message)
        }
        guard let data = response.data, !isEmpty(data) else {
            throw ImageAnalysisError.emptyResult(response.message)
        }
        logger.info("Image analysis completed with model: \(response.model ?? "unknown", privacy: .public)")
        return data
    }

    private static func rows(_ rows: [(String, String?)]) -> [String] {
        rows.compactMap { label, value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return "\(label): \(value)"
        }
    }

    private static func merge(_ results: [BiometricData]) -> BiometricData {
        results.reduce(BiometricData()) { partial, next in
            BiometricData(
                dbp: partial.dbp ?? next.dbp,
                cc: partial.cc ?? next.cc,
                ca: partial.ca ?? next.ca,
                cf: partial.cf ?? next.cf,
                weight: partial.weight ?? next.weight,
                weightVariation: partial.weightVariation ?? next.weightVariation,
                percentile: partial.percentile ?? next.percentile,
                gestAge: partial.gestAge ?? next.gestAge,
                gestAgeLMP: partial.gestAgeLMP ?? next.gestAgeLMP,
                gestAgeBiometry: partial.gestAgeBiometry ?? next.gestAgeBiometry,
                ipRightUterine: partial.ipRightUterine ?? next.ipRightUterine,
                ipLeftUterine: partial.ipLeftUterine ?? next.ipLeftUterine,
                ipUmbilical: partial.ipUmbilical ?? next.ipUmbilical,
                ipMCA: partial.ipMCA ?? next.ipMCA,
                ipDuctusVenosus: partial.ipDuctusVenosus ?? next.ipDuctusVenosus,
                tibia: partial.tibia ?? next.tibia,
                fibula: partial.fibula ?? next.fibula,
                humerus: partial.humerus ?? next.humerus,
                radius: partial.radius ?? next.radius,
                ulna: partial.ulna ?? next.ulna,
                cerebellum: partial.cerebellum ?? next.cerebellum,
                cisternaMagna: partial.cisternaMagna ?? next.cisternaMagna,
                binocularDistance: partial.binocularDistance ?? next.binocularDistance,
                ila: partial.ila ?? next.ila,
                gender: partial.gender ?? next.gender
            )
        }
    }

    private static func isEmpty(_ data: BiometricData) -> Bool {
        format([data], category: .morfologico).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
