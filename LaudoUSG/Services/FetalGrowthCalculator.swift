import Foundation

/// Port literal do núcleo compartilhado TypeScript.
/// Fonte: Fetal Medicine Barcelona, "Fetal growth defects", novembro de 2024.
enum FetalGrowthCalculator {
    static let protocolVersion = "FMB-FETAL-GROWTH-DEFECTS-2024-11"
    static let protocolReference =
        "Classificação baseada no protocolo Fetal Growth Defects da Fetal Medicine Barcelona (versão publicada em novembro de 2024)."

    enum Classification: String, Sendable {
        case adequateForGestationalAge
        case smallForGestationalAge
        case fetalGrowthRestrictionStage1
        case fetalGrowthRestrictionStage2
        case fetalGrowthRestrictionStage3
        case fetalGrowthRestrictionStage4
        case smallFetusStagingIncomplete
    }

    struct RepeatedCriterion: Sendable, Hashable {
        let present: Bool
        let confirmed: Bool
    }

    enum EndDiastolicFlow: Sendable, Hashable {
        case present
        case absent
        case reversed
    }

    struct DuctusVenosusCriteria: Sendable, Hashable {
        var piAboveP95 = false
        var diastolicFlow: EndDiastolicFlow = .present
        var persistentDicroticVenousPulsations = false
        var confirmedAfter6To12Hours = false
    }

    struct Input: Sendable, Hashable {
        let efwPercentile: Double
        let efwPercentileSource: String
        var gestationalWeeks: Int?
        var gestationalDays: Int?
        var dopplerAssessmentCompleteAndNormal = false
        var cprBelowP5 = RepeatedCriterion(present: false, confirmed: false)
        var mcaPiBelowP5 = RepeatedCriterion(present: false, confirmed: false)
        var meanUterinePiAboveP95 = false
        var umbilicalArteryEndDiastolicFlow: EndDiastolicFlow = .present
        var umbilicalFlowConfirmedInRequiredInterval = false
        var ductusVenosus = DuctusVenosusCriteria()
        var pathologicalCtg = false
    }

    enum CriterionCode: String, Sendable, Hashable {
        case efwBelowP3
        case cprBelowP5
        case mcaPiBelowP5
        case meanUterinePiAboveP95
        case umbilicalAbsentEndDiastolicFlow
        case umbilicalReversedEndDiastolicFlow
        case ductusVenosusPiAboveP95
        case ductusVenosusAbsentDiastolicFlow
        case persistentDicroticVenousPulsations
        case pathologicalCtg
        case ductusVenosusReversedDiastolicFlow
    }

    struct CriterionResult: Sendable, Hashable {
        let stage: Int
        let code: CriterionCode
        let label: String
        let confirmed: Bool
        let confirmationRequirement: String?
    }

    struct Result: Sendable, Hashable {
        let classification: Classification
        let stage: Int?
        let confirmedCriteria: [CriterionResult]
        let pendingCriteria: [CriterionResult]
        let warnings: [String]
        let conclusion: String
        let reportReference: String
        let protocolVersion: String
        let efwPercentileSource: String
    }

    private static let twoAfter12Hours =
        "Confirmar em duas determinações com intervalo superior a 12 horas."
    private static let twoAfter6To12Hours =
        "Confirmar em duas determinações com intervalo superior a 6–12 horas."

    static func calculate(_ input: Input) -> Result? {
        guard input.efwPercentile.isFinite,
              (0...100).contains(input.efwPercentile),
              !input.efwPercentileSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        if let weeks = input.gestationalWeeks, !(4...44).contains(weeks) { return nil }
        if let days = input.gestationalDays, !(0...6).contains(days) { return nil }

        var confirmed: [CriterionResult] = []
        var pending: [CriterionResult] = []
        var warnings: [String] = []
        let efwBelowP10 = input.efwPercentile < 10

        func append(_ item: CriterionResult) {
            if item.confirmed { confirmed.append(item) } else { pending.append(item) }
        }
        func item(
            stage: Int,
            code: CriterionCode,
            label: String,
            confirmed: Bool,
            requirement: String? = nil
        ) -> CriterionResult {
            CriterionResult(
                stage: stage,
                code: code,
                label: label,
                confirmed: confirmed,
                confirmationRequirement: requirement
            )
        }

        if input.efwPercentile < 3 {
            append(item(stage: 1, code: .efwBelowP3, label: "PFE abaixo do percentil 3", confirmed: true))
        }

        if efwBelowP10 {
            if input.cprBelowP5.present {
                append(item(stage: 1, code: .cprBelowP5, label: "RCP abaixo do percentil 5", confirmed: input.cprBelowP5.confirmed, requirement: twoAfter12Hours))
            }
            if input.mcaPiBelowP5.present {
                append(item(stage: 1, code: .mcaPiBelowP5, label: "IP da artéria cerebral média abaixo do percentil 5", confirmed: input.mcaPiBelowP5.confirmed, requirement: twoAfter12Hours))
            }
            if input.meanUterinePiAboveP95 {
                append(item(stage: 1, code: .meanUterinePiAboveP95, label: "IP médio das artérias uterinas acima do percentil 95", confirmed: true))
            }
            if input.umbilicalArteryEndDiastolicFlow == .absent {
                append(item(stage: 2, code: .umbilicalAbsentEndDiastolicFlow, label: "fluxo diastólico ausente na artéria umbilical", confirmed: input.umbilicalFlowConfirmedInRequiredInterval, requirement: twoAfter12Hours))
            }
            if input.umbilicalArteryEndDiastolicFlow == .reversed {
                append(item(stage: 3, code: .umbilicalReversedEndDiastolicFlow, label: "fluxo diastólico reverso na artéria umbilical", confirmed: input.umbilicalFlowConfirmedInRequiredInterval, requirement: twoAfter6To12Hours))
            }
            if input.ductusVenosus.piAboveP95 {
                append(item(stage: 3, code: .ductusVenosusPiAboveP95, label: "IP do ducto venoso acima do percentil 95", confirmed: input.ductusVenosus.confirmedAfter6To12Hours, requirement: twoAfter6To12Hours))
            }
            if input.ductusVenosus.diastolicFlow == .absent {
                append(item(stage: 3, code: .ductusVenosusAbsentDiastolicFlow, label: "fluxo diastólico ausente no ducto venoso", confirmed: input.ductusVenosus.confirmedAfter6To12Hours, requirement: twoAfter6To12Hours))
            }
            if input.ductusVenosus.persistentDicroticVenousPulsations {
                append(item(stage: 3, code: .persistentDicroticVenousPulsations, label: "pulsações venosas dicróticas persistentes", confirmed: input.ductusVenosus.confirmedAfter6To12Hours, requirement: twoAfter6To12Hours))
            }
            if input.pathologicalCtg {
                append(item(stage: 4, code: .pathologicalCtg, label: "traçado cardiotocográfico patológico", confirmed: true))
            }
            if input.ductusVenosus.diastolicFlow == .reversed {
                append(item(stage: 4, code: .ductusVenosusReversedDiastolicFlow, label: "fluxo diastólico reverso no ducto venoso", confirmed: input.ductusVenosus.confirmedAfter6To12Hours, requirement: twoAfter6To12Hours))
            }
        } else if hasAbnormalVitality(input) {
            warnings.append("Há alteração de vitalidade/Doppler, mas PFE igual ou acima do percentil 10 não preenche a definição de RCF deste protocolo. O achado deve ser descrito separadamente.")
        }

        if let weeks = input.gestationalWeeks,
           weeks * 7 + (input.gestationalDays ?? 0) < 24 * 7,
           efwBelowP10 {
            warnings.append("Diagnóstico antes de 24 semanas baseado somente na biometria deve ser confirmado com 24 semanas.")
        }

        let highestConfirmed = confirmed.map(\.stage).max()
        let highestPending = pending.map(\.stage).max()
        if let confirmedStage = highestConfirmed,
           let pendingStage = highestPending,
           pendingStage > confirmedStage {
            warnings.append("Há critério de estágio \(pendingStage) ainda pendente da repetição exigida; mantém-se o maior estágio confirmado.")
        }

        let classification: Classification
        let stage: Int?
        let conclusion: String
        if let confirmedStage = highestConfirmed {
            stage = confirmedStage
            classification = classificationForStage(confirmedStage)
            conclusion = "Restrição do crescimento fetal, estágio \(roman(confirmedStage)) pela classificação de Gratacós."
        } else if input.efwPercentile >= 10 {
            stage = nil
            classification = .adequateForGestationalAge
            conclusion = "Peso fetal adequado para a idade gestacional pela curva informada."
        } else if !pending.isEmpty || !input.dopplerAssessmentCompleteAndNormal {
            stage = nil
            classification = .smallFetusStagingIncomplete
            conclusion = "Peso fetal abaixo do percentil 10; classificação entre PIG e RCF ainda incompleta."
        } else {
            stage = nil
            classification = .smallForGestationalAge
            conclusion = "Feto pequeno para a idade gestacional, com Doppler dentro da normalidade."
        }

        return Result(
            classification: classification,
            stage: stage,
            confirmedCriteria: confirmed,
            pendingCriteria: pending,
            warnings: warnings,
            conclusion: conclusion,
            reportReference: protocolReference,
            protocolVersion: protocolVersion,
            efwPercentileSource: input.efwPercentileSource
        )
    }

    static func insertBlock(from result: Result) -> String {
        (["CRESCIMENTO FETAL:", result.conclusion]
         + result.pendingCriteria.map { item in
             "\(item.label): achado no exame atual; \(item.confirmationRequirement ?? "confirmação pendente")"
         }
         + result.warnings
         + [result.reportReference, "Curva informada para o percentil do peso: \(result.efwPercentileSource)."])
            .joined(separator: "\n")
    }

    private static func hasAbnormalVitality(_ input: Input) -> Bool {
        input.cprBelowP5.present || input.mcaPiBelowP5.present ||
        input.meanUterinePiAboveP95 ||
        input.umbilicalArteryEndDiastolicFlow != .present ||
        input.ductusVenosus.piAboveP95 ||
        input.ductusVenosus.diastolicFlow != .present ||
        input.ductusVenosus.persistentDicroticVenousPulsations ||
        input.pathologicalCtg
    }

    private static func classificationForStage(_ stage: Int) -> Classification {
        switch stage {
        case 4: return .fetalGrowthRestrictionStage4
        case 3: return .fetalGrowthRestrictionStage3
        case 2: return .fetalGrowthRestrictionStage2
        default: return .fetalGrowthRestrictionStage1
        }
    }

    private static func roman(_ stage: Int) -> String {
        [1: "I", 2: "II", 3: "III", 4: "IV"][stage] ?? "I"
    }
}
