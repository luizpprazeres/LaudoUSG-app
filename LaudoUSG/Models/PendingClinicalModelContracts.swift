import Foundation

/// Espelho Swift do contrato `clinicalModels/v1` compartilhado por Web e
/// Android. Os cinco modelos ficam compilados e testados, mas continuam fora de
/// `ReportCategory.selectable` até o gate de ativação simultânea.
enum PendingClinicalModelContracts {
    static let schemaVersion = 1
    static let categories: Set<ReportCategory> = [
        .abdomenTotalDoppler,
        .dopplerVenosoMmss,
        .dopplerArterialMmss,
        .torax,
        .quadrilInfantil,
    ]

    /// Gate de liberação conjunta (Web, iOS, Android e `RENDERER_CATEGORIES`
    /// do backend). Em Release fica sempre OFF. Em Debug, só abre com
    /// `-ClinicalModelsV1Preview YES` nos argumentos do scheme, para QA local;
    /// o servidor continua respondendo 404 enquanto o gate dele estiver OFF.
    static var isRolloutEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "ClinicalModelsV1Preview")
        #else
        false
        #endif
    }
}

struct ClinicalContractIssue: Codable, Equatable, Sendable {
    enum Severity: String, Codable, Sendable { case error, warning }
    let code: String
    let severity: Severity
    let field: String
    let message: String

    init(_ code: String, field: String, message: String, severity: Severity = .error) {
        self.code = code
        self.severity = severity
        self.field = field
        self.message = message
    }

    private enum CodingKeys: String, CodingKey { case code, severity, field, path, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        severity = try container.decode(Severity.self, forKey: .severity)
        field = try container.decodeIfPresent(String.self, forKey: .field)
            ?? container.decode(String.self, forKey: .path)
        message = try container.decode(String.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(severity, forKey: .severity)
        try container.encode(field, forKey: .field)
        try container.encode(message, forKey: .message)
    }
}

private func physicianReviewIssues(_ reviewed: Bool) -> [ClinicalContractIssue] {
    reviewed ? [] : [
        .init("MODEL_NOT_REVIEWED", field: "physicianReviewed", message: "Revise todos os achados e confirme o modelo antes de liberar o laudo."),
    ]
}

enum ExamLaterality: String, Codable, Sendable { case right, left, bilateral }

// MARK: - Abdome total com Doppler

struct AbdomenTotalDopplerDraft: Codable, Equatable, Sendable {
    enum DocumentationPhoto: String, Codable, Sendable { case include, omit }
    enum FlowDirection: String, Codable, Sendable { case hepatopetal, hepatofugal, absent = "ausente", other = "outro" }
    enum PortalStatus: String, Codable, Sendable { case absent, suspected, confirmed }
    enum PortalPathologyKind: String, Codable, Sendable { case portalHypertension = "portal_hypertension", portalThrombosis = "portal_thrombosis", other }

    struct RequiredVessel: Codable, Equatable, Sendable {
        var caliberCm: Double?
        var velocityCms: Double?
        var flow: FlowDirection?
    }

    struct OptionalVessel: Codable, Equatable, Sendable {
        var evaluated: Bool
        var caliberCm: Double?
        var velocityCms: Double?
        var flow: FlowDirection?

        private enum CodingKeys: String, CodingKey { case evaluated, caliberCm, velocityCms, flow }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(evaluated, forKey: .evaluated)
            guard evaluated else { return }
            try container.encodeIfPresent(caliberCm, forKey: .caliberCm)
            try container.encodeIfPresent(velocityCms, forKey: .velocityCms)
            try container.encodeIfPresent(flow, forKey: .flow)
        }
    }

    struct PortalPathology: Codable, Equatable, Sendable {
        var status: PortalStatus
        var kind: PortalPathologyKind?
        var evidence: String?
        var physicianConfirmed: Bool
    }

    /// Igual a `NORMAL_ABDOMEN_REPORT` de `@laudousg/shared`, já com a frase
    /// aprovada em 02/10/2026 ("Não há sinais de processo expansivo hepático.").
    static let normalAbdomenReport = "Fígado de margens regulares, dimensões e ecotextura normais. Vasos intra-hepáticos bem visíveis e de calibre anatômico. Não há sinais de processo expansivo hepático. Vesícula biliar de topografia usual e parede fina, sem cálculos. Vias biliares sem dilatação. Pâncreas e baço sem alterações. Rins tópicos, com dimensões e diferenciação corticomedular preservadas. Aorta e veia cava inferior de calibres normais. Bexiga de paredes finas e conteúdo anecoico homogêneo."

    var schemaVersion = PendingClinicalModelContracts.schemaVersion
    var categoryCode = ReportCategory.abdomenTotalDoppler.rawValue
    var physicianReviewed = false
    var documentationPhoto: DocumentationPhoto
    var abdomenReport: String
    var portalVein: RequiredVessel
    var hepaticVeins: OptionalVessel
    var splenicVein: OptionalVessel
    var superiorMesentericVein: OptionalVessel
    var commonHepaticArtery: OptionalVessel
    var portalPathology: PortalPathology

    var activationIssues: [ClinicalContractIssue] {
        var issues = physicianReviewIssues(physicianReviewed)
        if abdomenReport.trimmingCharacters(in: .whitespacesAndNewlines).count < 80 {
            issues.append(.init("ABDOMEN_REPORT_INVALID", field: "abdomenReport", message: "O modelo-base do abdome precisa estar completo antes de liberar o laudo."))
        }
        issues += vesselIssues(
            portalVein, field: "portalVein", incompleteCode: "PORTAL_VEIN_REQUIRED",
            incompleteMessage: "Veia porta exige calibre, velocidade e direção do fluxo informados pelo médico."
        )
        for (field, vessel) in [("hepaticVeins", hepaticVeins), ("splenicVein", splenicVein), ("superiorMesentericVein", superiorMesentericVein), ("commonHepaticArtery", commonHepaticArtery)] where vessel.evaluated {
            issues += vesselIssues(
                .init(caliberCm: vessel.caliberCm, velocityCms: vessel.velocityCms, flow: vessel.flow),
                field: field, incompleteCode: "OPTIONAL_VESSEL_INCOMPLETE",
                incompleteMessage: "Vaso marcado como avaliado exige calibre, velocidade e direção do fluxo."
            )
        }
        if portalPathology.status != .absent {
            if portalPathology.kind == nil || (portalPathology.evidence?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0) < 3 || !portalPathology.physicianConfirmed {
                issues.append(.init("PORTAL_CONCLUSION_INCOMPLETE", field: "portalPathology", message: "Hipertensão ou trombose portal exige tipo, critérios descritos e confirmação médica."))
            }
        }
        if portalVein.flow == .hepatofugal && portalPathology.status == .absent {
            issues.append(.init("HEPATOFUGAL_FLOW_WITHOUT_PORTAL_FINDING", field: "portalPathology.status", message: "Fluxo hepatofugal exige registrar a suspeita ou alteração portal e os critérios revisados."))
        }
        return issues
    }

    /// Mesmos códigos de `validateClinicalModelInput`; o servidor continua sendo
    /// a autoridade e devolve 422 se este espelho divergir.
    private func vesselIssues(
        _ vessel: RequiredVessel,
        field: String,
        incompleteCode: String,
        incompleteMessage: String
    ) -> [ClinicalContractIssue] {
        var issues: [ClinicalContractIssue] = []
        if vessel.caliberCm == nil || vessel.velocityCms == nil || vessel.flow == nil {
            issues.append(.init(incompleteCode, field: field, message: incompleteMessage))
        }
        if vessel.caliberCm.map({ !$0.isFinite || $0 <= 0 }) == true { issues.append(.init("VESSEL_CALIBER_INVALID", field: "\(field).caliberCm", message: "O calibre deve ser positivo.")) }
        if vessel.velocityCms.map({ !$0.isFinite || $0 <= 0 }) == true { issues.append(.init("VESSEL_VELOCITY_INVALID", field: "\(field).velocityCms", message: "A velocidade deve ser positiva.")) }
        return issues
    }
}

// MARK: - Doppler venoso de membro superior

struct DopplerVenosoMmssDraft: Codable, Equatable, Sendable {
    enum Indication: String, Codable, Sendable { case elective, thrombosisResearch = "thrombosis_research", catheter }
    enum SystemStatus: String, Codable, Sendable { case patent, thrombosis, notAssessed = "not_assessed" }
    enum Reflux: String, Codable, Sendable { case absent, present, notAssessed = "not_assessed" }
    enum JugularStatus: String, Codable, Sendable { case notAssessed = "not_assessed", patent, thrombosis }
    enum CatheterRelation: String, Codable, Sendable { case none, adjacent, aroundCatheter = "around_catheter", occlusive }
    enum ThrombosisPhase: String, Codable, Sendable { case notApplicable = "not_applicable", acute, subacute, chronic, indeterminate }

    struct Catheter: Codable, Equatable, Sendable {
        var present: Bool
        var relation: CatheterRelation?
        var segment: String?
    }

    struct Side: Codable, Equatable, Sendable {
        var examined: Bool
        var deepSystem: SystemStatus
        var superficialSystem: SystemStatus
        var competenceTested: Bool
        var reflux: Reflux
        var internalJugular: JugularStatus
        var catheter: Catheter
        var thrombosisPhase: ThrombosisPhase
        var phaseConfirmed: Bool

        var hasThrombosis: Bool {
            deepSystem == .thrombosis || superficialSystem == .thrombosis || internalJugular == .thrombosis
        }

        /// Sem trombose descrita, a fase sai junto (o seletor some da tela e o
        /// valor antigo bloquearia o laudo sem caminho de correção).
        func reconcilingThrombosisPhase() -> Self {
            var copy = self
            if !hasThrombosis { copy.thrombosisPhase = .notApplicable }
            if [.notApplicable, .indeterminate].contains(copy.thrombosisPhase) { copy.phaseConfirmed = false }
            return copy
        }
    }

    var schemaVersion = PendingClinicalModelContracts.schemaVersion
    var categoryCode = ReportCategory.dopplerVenosoMmss.rawValue
    var physicianReviewed = false
    var indication: Indication
    var laterality: ExamLaterality
    var right: Side
    var left: Side

    var activationIssues: [ClinicalContractIssue] {
        let sides: [(ExamLaterality, Side)] = [(.right, right), (.left, left)]
        return physicianReviewIssues(physicianReviewed) + sides.flatMap { side, value in
            var issues: [ClinicalContractIssue] = []
            let field = side.rawValue
            if sideRequired(side), !value.examined {
                issues.append(.init("SIDE_NOT_EXAMINED", field: field, message: "O lado solicitado precisa ser marcado como examinado."))
            }
            if !sideRequired(side), value.examined {
                issues.append(.init("SIDE_OUTSIDE_LATERALITY", field: field, message: "O lado examinado não foi solicitado. Ajuste a lateralidade antes de gerar o laudo."))
            }
            if value.examined && value.competenceTested && value.reflux == .notAssessed {
                issues.append(.init("COMPETENCE_WITHOUT_RESULT", field: "\(field).reflux", message: "Informe o resultado da pesquisa de refluxo."))
            }
            if value.examined && value.deepSystem == .notAssessed && value.superficialSystem == .notAssessed && value.internalJugular == .notAssessed {
                issues.append(.init("VENOUS_TERRITORY_REQUIRED", field: field, message: "Informe pelo menos um território venoso efetivamente avaliado neste lado."))
            }
            if value.examined && !value.competenceTested && value.reflux != .notAssessed {
                issues.append(.init("REFLUX_NOT_TESTED", field: "\(field).competenceTested", message: "Não conclua competência ou refluxo sem teste documentado."))
            }
            let hasThrombosis = value.deepSystem == .thrombosis || value.superficialSystem == .thrombosis || value.internalJugular == .thrombosis
            if !hasThrombosis && value.thrombosisPhase != .notApplicable {
                issues.append(.init("PHASE_WITHOUT_THROMBOSIS", field: "\(field).thrombosisPhase", message: "Fase só pode ser usada quando há trombose descrita."))
            }
            if hasThrombosis && ![.notApplicable, .indeterminate].contains(value.thrombosisPhase) && !value.phaseConfirmed {
                issues.append(.init("THROMBOSIS_PHASE_UNCONFIRMED", field: "\(field).phaseConfirmed", message: "A fase da trombose exige confirmação médica."))
            }
            if value.catheter.present && (value.catheter.relation == nil || value.catheter.relation == CatheterRelation.none || value.catheter.segment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false) {
                issues.append(.init("CATHETER_RELATION_INCOMPLETE", field: "\(field).catheter", message: "Informe o segmento e a relação do trombo com o cateter."))
            }
            return issues
        }
    }

    private func sideRequired(_ side: ExamLaterality) -> Bool { laterality == .bilateral || laterality == side }

    static let unexaminedSide = Side(
        examined: false, deepSystem: .notAssessed, superficialSystem: .notAssessed,
        competenceTested: false, reflux: .notAssessed, internalJugular: .notAssessed,
        catheter: .init(present: false, relation: nil, segment: nil),
        thrombosisPhase: .notApplicable, phaseConfirmed: false
    )

    /// Decisão de 30/09: exame bilateral gera um único laudo com seções direita
    /// e esquerda. Lado fora do pedido volta ao estado neutro para que achados
    /// antigos não entrem no texto nem bloqueiem a validação do servidor.
    func applyingLaterality(_ newValue: ExamLaterality) -> Self {
        var copy = self
        copy.laterality = newValue
        copy.right = copy.sideRequired(.right) ? Self.examined(right) : Self.unexaminedSide
        copy.left = copy.sideRequired(.left) ? Self.examined(left) : Self.unexaminedSide
        return copy
    }

    private static func examined(_ side: Side) -> Side {
        var copy = side
        copy.examined = true
        return copy
    }
}

// MARK: - Doppler arterial de membro superior

struct DopplerArterialMmssDraft: Codable, Equatable, Sendable {
    enum ArterialStatus: String, Codable, Sendable { case normal, stenosis, occlusion, other }
    enum OutletResult: String, Codable, Sendable { case negative, positive, indeterminate }

    struct ThoracicOutlet: Codable, Equatable, Sendable {
        var evaluated: Bool
        var maneuvers: String?
        var positions: String?
        var result: OutletResult?
        var physicianConfirmed: Bool?

        private enum CodingKeys: String, CodingKey { case evaluated, maneuvers, positions, result, physicianConfirmed }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(evaluated, forKey: .evaluated)
            guard evaluated else { return }
            try container.encodeIfPresent(maneuvers, forKey: .maneuvers)
            try container.encodeIfPresent(positions, forKey: .positions)
            try container.encodeIfPresent(result, forKey: .result)
            try container.encodeIfPresent(physicianConfirmed, forKey: .physicianConfirmed)
        }
    }

    struct Side: Codable, Equatable, Sendable {
        var examined: Bool
        var status: ArterialStatus
        var affectedVessel: String?
        var psvCms: [String: Double]
        var stenosisPercent: Double?
        var percentageDataSufficient: Bool
        var percentageConfirmed: Bool
        var distalPattern: String?
        var thoracicOutlet: ThoracicOutlet

        /// A VPS do vaso afetado é guardada sob o nome digitado; ao renomear,
        /// a medida acompanha o novo nome em vez de deixar uma chave órfã que
        /// entraria no laudo com o nome antigo.
        func renamingAffectedVessel(to newName: String?) -> Self {
            var copy = self
            if let oldName = affectedVessel,
               !DopplerArterialMmssDraft.standardPsvVessels.contains(oldName),
               let measurement = copy.psvCms.removeValue(forKey: oldName),
               let newName, !newName.isEmpty, copy.psvCms[newName] == nil {
                copy.psvCms[newName] = measurement
            }
            copy.affectedVessel = newName
            return copy
        }
    }

    static let standardPsvVessels = [
        "Artéria subclávia", "Artéria axilar", "Artéria braquial", "Artéria radial", "Artéria ulnar",
    ]

    var schemaVersion = PendingClinicalModelContracts.schemaVersion
    var categoryCode = ReportCategory.dopplerArterialMmss.rawValue
    var physicianReviewed = false
    var laterality: ExamLaterality
    var right: Side
    var left: Side

    var activationIssues: [ClinicalContractIssue] {
        let sides: [(ExamLaterality, Side)] = [(.right, right), (.left, left)]
        return physicianReviewIssues(physicianReviewed) + sides.flatMap { side, value in
            var issues: [ClinicalContractIssue] = []
            let field = side.rawValue
            if sideRequired(side), !value.examined {
                issues.append(.init("SIDE_NOT_EXAMINED", field: field, message: "O lado solicitado precisa ser marcado como examinado."))
            }
            if value.examined && value.status != .normal && (value.affectedVessel?.isEmpty != false || value.psvCms.isEmpty) {
                issues.append(.init("ALTERED_ARTERIAL_MEASUREMENTS_REQUIRED", field: field, message: "Alteração arterial exige vaso afetado e pelo menos uma VPS."))
            }
            if value.psvCms.values.contains(where: { !$0.isFinite || $0 <= 0 }) {
                issues.append(.init("ARTERIAL_PSV_INVALID", field: "\(field).psvCms", message: "As velocidades de pico sistólico devem ser positivas."))
            }
            if value.psvCms.keys.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                issues.append(.init("ARTERIAL_PSV_VESSEL_REQUIRED", field: "\(field).psvCms", message: "Cada velocidade de pico sistólico precisa do nome do vaso."))
            }
            if [.stenosis, .occlusion].contains(value.status) && value.distalPattern?.isEmpty != false {
                issues.append(.init("DISTAL_PATTERN_REQUIRED", field: "\(field).distalPattern", message: "Estenose ou oclusão exige padrão/amortecimento/reenchimento distal."))
            }
            if value.stenosisPercent != nil && (!value.percentageDataSufficient || !value.percentageConfirmed) {
                issues.append(.init("STENOSIS_PERCENT_UNSUPPORTED", field: "\(field).stenosisPercent", message: "O percentual exige dados suficientes e confirmação médica."))
            }
            if value.stenosisPercent != nil && value.status != .stenosis {
                issues.append(.init("STENOSIS_PERCENT_STATUS_MISMATCH", field: "\(field).stenosisPercent", message: "Percentual de estenose só pode ser informado quando o lado está marcado como estenose."))
            }
            if value.stenosisPercent == nil && (value.percentageDataSufficient || value.percentageConfirmed) {
                issues.append(.init("PERCENTAGE_FLAGS_WITHOUT_VALUE", field: "\(field).stenosisPercent", message: "Confirmações de percentual exigem um percentual informado."))
            }
            if value.stenosisPercent.map({ !$0.isFinite || !(1...100).contains($0) }) == true {
                issues.append(.init("STENOSIS_PERCENT_INVALID", field: "\(field).stenosisPercent", message: "O percentual de estenose deve estar entre 1 e 100%."))
            }
            if !sideRequired(side), value.examined {
                issues.append(.init("SIDE_OUTSIDE_LATERALITY", field: field, message: "O lado examinado não foi solicitado. Ajuste a lateralidade antes de gerar o laudo."))
            }
            if value.thoracicOutlet.evaluated {
                let textTooShort = { (text: String?) in (text?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0) < 3 }
                if textTooShort(value.thoracicOutlet.maneuvers) || textTooShort(value.thoracicOutlet.positions) || value.thoracicOutlet.result == nil || value.thoracicOutlet.physicianConfirmed != true {
                    issues.append(.init("THORACIC_OUTLET_UNCONFIRMED", field: "\(field).thoracicOutlet", message: "Desfiladeiro torácico exige manobras, posições, resultado e confirmação médica."))
                }
            }
            return issues
        }
    }

    private func sideRequired(_ side: ExamLaterality) -> Bool { laterality == .bilateral || laterality == side }

    static let unexaminedSide = Side(
        examined: false, status: .normal, affectedVessel: nil, psvCms: [:],
        stenosisPercent: nil, percentageDataSufficient: false, percentageConfirmed: false,
        distalPattern: nil,
        thoracicOutlet: .init(evaluated: false, maneuvers: nil, positions: nil, result: nil, physicianConfirmed: nil)
    )

    /// Mesma regra do venoso: um laudo, seções apenas dos lados solicitados.
    func applyingLaterality(_ newValue: ExamLaterality) -> Self {
        var copy = self
        copy.laterality = newValue
        copy.right = copy.sideRequired(.right) ? Self.examined(right) : Self.unexaminedSide
        copy.left = copy.sideRequired(.left) ? Self.examined(left) : Self.unexaminedSide
        return copy
    }

    private static func examined(_ side: Side) -> Side {
        var copy = side
        copy.examined = true
        return copy
    }
}

// MARK: - Ultrassonografia de tórax

enum BalikPleuralEffusionMethod {
    static let id = "balik-2006-adult-ventilated-supine-15deg"
    static let formula = "V (mL) = 20 × Sep (mm)"
    static let population = "Adulto sob ventilação mecânica, em decúbito supino com tronco a 15°"
    static let measurement = "Separação máxima no fim da expiração, na linha axilar posterior"
    static let doi = "10.1007/s00134-005-0024-2"
    static let meanAbsoluteErrorMl = 158

    static func volumeMl(separationMm: Double) -> Double? {
        guard separationMm.isFinite, separationMm > 0 else { return nil }
        return 20 * separationMm
    }
}

struct ThoraxDraft: Codable, Equatable, Sendable {
    enum PleuralLine: String, Codable, Sendable { case regular, irregular, notAssessed = "not_assessed" }
    enum Sliding: String, Codable, Sendable { case present, absent, notAssessed = "not_assessed" }
    enum BLineDistribution: String, Codable, Sendable { case none, focal, multifocal, diffuse }
    enum FindingStatus: String, Codable, Sendable { case notSeen = "not_seen", suspected, confirmed }

    struct BLines: Codable, Equatable, Sendable { var count: Int; var distribution: BLineDistribution }
    struct BalikContext: Codable, Equatable, Sendable {
        var adult: Bool
        var mechanicallyVentilated: Bool
        var supineTorso15Deg: Bool
        var endExpirationPosteriorAxillary: Bool
        var physicianConfirmed: Bool

        var supportsCalculation: Bool {
            adult && mechanicallyVentilated && supineTorso15Deg && endExpirationPosteriorAxillary && physicianConfirmed
        }
    }

    struct Effusion: Codable, Equatable, Sendable {
        var present: Bool
        var separationMm: Double?
        var context: BalikContext?

        private enum CodingKeys: String, CodingKey { case present, separationMm, context }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(present, forKey: .present)
            guard present else { return }
            try container.encodeIfPresent(separationMm, forKey: .separationMm)
            try container.encodeIfPresent(context, forKey: .context)
        }

        /// A estimativa só existe dentro da população e técnica validadas por
        /// Balik. Fora desse domínio, o contrato falha fechado e retorna `nil`.
        var estimatedVolumeMl: Double? {
            guard present, context?.supportsCalculation == true, let separationMm else { return nil }
            return BalikPleuralEffusionMethod.volumeMl(separationMm: separationMm)
        }
    }
    struct Side: Codable, Equatable, Sendable {
        var pleuralLine: PleuralLine
        var sliding: Sliding
        var linesB: BLines
        var effusion: Effusion
        var consolidation: FindingStatus
        var atelectasis: FindingStatus
        var pneumothorax: FindingStatus
    }

    var schemaVersion = PendingClinicalModelContracts.schemaVersion
    var categoryCode = ReportCategory.torax.rawValue
    var physicianReviewed = false
    var right: Side
    var left: Side
    var limitation: String?
    var correlationSuggested: Bool

    var activationIssues: [ClinicalContractIssue] {
        let sides: [(ExamLaterality, Side)] = [(.right, right), (.left, left)]
        var issues: [ClinicalContractIssue] = physicianReviewIssues(physicianReviewed) + sides.flatMap { side, value in
            var sideIssues: [ClinicalContractIssue] = []
            let field = side.rawValue
            if !(0...99).contains(value.linesB.count) {
                sideIssues.append(.init("LINES_B_COUNT_INVALID", field: "\(field).linesB.count", message: "A contagem de linhas B deve estar entre 0 e 99."))
            }
            if value.effusion.present {
                if BalikPleuralEffusionMethod.volumeMl(separationMm: value.effusion.separationMm ?? 0) == nil {
                    sideIssues.append(.init("EFFUSION_MEASUREMENT_REQUIRED", field: "\(field).effusion.separationMm", message: "Informe uma separação pleural máxima positiva, em milímetros."))
                }
                if value.effusion.context?.supportsCalculation != true {
                    sideIssues.append(.init("EFFUSION_BALIK_CONTEXT_UNSUPPORTED", field: "\(field).effusion.context", message: "A separação pleural será descrita sem cálculo de volume: o método de Balik só pode ser usado em adulto ventilado, supino com tronco a 15°, com medida máxima no fim da expiração na linha axilar posterior e contexto confirmado.", severity: .warning))
                }
            }
            if value.linesB.count == 0 && value.linesB.distribution != .none { sideIssues.append(.init("LINES_B_DISTRIBUTION_WITHOUT_COUNT", field: "\(field).linesB", message: "Distribuição exige contagem maior que zero.")) }
            if value.linesB.count > 0 && value.linesB.distribution == .none { sideIssues.append(.init("LINES_B_COUNT_WITHOUT_DISTRIBUTION", field: "\(field).linesB", message: "Linhas B registradas exigem distribuição.")) }
            return sideIssues
        }
        func hasFinding(_ side: Side) -> Bool {
            if side.pleuralLine != .regular || side.sliding != .present { return true }
            if side.linesB.count > 0 || side.effusion.present { return true }
            return side.consolidation != .notSeen
                || side.atelectasis != .notSeen
                || side.pneumothorax != .notSeen
        }
        let containsFinding = hasFinding(right) || hasFinding(left)
        if correlationSuggested && !containsFinding && limitation?.isEmpty != false {
            issues.append(.init("CORRELATION_WITHOUT_REASON", field: "correlationSuggested", message: "Correlação só cabe com achado, limitação ou campo incompleto."))
        }
        return issues
    }
}

// MARK: - Quadril infantil / Graf

struct QuadrilInfantilDraft: Codable, Equatable, Sendable {
    enum BonyRoof: String, Codable, Sendable { case normal, rounded, deficient, notAssessed = "not_assessed" }
    enum CartilaginousRoof: String, Codable, Sendable { case normal, displaced, notAssessed = "not_assessed" }
    enum FemoralHead: String, Codable, Sendable { case centered, decentered, dislocated, notAssessed = "not_assessed" }
    enum LabrumPosition: String, Codable, Sendable { case normal, everted, interposed, notAssessed = "not_assessed" }
    enum GrafClassification: String, Codable, Sendable { case typeI = "I", typeIIA = "IIA", typeIIB = "IIB", typeIIC = "IIC", typeD = "D", typeIII = "III", typeIV = "IV" }

    struct Side: Codable, Equatable, Sendable {
        var adequateStandardPlane: Bool
        var alphaDeg: Double?
        var betaDeg: Double?
        var bonyRoof: BonyRoof
        var cartilaginousRoof: CartilaginousRoof
        var femoralHead: FemoralHead
        var labrumPosition: LabrumPosition
        var coveragePercent: Double?
        var grafClassification: GrafClassification?
        var classificationConfirmed: Bool

        var hasCompleteGrafInputs: Bool {
            adequateStandardPlane && alphaDeg != nil && betaDeg != nil && bonyRoof != .notAssessed && cartilaginousRoof != .notAssessed && femoralHead != .notAssessed && labrumPosition != .notAssessed
        }
    }

    var schemaVersion = PendingClinicalModelContracts.schemaVersion
    var categoryCode = ReportCategory.quadrilInfantil.rawValue
    var physicianReviewed = false
    var ageDays: Int?
    var right: Side
    var left: Side
    var recommendation: String?
    var recommendationConfirmed: Bool

    var isOutsidePreferredAgeRange: Bool { ageDays.map { $0 > 183 } ?? false }

    /// Sugestão determinística conservadora. Entradas incompletas ou combinações
    /// morfológicas incompatíveis retornam `nil`; o resultado nunca equivale à
    /// confirmação médica.
    func suggestedGrafClassification(for laterality: ExamLaterality) -> GrafClassification? {
        guard let ageDays, let side = side(for: laterality), side.hasCompleteGrafInputs,
              let alpha = side.alphaDeg, let beta = side.betaDeg else { return nil }
        if alpha >= 60 { return .typeI }
        if alpha >= 50 { return ageDays <= 84 ? .typeIIA : .typeIIB }
        if alpha >= 43 {
            let centeredAndCovered = side.femoralHead == .centered && side.bonyRoof != .deficient && side.cartilaginousRoof == .normal
            return beta < 77 && centeredAndCovered ? .typeIIC : .typeD
        }
        if side.labrumPosition == .everted { return .typeIII }
        if side.labrumPosition == .interposed { return .typeIV }
        return nil
    }

    /// Uma confirmação vale só para a classificação que o médico viu. Se idade,
    /// ângulos ou morfologia mudarem a sugestão, a classificação e a confirmação
    /// são descartadas e precisam ser refeitas.
    func reconcilingGrafConfirmation() -> Self {
        var copy = self
        for laterality in [ExamLaterality.right, .left] {
            let suggestion = copy.suggestedGrafClassification(for: laterality)
            var side = laterality == .right ? copy.right : copy.left
            if side.grafClassification != nil && side.grafClassification != suggestion {
                side.grafClassification = nil
                side.classificationConfirmed = false
            }
            if side.grafClassification == nil { side.classificationConfirmed = false }
            if laterality == .right { copy.right = side } else { copy.left = side }
        }
        return copy
    }

    func validatedGrafClassification(for laterality: ExamLaterality) -> GrafClassification? {
        guard let side = side(for: laterality), side.classificationConfirmed,
              let suggestion = suggestedGrafClassification(for: laterality),
              side.grafClassification == suggestion else { return nil }
        return side.grafClassification
    }

    var activationIssues: [ClinicalContractIssue] {
        var issues = physicianReviewIssues(physicianReviewed)
        if ageDays == nil { issues.append(.init("AGE_REQUIRED", field: "ageDays", message: "Informe a idade em dias.")) }
        if ageDays.map({ !(0...730).contains($0) }) == true { issues.append(.init("AGE_INVALID", field: "ageDays", message: "A idade deve estar entre 0 e 730 dias.")) }
        if isOutsidePreferredAgeRange { issues.append(.init("AGE_OUTSIDE_TARGET", field: "ageDays", message: "Idade fora da faixa preferencial de 0 a 6 meses.", severity: .warning)) }
        for (field, value) in [("right", right), ("left", left)] {
            if value.alphaDeg.map({ !$0.isFinite || !(0...90).contains($0) }) == true { issues.append(.init("ALPHA_INVALID", field: "\(field).alphaDeg", message: "O ângulo alfa deve estar entre 0 e 90°.")) }
            if value.betaDeg.map({ !$0.isFinite || !(0...120).contains($0) }) == true { issues.append(.init("BETA_INVALID", field: "\(field).betaDeg", message: "O ângulo beta deve estar entre 0 e 120°.")) }
            if value.coveragePercent.map({ !$0.isFinite || !(0...100).contains($0) }) == true { issues.append(.init("COVERAGE_INVALID", field: "\(field).coveragePercent", message: "A cobertura deve estar entre 0 e 100%.")) }
            let laterality: ExamLaterality = field == "right" ? .right : .left
            let suggestion = suggestedGrafClassification(for: laterality)
            if suggestion == nil {
                let code = value.hasCompleteGrafInputs && value.alphaDeg.map({ $0 < 43 }) == true ? "GRAF_MORPHOLOGY_INSUFFICIENT" : "GRAF_INPUT_INCOMPLETE"
                issues.append(.init(code, field: field, message: "A classificação exige corte adequado, idade, ângulos e morfologia completos."))
            }
            if let suggestion, value.grafClassification != suggestion {
                issues.append(.init("GRAF_CLASSIFICATION_MISMATCH", field: "\(field).grafClassification", message: "A classificação informada diverge da sugestão determinística \(suggestion.rawValue)."))
            }
            if suggestion != nil && !value.classificationConfirmed { issues.append(.init("GRAF_UNCONFIRMED", field: "\(field).classificationConfirmed", message: "A classificação calculada ou selecionada exige confirmação médica.")) }
            if !value.adequateStandardPlane && value.grafClassification != nil { issues.append(.init("GRAF_INADEQUATE_PLANE", field: "\(field).adequateStandardPlane", message: "Corte inadequado bloqueia a classificação.")) }
        }
        if recommendation?.isEmpty == false && !recommendationConfirmed { issues.append(.init("RECOMMENDATION_UNCONFIRMED", field: "recommendationConfirmed", message: "Controle ou encaminhamento exige confirmação médica.")) }
        return issues
    }

    private func side(for laterality: ExamLaterality) -> Side? {
        switch laterality {
        case .right: right
        case .left: left
        case .bilateral: nil
        }
    }
}
