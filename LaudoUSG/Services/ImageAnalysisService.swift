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
            return "Análise de imagem indisponível para esta categoria."
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
        case .obstetrica, .dopplerObstetrico, .morfologico, .tireoide, .mamaria, .dopplerCarotidas:
            return true
        default:
            return false
        }
    }

    static func analyze(
        images: [Data],
        category: ReportCategory,
        includeDoppler: Bool = false
    ) async throws -> [BiometricData] {
        guard canAnalyze(category: category) else { throw ImageAnalysisError.unsupportedCategory }
        guard !images.isEmpty else { throw ImageAnalysisError.emptyImage }

        var results: [BiometricData] = []
        for image in images.prefix(3) {
            let result = try await analyze(
                image: image,
                category: category,
                includeDoppler: includeDoppler
            )
            results.append(result)
        }
        return results
    }

    static func format(_ results: [BiometricData], category: ReportCategory) -> String {
        let merged = merge(results)
        var sections: [String] = []

        if category == .tireoide {
            let gland = rows([
                ("Lobo direito", dimensions(merged.thyroidRightLobe)),
                ("Lobo esquerdo", dimensions(merged.thyroidLeftLobe)),
                ("Istmo", dimensions(merged.thyroidIsthmus))
            ])
            if !gland.isEmpty { sections.append("Medidas da tireoide:\n" + gland.joined(separator: "\n")) }
            let nodules = (merged.thyroidNodules ?? []).enumerated().map { index, nodule in
                let axes = [nodule.c1, nodule.c2, nodule.c3].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " x ")
                let location = nodule.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let detail = [axes.isEmpty ? "" : "\(axes) cm", location].filter { !$0.isEmpty }.joined(separator: " · ")
                return "Nódulo \(index + 1) (\(lobeLabel(nodule.lobe))): \(detail)"
            }
            if !nodules.isEmpty { sections.append("Nódulos:\n" + nodules.joined(separator: "\n")) }
            return sections.joined(separator: "\n\n")
        }

        if category == .mamaria {
            return (merged.breastFindings ?? []).enumerated().map { index, finding in
                let axes = [finding.c1, finding.c2, finding.c3].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " x ")
                let type: String
                switch finding.type {
                case "nodulo": type = "Nódulo"
                case "cisto_simples": type = "Cisto simples"
                case "multiplos_cistos": type = "Cistos múltiplos"
                default: type = "Calcificações"
                }
                let detail = [axes.isEmpty ? "" : "\(axes) cm", finding.location ?? "", finding.hour ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
                return "\(index + 1). \(type) — mama \(finding.side)\(detail.isEmpty ? "" : ": \(detail)")"
            }.joined(separator: "\n")
        }

        if category == .dopplerCarotidas {
            let measurements = (merged.carotidMeasurements ?? []).map { item in
                let vessel: String
                switch item.vessel {
                case "comum": vessel = "carótida comum"
                case "interna": vessel = "carótida interna"
                case "externa": vessel = "carótida externa"
                default: vessel = "vertebral"
                }
                let values = [
                    item.psv.map { "PSV \($0)" }, item.vdf.map { "VDF \($0)" },
                    item.ir.map { "IR \($0)" }, item.emi.map { "EMI \($0)" },
                    item.flowDirection.map { "Fluxo \($0)" }
                ].compactMap { $0 }
                return "\(vessel) \(item.side): \(values.joined(separator: " · "))"
            }
            let plaques = (merged.carotidPlaques ?? []).enumerated().map { index, item in
                let details = [item.location ?? "", item.thickness.map { "\($0) mm" } ?? "", item.stenosisPercent.map { "\($0)% informado" } ?? ""].filter { !$0.isEmpty }
                return "Placa \(index + 1) \(item.side): \(details.joined(separator: " · "))"
            }
            return (measurements + plaques).joined(separator: "\n")
        }

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
        if category != .dopplerObstetrico && !biometria.isEmpty {
            sections.append("Biometria fetal:\n" + biometria.joined(separator: "\n"))
        }

        let doppler = rows([
            ("IR uterina direita", merged.irRightUterine),
            ("IP uterina direita", merged.ipRightUterine),
            ("IR uterina esquerda", merged.irLeftUterine),
            ("IP uterina esquerda", merged.ipLeftUterine),
            ("IR artéria umbilical", merged.irUmbilical),
            ("IP artéria umbilical", merged.ipUmbilical),
            ("IR artéria cerebral média", merged.irMCA),
            ("IP artéria cerebral média", merged.ipMCA),
            ("IR ducto venoso", merged.irDuctusVenosus),
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

    private static func analyze(
        image: Data,
        category: ReportCategory,
        includeDoppler: Bool
    ) async throws -> BiometricData {
        guard !image.isEmpty else { throw ImageAnalysisError.emptyImage }
        logger.info("Uploading compressed image: \(image.count, privacy: .public) bytes")

        let request = AnalyzeImageRequest(
            imageBase64: image.base64EncodedString(),
            category: category.rawValue,
            gemelar: false,
            modules: includeDoppler && category != .dopplerObstetrico
                ? [ReportCategory.dopplerObstetrico.rawValue]
                : []
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

    static func merge(_ results: [BiometricData]) -> BiometricData {
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
                irRightUterine: partial.irRightUterine ?? next.irRightUterine,
                ipRightUterine: partial.ipRightUterine ?? next.ipRightUterine,
                irLeftUterine: partial.irLeftUterine ?? next.irLeftUterine,
                ipLeftUterine: partial.ipLeftUterine ?? next.ipLeftUterine,
                irUmbilical: partial.irUmbilical ?? next.irUmbilical,
                ipUmbilical: partial.ipUmbilical ?? next.ipUmbilical,
                irMCA: partial.irMCA ?? next.irMCA,
                ipMCA: partial.ipMCA ?? next.ipMCA,
                irDuctusVenosus: partial.irDuctusVenosus ?? next.irDuctusVenosus,
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
                gender: partial.gender ?? next.gender,
                thyroidRightLobe: partial.thyroidRightLobe ?? next.thyroidRightLobe,
                thyroidLeftLobe: partial.thyroidLeftLobe ?? next.thyroidLeftLobe,
                thyroidIsthmus: partial.thyroidIsthmus ?? next.thyroidIsthmus,
                thyroidNodules: mergeNodules(partial.thyroidNodules, next.thyroidNodules),
                breastFindings: mergeBreastFindings(partial.breastFindings, next.breastFindings),
                carotidMeasurements: mergeCarotidMeasurements(partial.carotidMeasurements, next.carotidMeasurements),
                carotidPlaques: mergeCarotidPlaques(partial.carotidPlaques, next.carotidPlaques)
            )
        }
    }

    private static func dimensions(_ value: ThyroidMeasurements?) -> String? {
        guard let value else { return nil }
        let axes = [value.a, value.b, value.c].compactMap { $0 }.filter { !$0.isEmpty }
        return axes.isEmpty ? nil : axes.joined(separator: " x ") + " cm"
    }

    private static func lobeLabel(_ value: String) -> String {
        switch value {
        case "lobo_direito": return "lobo direito"
        case "lobo_esquerdo": return "lobo esquerdo"
        default: return "istmo"
        }
    }

    private static func mergeNodules(_ first: [ThyroidNodule]?, _ second: [ThyroidNodule]?) -> [ThyroidNodule]? {
        var result = first ?? []
        var keys = Set(result.map { "\($0.lobe)|\($0.c1 ?? "")|\($0.c2 ?? "")|\($0.c3 ?? "")|\($0.location ?? "")" })
        for nodule in second ?? [] {
            let key = "\(nodule.lobe)|\(nodule.c1 ?? "")|\(nodule.c2 ?? "")|\(nodule.c3 ?? "")|\(nodule.location ?? "")"
            if keys.insert(key).inserted { result.append(nodule) }
        }
        return result.isEmpty ? nil : result
    }

    private static func mergeBreastFindings(_ first: [ExtractedBreastFinding]?, _ second: [ExtractedBreastFinding]?) -> [ExtractedBreastFinding]? {
        var result = first ?? []
        var keys = Set(result.map { "\($0.side)|\($0.type)|\($0.c1 ?? "")|\($0.c2 ?? "")|\($0.c3 ?? "")|\($0.location ?? "")|\($0.hour ?? "")" })
        for finding in second ?? [] {
            let key = "\(finding.side)|\(finding.type)|\(finding.c1 ?? "")|\(finding.c2 ?? "")|\(finding.c3 ?? "")|\(finding.location ?? "")|\(finding.hour ?? "")"
            if keys.insert(key).inserted { result.append(finding) }
        }
        return result.isEmpty ? nil : result
    }

    private static func mergeCarotidMeasurements(_ first: [ExtractedCarotidMeasurement]?, _ second: [ExtractedCarotidMeasurement]?) -> [ExtractedCarotidMeasurement]? {
        var result = first ?? []
        var keys = Set(result.map { "\($0.side)|\($0.vessel)|\($0.psv ?? "")|\($0.vdf ?? "")|\($0.ir ?? "")|\($0.emi ?? "")|\($0.flowDirection ?? "")" })
        for item in second ?? [] {
            let key = "\(item.side)|\(item.vessel)|\(item.psv ?? "")|\(item.vdf ?? "")|\(item.ir ?? "")|\(item.emi ?? "")|\(item.flowDirection ?? "")"
            if keys.insert(key).inserted { result.append(item) }
        }
        return result.isEmpty ? nil : result
    }

    private static func mergeCarotidPlaques(_ first: [ExtractedCarotidPlaque]?, _ second: [ExtractedCarotidPlaque]?) -> [ExtractedCarotidPlaque]? {
        var result = first ?? []
        var keys = Set(result.map { "\($0.side)|\($0.location ?? "")|\($0.thickness ?? "")|\($0.stenosisPercent ?? "")" })
        for item in second ?? [] {
            let key = "\(item.side)|\(item.location ?? "")|\(item.thickness ?? "")|\(item.stenosisPercent ?? "")"
            if keys.insert(key).inserted { result.append(item) }
        }
        return result.isEmpty ? nil : result
    }

    private static func isEmpty(_ data: BiometricData) -> Bool {
        let category: ReportCategory = !(data.carotidMeasurements ?? []).isEmpty || !(data.carotidPlaques ?? []).isEmpty
            ? .dopplerCarotidas
            : !(data.breastFindings ?? []).isEmpty
            ? .mamaria
            : data.thyroidRightLobe != nil || data.thyroidLeftLobe != nil || data.thyroidIsthmus != nil || !(data.thyroidNodules ?? []).isEmpty
                ? .tireoide : .morfologico
        return format([data], category: category).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
