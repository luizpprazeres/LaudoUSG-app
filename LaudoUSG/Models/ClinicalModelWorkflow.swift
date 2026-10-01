import Foundation

enum ClinicalModelDraft: Codable, Equatable, Sendable {
    case abdomen(AbdomenTotalDopplerDraft)
    case venous(DopplerVenosoMmssDraft)
    case arterial(DopplerArterialMmssDraft)
    case thorax(ThoraxDraft)
    case hip(QuadrilInfantilDraft)

    private enum Keys: String, CodingKey { case categoryCode }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let code = try container.decode(String.self, forKey: .categoryCode)
        switch ReportCategory(rawValue: code) {
        case .abdomenTotalDoppler: self = .abdomen(try .init(from: decoder))
        case .dopplerVenosoMmss: self = .venous(try .init(from: decoder))
        case .dopplerArterialMmss: self = .arterial(try .init(from: decoder))
        case .torax: self = .thorax(try .init(from: decoder))
        case .quadrilInfantil: self = .hip(try .init(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .categoryCode,
                in: container,
                debugDescription: "Categoria clínica não suportada: \(code)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .abdomen(let value): try value.encode(to: encoder)
        case .venous(let value): try value.encode(to: encoder)
        case .arterial(let value): try value.encode(to: encoder)
        case .thorax(let value): try value.encode(to: encoder)
        case .hip(let value): try value.encode(to: encoder)
        }
    }

    var category: ReportCategory {
        switch self {
        case .abdomen: .abdomenTotalDoppler
        case .venous: .dopplerVenosoMmss
        case .arterial: .dopplerArterialMmss
        case .thorax: .torax
        case .hip: .quadrilInfantil
        }
    }

    var activationIssues: [ClinicalContractIssue] {
        switch self {
        case .abdomen(let value): value.activationIssues
        case .venous(let value): value.activationIssues
        case .arterial(let value): value.activationIssues
        case .thorax(let value): value.activationIssues
        case .hip(let value): value.activationIssues
        }
    }

    var previewIssues: [ClinicalContractIssue] {
        activationIssues.filter { $0.code != "MODEL_NOT_REVIEWED" }
    }

    var physicianReviewed: Bool {
        switch self {
        case .abdomen(let value): value.physicianReviewed
        case .venous(let value): value.physicianReviewed
        case .arterial(let value): value.physicianReviewed
        case .thorax(let value): value.physicianReviewed
        case .hip(let value): value.physicianReviewed
        }
    }

    func settingPhysicianReviewed(_ reviewed: Bool) -> Self {
        switch self {
        case .abdomen(var value): value.physicianReviewed = reviewed; return .abdomen(value)
        case .venous(var value): value.physicianReviewed = reviewed; return .venous(value)
        case .arterial(var value): value.physicianReviewed = reviewed; return .arterial(value)
        case .thorax(var value): value.physicianReviewed = reviewed; return .thorax(value)
        case .hip(var value): value.physicianReviewed = reviewed; return .hip(value)
        }
    }

    static func empty(for category: ReportCategory) -> Self? {
        let vessel = AbdomenTotalDopplerDraft.OptionalVessel(
            evaluated: false, caliberCm: nil, velocityCms: nil, flow: nil
        )
        let venousSide = DopplerVenosoMmssDraft.Side(
            examined: false, deepSystem: .notAssessed, superficialSystem: .notAssessed,
            competenceTested: false, reflux: .notAssessed, internalJugular: .notAssessed,
            catheter: .init(present: false, relation: nil, segment: nil),
            thrombosisPhase: .notApplicable, phaseConfirmed: false
        )
        let arterialSide = DopplerArterialMmssDraft.Side(
            examined: false, status: .normal, affectedVessel: nil, psvCms: [:],
            stenosisPercent: nil, percentageDataSufficient: false, percentageConfirmed: false,
            distalPattern: nil,
            thoracicOutlet: .init(
                evaluated: false, maneuvers: nil, positions: nil,
                result: nil, physicianConfirmed: nil
            )
        )
        let thoraxSide = ThoraxDraft.Side(
            pleuralLine: .regular, sliding: .present,
            linesB: .init(count: 0, distribution: .none),
            effusion: .init(present: false, separationMm: nil, context: nil),
            consolidation: .notSeen, atelectasis: .notSeen, pneumothorax: .notSeen
        )
        let hipSide = QuadrilInfantilDraft.Side(
            adequateStandardPlane: false, alphaDeg: nil, betaDeg: nil,
            bonyRoof: .notAssessed, cartilaginousRoof: .notAssessed,
            femoralHead: .notAssessed, labrumPosition: .notAssessed,
            coveragePercent: nil, grafClassification: nil, classificationConfirmed: false
        )

        switch category {
        case .abdomenTotalDoppler:
            return .abdomen(.init(
                documentationPhoto: .include,
                abdomenReport: "Fígado de margens regulares, dimensões e ecotextura normais. Vasos intra-hepáticos bem visíveis e de calibre anatômico. Vesícula biliar de topografia usual e parede fina, sem cálculos. Vias biliares sem dilatação. Pâncreas e baço sem alterações. Rins tópicos, com dimensões e diferenciação corticomedular preservadas. Aorta e veia cava inferior de calibres normais. Bexiga de paredes finas e conteúdo anecoico homogêneo.",
                portalVein: .init(caliberCm: nil, velocityCms: nil, flow: nil),
                hepaticVeins: vessel, splenicVein: vessel,
                superiorMesentericVein: vessel, commonHepaticArtery: vessel,
                portalPathology: .init(
                    status: .absent, kind: nil, evidence: nil, physicianConfirmed: false
                )
            ))
        case .dopplerVenosoMmss:
            var right = venousSide; right.examined = true
            return .venous(.init(
                indication: .elective, laterality: .right, right: right, left: venousSide
            ))
        case .dopplerArterialMmss:
            var right = arterialSide; right.examined = true
            return .arterial(.init(laterality: .right, right: right, left: arterialSide))
        case .torax:
            return .thorax(.init(
                right: thoraxSide, left: thoraxSide,
                limitation: nil, correlationSuggested: false
            ))
        case .quadrilInfantil:
            return .hip(.init(
                ageDays: nil, right: hipSide, left: hipSide,
                recommendation: nil, recommendationConfirmed: false
            ))
        default:
            return nil
        }
    }
}

struct ClinicalRemoteReportState: Codable, Equatable, Sendable {
    enum ReviewState: String, Codable, Sendable { case pending, reviewed }
    var id: String
    var contentRevision: Int
    var generatedOutput: String
    var reviewState: ReviewState
    var reviewedAt: Date?
}

struct ClinicalModelWorkspaceState: Codable, Equatable, Sendable {
    var draft: ClinicalModelDraft
    private(set) var previewText: String?
    private(set) var remoteReport: ClinicalRemoteReportState?

    init(
        draft: ClinicalModelDraft,
        previewText: String? = nil,
        remoteReport: ClinicalRemoteReportState? = nil
    ) {
        self.draft = draft
        self.previewText = previewText
        self.remoteReport = remoteReport
    }

    var warnings: [ClinicalContractIssue] {
        draft.previewIssues.filter { $0.severity == .warning }
    }

    var blockingIssues: [ClinicalContractIssue] {
        draft.previewIssues.filter { $0.severity == .error }
    }

    var canCopyOrSendToSala: Bool {
        remoteReport?.reviewState == .reviewed && draft.physicianReviewed
    }

    /// Aprovação remota não é credencial persistível. Ao restaurar um draft,
    /// o cliente mantém os campos e a prévia, mas exige novo ciclo autenticado.
    var draftForPersistence: Self {
        .init(
            draft: draft.settingPhysicianReviewed(false),
            previewText: previewText,
            remoteReport: nil
        )
    }

    mutating func replaceDraft(_ newValue: ClinicalModelDraft) {
        draft = newValue.settingPhysicianReviewed(false)
        previewText = nil
        remoteReport = nil
    }

    @discardableResult
    mutating func preparePreview() throws -> String {
        guard blockingIssues.isEmpty else {
            throw ClinicalModelWorkflowError.validation(blockingIssues)
        }
        let rendered = try ClinicalModelReportRenderer.render(draft)
        previewText = rendered
        remoteReport = nil
        draft = draft.settingPhysicianReviewed(false)
        return rendered
    }

    mutating func acceptCreatedReport(_ report: ClinicalReportService.Report) throws {
        guard report.categoryCode == draft.category.rawValue,
              report.contract.settingPhysicianReviewed(false) == draft.settingPhysicianReviewed(false) else {
            throw ClinicalModelWorkflowError.remoteMismatch
        }
        draft = draft.settingPhysicianReviewed(false)
        // A versão devolvida pela API é a fonte de verdade para a revisão e
        // substitui a prévia local antes de qualquer liberação.
        previewText = report.generatedOutput
        remoteReport = .init(
            id: report.id,
            contentRevision: report.contentRevision,
            generatedOutput: report.generatedOutput,
            reviewState: .pending,
            reviewedAt: nil
        )
    }

    mutating func acceptReview(_ response: ClinicalReportService.ReviewResponse) throws {
        guard response.ok,
              response.reviewStatus == "reviewed",
              var report = remoteReport,
              response.contentRevision == report.contentRevision else {
            throw ClinicalModelWorkflowError.remoteMismatch
        }
        report.reviewState = .reviewed
        report.reviewedAt = response.reviewedAt
        remoteReport = report
        draft = draft.settingPhysicianReviewed(true)
    }
}

enum ClinicalModelWorkflowError: LocalizedError {
    case validation([ClinicalContractIssue])
    case remoteMismatch

    var errorDescription: String? {
        switch self {
        case .validation(let issues):
            return issues.map(\.message).joined(separator: "\n")
        case .remoteMismatch:
            return "O servidor não confirmou a mesma versão do laudo. Gere a prévia novamente antes de revisar."
        }
    }
}
