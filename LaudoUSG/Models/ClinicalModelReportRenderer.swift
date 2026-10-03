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

    /// Igual a `sentence()` do shared: texto livre vira uma frase com um único
    /// ponto final (remove `.;,:` e espaços do fim antes de pontuar).
    static func sentence(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = value.unicodeScalars.last,
              ".;,:".unicodeScalars.contains(last) || CharacterSet.whitespacesAndNewlines.contains(last) {
            value.unicodeScalars.removeLast()
        }
        return value + "."
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
            lines.append(sentence(evidence))
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
        case (.suspected, _):
            conclusion = "Achados suspeitos de alteração do sistema portal, conforme descritos acima."
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
        let phase: [DopplerVenosoMmssDraft.ThrombosisPhase: String] = [
            .acute: "aguda", .subacute: "subaguda", .chronic: "crônica", .indeterminate: "indeterminada",
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
                lines.append("Cateter no segmento \(value.catheter.segment ?? ""), com relação \(relation).")
            }
            if value.hasThrombosis, let label = phase[value.thrombosisPhase] {
                lines.append("Aspecto temporal da trombose: \(label).")
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

        let blocks = [block(.right, data.right), block(.left, data.left)].compactMap { $0 }
        return "DOPPLER VENOSO DE MEMBRO SUPERIOR\n\nCOMENTÁRIOS:\nExame realizado com transdutor linear de alta frequência, análise espectral, Doppler colorido e manobras de compressão seriada. Indicação: \(indication[data.indication]!).\n\nOS SEGUINTES ASPECTOS FORAM OBSERVADOS:\n\(blocks.map(\.0).joined(separator: "\n\n"))\n\nCONCLUSÃO:\n\(blocks.map(\.1).joined(separator: "\n"))"
    }

    private static func renderArterial(_ data: DopplerArterialMmssDraft) -> String {
        let statusLabel: [DopplerArterialMmssDraft.ArterialStatus: String] = [
            .stenosis: "Estenose", .occlusion: "Oclusão", .other: "Outra alteração",
        ]
        let outletLabel: [DopplerArterialMmssDraft.OutletResult: String] = [
            .negative: "negativo", .positive: "positivo", .indeterminate: "indeterminado",
        ]

        func block(_ laterality: ExamLaterality, _ value: DopplerArterialMmssDraft.Side) -> (String, String)? {
            guard value.examined else { return nil }
            let vessel = value.affectedVessel ?? ""
            var lines = [
                "Membro superior \(sideName(laterality)):",
                value.status == .normal
                    ? "Artérias avaliadas pérvias, com padrão espectral preservado."
                    : "\(statusLabel[value.status]!) em \(vessel).",
            ]
            // O envio usa chaves ordenadas; o servidor percorre o objeto na
            // mesma ordem, então a prévia lista as VPS igual ao texto final.
            lines += value.psvCms.sorted(by: { $0.key < $1.key }).map {
                "\($0.key): velocidade de pico sistólico de \(pt($0.value)) cm/s."
            }
            if let percent = value.stenosisPercent { lines.append("Estenose estimada em \(pt(percent))%.") }
            if let distal = value.distalPattern, !distal.isEmpty { lines.append("Padrão distal: \(sentence(distal))") }
            let outlet = value.thoracicOutlet
            if outlet.evaluated, let result = outlet.result {
                lines.append("Desfiladeiro torácico: manobras \(outlet.maneuvers ?? ""); posições \(outlet.positions ?? ""); resultado \(outletLabel[result]!).")
            }

            var conclusion: String
            switch value.status {
            case .normal:
                conclusion = "Estudo arterial do membro superior \(sideName(laterality)) sem alterações hemodinâmicas significativas."
            case .stenosis:
                let percent = value.stenosisPercent.map { ", estimada em \(pt($0))%" } ?? ""
                conclusion = "Estenose de \(vessel)\(percent), no membro superior \(sideName(laterality))."
            case .occlusion:
                conclusion = "Oclusão de \(vessel) no membro superior \(sideName(laterality))."
            case .other:
                conclusion = "Alteração de \(vessel) no membro superior \(sideName(laterality)), conforme descrita acima."
            }
            if outlet.evaluated {
                switch outlet.result {
                case .positive: conclusion += " Manobras posicionais positivas para compressão arterial no desfiladeiro torácico."
                case .negative: conclusion += " Manobras posicionais negativas para compressão arterial no desfiladeiro torácico."
                default: conclusion += " Avaliação do desfiladeiro torácico com resultado indeterminado."
                }
            }
            return (lines.joined(separator: "\n"), conclusion)
        }

        let blocks = [block(.right, data.right), block(.left, data.left)].compactMap { $0 }
        return "DOPPLER ARTERIAL DE MEMBRO SUPERIOR\n\nCOMENTÁRIOS:\nExame realizado com transdutor linear de alta frequência, análise espectral e mapeamento com Doppler colorido.\n\nOS SEGUINTES ASPECTOS FORAM OBSERVADOS:\n\(blocks.map(\.0).joined(separator: "\n\n"))\n\nCONCLUSÃO:\n\(blocks.map(\.1).joined(separator: "\n"))"
    }

    private static func renderThorax(_ data: ThoraxDraft) -> String {
        let pleuralLabel: [ThoraxDraft.PleuralLine: String] = [.regular: "regular", .irregular: "irregular", .notAssessed: "não avaliada"]
        let slidingLabel: [ThoraxDraft.Sliding: String] = [.present: "presente", .absent: "ausente", .notAssessed: "não avaliado"]
        let distributionLabel: [ThoraxDraft.BLineDistribution: String] = [.none: "ausente", .focal: "focal", .multifocal: "multifocal", .diffuse: "difusa"]
        // Mesmos rótulos do shared, inclusive a concordância de "pneumotórax"
        // (ver relatório de paridade); a prévia precisa ser idêntica ao servidor.
        let findingLabel: [ThoraxDraft.FindingStatus: String] = [.notSeen: "não identificada", .suspected: "suspeita", .confirmed: "confirmada"]

        func side(_ laterality: ExamLaterality, _ value: ThoraxDraft.Side) -> String {
            let effusion: String
            if value.effusion.present, let separation = value.effusion.separationMm {
                effusion = value.effusion.estimatedVolumeMl.map {
                    "Derrame pleural com separação máxima de \(pt(separation)) mm e volume estimado de \(pt($0)) mL pelo método de Balik."
                } ?? "Derrame pleural com separação máxima de \(pt(separation)) mm; volume não calculado fora do domínio validado do método de Balik."
            } else {
                effusion = "Não se identifica derrame pleural."
            }
            return [
                "Hemitórax \(sideName(laterality)):",
                "Linha pleural \(pleuralLabel[value.pleuralLine]!); deslizamento pleural \(slidingLabel[value.sliding]!).",
                value.linesB.count > 0
                    ? "\(value.linesB.count) linhas B, com distribuição \(distributionLabel[value.linesB.distribution]!)."
                    : "Não foram registradas linhas B.",
                effusion,
                "Consolidação \(findingLabel[value.consolidation]!). Atelectasia \(findingLabel[value.atelectasis]!). Sinais de pneumotórax: \(findingLabel[value.pneumothorax]!).",
            ].joined(separator: "\n")
        }

        func conclusion(_ laterality: ExamLaterality, _ value: ThoraxDraft.Side) -> String {
            var findings: [String] = []
            if value.pleuralLine == .irregular { findings.append("irregularidade da linha pleural") }
            if value.sliding == .absent { findings.append("ausência de deslizamento pleural") }
            if value.effusion.present, let separation = value.effusion.separationMm {
                findings.append(value.effusion.estimatedVolumeMl.map {
                    "derrame pleural estimado em \(pt($0)) mL"
                } ?? "derrame pleural com separação máxima de \(pt(separation)) mm, sem estimativa volumétrica")
            }
            if value.linesB.count > 0 {
                findings.append("\(value.linesB.count) linhas B de distribuição \(distributionLabel[value.linesB.distribution]!)")
            }
            if value.consolidation != .notSeen { findings.append("consolidação \(findingLabel[value.consolidation]!)") }
            if value.atelectasis != .notSeen { findings.append("atelectasia \(findingLabel[value.atelectasis]!)") }
            if value.pneumothorax != .notSeen { findings.append("pneumotórax \(findingLabel[value.pneumothorax]!)") }
            if !findings.isEmpty { return "Hemitórax \(sideName(laterality)): \(findings.joined(separator: ", "))." }
            if value.pleuralLine == .notAssessed || value.sliding == .notAssessed {
                return "Hemitórax \(sideName(laterality)) com avaliação pleural incompleta."
            }
            return "Hemitórax \(sideName(laterality)) sem alterações ecográficas significativas."
        }

        let method = [data.right, data.left].contains { $0.effusion.estimatedVolumeMl != nil }
            ? "\n\nNOTA DA ESTIMATIVA:\n\(BalikPleuralEffusionMethod.formula); \(BalikPleuralEffusionMethod.population); \(BalikPleuralEffusionMethod.measurement). DOI \(BalikPleuralEffusionMethod.doi). Erro absoluto médio aproximado de \(BalikPleuralEffusionMethod.meanAbsoluteErrorMl) mL; a estimativa não determina conduta automaticamente."
            : ""
        let limitation = data.limitation.flatMap { $0.isEmpty ? nil : "\nLimitação: \(sentence($0))" } ?? ""
        let correlation = data.correlationSuggested ? "\nSugere-se correlação clínica." : ""
        // A quebra extra após o hemitórax esquerdo replica o template do shared.
        return "ULTRASSONOGRAFIA DE TÓRAX\n\nCOMENTÁRIOS:\nExame realizado com transdutores convexo e linear, com avaliação bilateral das regiões anterior, lateral e posterior do tórax.\n\nOS SEGUINTES ASPECTOS FORAM OBSERVADOS:\n\(side(.right, data.right))\n\n\(side(.left, data.left))\n\(limitation)\(method)\n\nCONCLUSÃO:\n\(conclusion(.right, data.right))\n\(conclusion(.left, data.left))\(correlation)"
    }

    private static func renderHip(_ data: QuadrilInfantilDraft) -> String {
        let roofLabel: [QuadrilInfantilDraft.BonyRoof: String] = [.normal: "bem formado", .rounded: "arredondado", .deficient: "deficiente", .notAssessed: "não avaliado"]
        let cartilageLabel: [QuadrilInfantilDraft.CartilaginousRoof: String] = [.normal: "preservado", .displaced: "deslocado", .notAssessed: "não avaliado"]
        let headLabel: [QuadrilInfantilDraft.FemoralHead: String] = [.centered: "centrada", .decentered: "descentrada", .dislocated: "luxada", .notAssessed: "não avaliada"]
        let labrumLabel: [QuadrilInfantilDraft.LabrumPosition: String] = [.normal: "em posição habitual", .everted: "evertido", .interposed: "interposto", .notAssessed: "não avaliado"]

        func block(_ laterality: ExamLaterality, _ value: QuadrilInfantilDraft.Side) -> String {
            guard value.adequateStandardPlane else {
                return "Quadril \(sideName(laterality)): corte padrão inadequado; classificação não emitida."
            }
            let coverage = value.coveragePercent.map { " e cobertura de \(pt($0))%" } ?? ""
            return "Quadril \(sideName(laterality)): teto ósseo \(roofLabel[value.bonyRoof]!), teto cartilaginoso \(cartilageLabel[value.cartilaginousRoof]!), cabeça femoral \(headLabel[value.femoralHead]!), labrum \(labrumLabel[value.labrumPosition]!), ângulo alfa de \(pt(value.alphaDeg ?? 0))°, ângulo beta de \(pt(value.betaDeg ?? 0))°\(coverage). Classificação de Graf \(value.grafClassification?.rawValue ?? "")."
        }
        let recommendation = data.recommendation.flatMap { $0.isEmpty ? nil : "\n\($0)" } ?? ""
        return "ULTRASSONOGRAFIA DOS QUADRIS DO LACTENTE\n\nCOMENTÁRIOS:\nExame realizado com transdutor linear de alta frequência, utilizando cortes coronais padronizados segundo a técnica de Graf. Idade: \(data.ageDays ?? 0) dias.\n\nOS SEGUINTES ASPECTOS FORAM OBSERVADOS:\n\(block(.right, data.right))\n\(block(.left, data.left))\n\nCONCLUSÃO:\nQuadril direito classificado como Graf \(data.right.grafClassification?.rawValue ?? "").\nQuadril esquerdo classificado como Graf \(data.left.grafClassification?.rawValue ?? "").\(recommendation)"
    }
}
