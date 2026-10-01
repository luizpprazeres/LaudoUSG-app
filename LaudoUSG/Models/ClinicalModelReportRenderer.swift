import Foundation

enum ClinicalModelReportRenderer {
    private static let formatter: NumberFormatter = {
        let value = NumberFormatter()
        value.locale = Locale(identifier: "pt_BR")
        value.maximumFractionDigits = 2
        value.minimumFractionDigits = 0
        return value
    }()

    private static func pt(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func sideName(_ side: ExamLaterality) -> String {
        side == .right ? "direito" : "esquerdo"
    }

    static func render(_ draft: ClinicalModelDraft) throws -> String {
        let errors = draft.previewIssues.filter { $0.severity == .error }
        guard errors.isEmpty else {
            throw ClinicalModelWorkflowError.validation(errors)
        }
        switch draft {
        case .abdomen(let value): return renderAbdomen(value)
        case .venous(let value): return renderVenous(value)
        case .arterial(let value): return renderArterial(value)
        case .thorax(let value): return renderThorax(value)
        case .hip(let value): return renderHip(value)
        }
    }

    private static func renderAbdomen(_ data: AbdomenTotalDopplerDraft) -> String {
        func vessel(
            _ label: String,
            caliber: Double?,
            velocity: Double?,
            flow: AbdomenTotalDopplerDraft.FlowDirection?
        ) -> String {
            let flowText: [AbdomenTotalDopplerDraft.FlowDirection: String] = [
                .hepatopetal: "hepatopetal",
                .hepatofugal: "hepatofugal",
                .absent: "ausente",
                .other: "com padrão descrito pelo médico",
            ]
            return "\(label) com calibre de \(pt(caliber!)) cm, velocidade de \(pt(velocity!)) cm/s e fluxo \(flowText[flow!]!)."
        }

        var lines = [
            vessel(
                "Tronco da veia porta",
                caliber: data.portalVein.caliberCm,
                velocity: data.portalVein.velocityCms,
                flow: data.portalVein.flow
            ),
        ]
        let optionals: [(String, AbdomenTotalDopplerDraft.OptionalVessel)] = [
            ("Veias hepáticas", data.hepaticVeins),
            ("Veia esplênica", data.splenicVein),
            ("Veia mesentérica superior", data.superiorMesentericVein),
            ("Artéria hepática comum", data.commonHepaticArtery),
        ]
        lines += optionals.compactMap { label, value in
            value.evaluated
                ? vessel(label, caliber: value.caliberCm, velocity: value.velocityCms, flow: value.flow)
                : nil
        }
        if data.portalPathology.status != .absent, let evidence = data.portalPathology.evidence {
            lines.append("\(evidence).")
        }

        let prefix = data.portalPathology.status == .suspected
            ? "Achados suspeitos de"
            : "Sinais ultrassonográficos de"
        let conclusion: String
        switch (data.portalPathology.status, data.portalPathology.kind) {
        case (.absent, _):
            conclusion = "Estudo Doppler do sistema esplâncnico sem alterações nos parâmetros informados."
        case (_, .portalThrombosis):
            conclusion = "\(prefix) trombose portal."
        case (_, .portalHypertension):
            conclusion = "\(prefix) hipertensão portal."
        default:
            conclusion = "Alteração do sistema portal, conforme descrita acima."
        }
        let photo = data.documentationPhoto == .include
            ? " A documentação fotográfica foi realizada conforme a preferência configurada."
            : ""

        return """
        ULTRASSONOGRAFIA DO ABDOME TOTAL COM DOPPLER COLORIDO

        COMENTÁRIOS:
        Exame realizado com transdutor convexo multifrequencial, abrangendo todo o abdome. Foram realizados múltiplos cortes em planos ortogonais.\(photo)

        OS SEGUINTES ASPECTOS FORAM OBSERVADOS:
        \(data.abdomenReport)

        DOPPLER DO SISTEMA ESPLÂNCNICO:
        \(lines.joined(separator: "\n"))

        CONCLUSÃO:
        \(conclusion)
        """
    }

    private static func renderVenous(_ data: DopplerVenosoMmssDraft) -> String {
        let indication: [DopplerVenosoMmssDraft.Indication: String] = [
            .elective: "avaliação eletiva",
            .thrombosisResearch: "pesquisa de trombose",
            .catheter: "avaliação relacionada a cateter",
        ]

        func block(_ laterality: ExamLaterality, _ value: DopplerVenosoMmssDraft.Side) -> (String, String)? {
            guard value.examined else { return nil }
            func system(_ status: DopplerVenosoMmssDraft.SystemStatus) -> String {
                switch status {
                case .patent: "pérvio nos segmentos avaliados"
                case .thrombosis: "com sinais de trombose"
                case .notAssessed: "não avaliado por completo"
                }
            }
            var lines = [
                "Membro superior \(sideName(laterality)):",
                "Sistema venoso profundo \(system(value.deepSystem)).",
                "Sistema venoso superficial \(system(value.superficialSystem)).",
            ]
            if value.internalJugular != .notAssessed {
                lines.append("Veia jugular interna \(value.internalJugular == .patent ? "pérvia" : "com sinais de trombose").")
            }
            if value.competenceTested {
                lines.append("Pesquisa de refluxo \(value.reflux == .present ? "positiva" : "negativa").")
            }
            if value.catheter.present {
                let relation: String
                switch value.catheter.relation {
                case .adjacent: relation = "adjacente"
                case .aroundCatheter: relation = "ao redor do cateter"
                case .occlusive: relation = "oclusiva"
                default: relation = "não informada"
                }
                lines.append("Cateter no segmento \(value.catheter.segment!), com relação \(relation).")
            }
            let territories = [
                value.deepSystem == .thrombosis ? "sistema venoso profundo" : nil,
                value.superficialSystem == .thrombosis ? "sistema venoso superficial" : nil,
                value.internalJugular == .thrombosis ? "veia jugular interna" : nil,
            ].compactMap { $0 }
            var conclusion = territories.isEmpty
                ? "Não se identificam sinais de trombose nos segmentos venosos avaliados do membro superior \(sideName(laterality))."
                : "Trombose no \(territories.joined(separator: " e ")) do membro superior \(sideName(laterality))."
            if value.competenceTested && value.reflux == .present {
                conclusion += " Refluxo venoso detectado."
            }
            return (lines.joined(separator: "\n"), conclusion)
        }

        let blocks = [
            block(.right, data.right),
            block(.left, data.left),
        ].compactMap { $0 }

        return """
        DOPPLER VENOSO DE MEMBRO SUPERIOR

        COMENTÁRIOS:
        Exame realizado com transdutor linear de alta frequência, análise espectral, Doppler colorido e manobras de compressão seriada. Indicação: \(indication[data.indication]!).

        OS SEGUINTES ASPECTOS FORAM OBSERVADOS:
        \(blocks.map(\.0).joined(separator: "\n\n"))

        CONCLUSÃO:
        \(blocks.map(\.1).joined(separator: "\n"))
        """
    }

    private static func renderArterial(_ data: DopplerArterialMmssDraft) -> String {
        func block(_ laterality: ExamLaterality, _ value: DopplerArterialMmssDraft.Side) -> (String, String)? {
            guard value.examined else { return nil }
            let statusLine: String
            switch value.status {
            case .normal: statusLine = "Artérias avaliadas pérvias, com padrão espectral preservado."
            case .stenosis: statusLine = "Estenose em \(value.affectedVessel!)."
            case .occlusion: statusLine = "Oclusão em \(value.affectedVessel!)."
            case .other: statusLine = "Outra alteração em \(value.affectedVessel!)."
            }
            var lines = ["Membro superior \(sideName(laterality)):", statusLine]
            lines += value.psvCms.sorted(by: { $0.key < $1.key }).map {
                "\($0.key): velocidade de pico sistólico de \(pt($0.value)) cm/s."
            }
            if let percent = value.stenosisPercent {
                lines.append("Estenose estimada em \(pt(percent))%.")
            }
            if let distal = value.distalPattern {
                lines.append("Padrão distal: \(distal).")
            }
            if value.thoracicOutlet.evaluated {
                let result = value.thoracicOutlet.result == .positive
                    ? "positivo"
                    : value.thoracicOutlet.result == .negative ? "negativo" : "indeterminado"
                lines.append("Desfiladeiro torácico: manobras \(value.thoracicOutlet.maneuvers!); posições \(value.thoracicOutlet.positions!); resultado \(result).")
            }

            var conclusion: String
            switch value.status {
            case .normal:
                conclusion = "Estudo arterial do membro superior \(sideName(laterality)) sem alterações hemodinâmicas significativas."
            case .stenosis:
                let percent = value.stenosisPercent.map { ", estimada em \(pt($0))%" } ?? ""
                conclusion = "Estenose de \(value.affectedVessel!)\(percent), no membro superior \(sideName(laterality))."
            case .occlusion:
                conclusion = "Oclusão de \(value.affectedVessel!) no membro superior \(sideName(laterality))."
            case .other:
                conclusion = "Alteração de \(value.affectedVessel!) no membro superior \(sideName(laterality)), conforme descrita acima."
            }
            if value.thoracicOutlet.evaluated {
                let result = value.thoracicOutlet.result == .positive
                    ? "positivo"
                    : value.thoracicOutlet.result == .negative ? "negativo" : "indeterminado"
                conclusion += " Avaliação do desfiladeiro torácico com resultado \(result)."
            }
            return (lines.joined(separator: "\n"), conclusion)
        }

        let blocks = [
            block(.right, data.right),
            block(.left, data.left),
        ].compactMap { $0 }

        return """
        DOPPLER ARTERIAL DE MEMBRO SUPERIOR

        COMENTÁRIOS:
        Exame realizado com transdutor linear de alta frequência, análise espectral e mapeamento com Doppler colorido.

        OS SEGUINTES ASPECTOS FORAM OBSERVADOS:
        \(blocks.map(\.0).joined(separator: "\n\n"))

        CONCLUSÃO:
        \(blocks.map(\.1).joined(separator: "\n"))
        """
    }

    private static func renderThorax(_ data: ThoraxDraft) -> String {
        func block(_ laterality: ExamLaterality, _ value: ThoraxDraft.Side) -> (String, String) {
            let pleural = value.pleuralLine == .regular
                ? "regular" : value.pleuralLine == .irregular ? "irregular" : "não avaliada"
            let sliding = value.sliding == .present
                ? "presente" : value.sliding == .absent ? "ausente" : "não avaliado"
            let distribution: [ThoraxDraft.BLineDistribution: String] = [
                .none: "ausente", .focal: "focal", .multifocal: "multifocal", .diffuse: "difusa",
            ]
            var lines = [
                "Hemitórax \(sideName(laterality)):",
                "Linha pleural \(pleural); deslizamento pleural \(sliding).",
                value.linesB.count == 0
                    ? "Não foram registradas linhas B."
                    : "\(value.linesB.count) linhas B, com distribuição \(distribution[value.linesB.distribution]!).",
            ]
            if value.effusion.present, let separation = value.effusion.separationMm {
                lines.append(value.effusion.estimatedVolumeMl.map {
                    "Derrame pleural com separação máxima de \(pt(separation)) mm e volume estimado de \(pt($0)) mL pelo método de Balik."
                } ?? "Derrame pleural com separação máxima de \(pt(separation)) mm; volume não calculado fora do domínio validado do método de Balik.")
            } else {
                lines.append("Não se identifica derrame pleural.")
            }

            var findings: [String] = []
            if value.pleuralLine == .irregular { findings.append("irregularidade da linha pleural") }
            if value.sliding == .absent { findings.append("ausência de deslizamento pleural") }
            if value.effusion.present {
                findings.append(value.effusion.estimatedVolumeMl.map {
                    "derrame pleural estimado em \(pt($0)) mL"
                } ?? "derrame pleural sem estimativa volumétrica")
            }
            if value.linesB.count > 0 { findings.append("\(value.linesB.count) linhas B") }
            if value.consolidation != .notSeen {
                findings.append("consolidação \(value.consolidation == .confirmed ? "confirmada" : "suspeita")")
            }
            if value.atelectasis != .notSeen {
                findings.append("atelectasia \(value.atelectasis == .confirmed ? "confirmada" : "suspeita")")
            }
            if value.pneumothorax != .notSeen {
                findings.append("pneumotórax \(value.pneumothorax == .confirmed ? "confirmado" : "suspeito")")
            }

            let conclusion: String
            if !findings.isEmpty {
                conclusion = "Hemitórax \(sideName(laterality)): \(findings.joined(separator: ", "))."
            } else if value.pleuralLine == .notAssessed || value.sliding == .notAssessed {
                conclusion = "Hemitórax \(sideName(laterality)) com avaliação pleural incompleta."
            } else {
                conclusion = "Hemitórax \(sideName(laterality)) sem alterações ecográficas significativas."
            }
            return (lines.joined(separator: "\n"), conclusion)
        }

        let blocks = [block(.right, data.right), block(.left, data.left)]
        let method = [data.right, data.left].contains { $0.effusion.estimatedVolumeMl != nil }
            ? "\n\nNOTA DA ESTIMATIVA:\n\(BalikPleuralEffusionMethod.formula); \(BalikPleuralEffusionMethod.population); \(BalikPleuralEffusionMethod.measurement). DOI \(BalikPleuralEffusionMethod.doi). Erro absoluto médio aproximado de \(BalikPleuralEffusionMethod.meanAbsoluteErrorMl) mL; a estimativa não determina conduta automaticamente."
            : ""
        let limitation = data.limitation.map { "\nLimitação: \($0)." } ?? ""
        let correlation = data.correlationSuggested ? "\nSugere-se correlação clínica." : ""

        return """
        ULTRASSONOGRAFIA DE TÓRAX

        COMENTÁRIOS:
        Exame realizado com transdutores convexo e linear, com avaliação bilateral das regiões anterior, lateral e posterior do tórax.

        OS SEGUINTES ASPECTOS FORAM OBSERVADOS:
        \(blocks.map(\.0).joined(separator: "\n\n"))\(limitation)\(method)

        CONCLUSÃO:
        \(blocks.map(\.1).joined(separator: "\n"))\(correlation)
        """
    }

    private static func renderHip(_ data: QuadrilInfantilDraft) -> String {
        func block(_ laterality: ExamLaterality, _ value: QuadrilInfantilDraft.Side) -> String {
            guard value.adequateStandardPlane else {
                return "Quadril \(sideName(laterality)): corte padrão inadequado; classificação não emitida."
            }
            let coverage = value.coveragePercent.map { " e cobertura de \(pt($0))%" } ?? ""
            return "Quadril \(sideName(laterality)): ângulo alfa de \(pt(value.alphaDeg!))°, ângulo beta de \(pt(value.betaDeg!))°\(coverage). Classificação de Graf \(value.grafClassification!.rawValue)."
        }
        let recommendation = data.recommendation.map { "\n\($0)" } ?? ""

        return """
        ULTRASSONOGRAFIA DOS QUADRIS DO LACTENTE

        COMENTÁRIOS:
        Exame realizado com transdutor linear de alta frequência, utilizando cortes coronais padronizados segundo a técnica de Graf. Idade: \(data.ageDays!) dias.

        OS SEGUINTES ASPECTOS FORAM OBSERVADOS:
        \(block(.right, data.right))
        \(block(.left, data.left))

        CONCLUSÃO:
        Quadril direito classificado como Graf \(data.right.grafClassification!.rawValue).
        Quadril esquerdo classificado como Graf \(data.left.grafClassification!.rawValue).\(recommendation)
        """
    }
}
