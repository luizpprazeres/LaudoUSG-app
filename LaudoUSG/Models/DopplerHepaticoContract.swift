import Foundation

/// Espelho Swift do contrato compartilhado `DOPPLER_HEPATICO`.
/// O estado inicial é deliberadamente não avaliado: nenhuma normalidade é
/// presumida antes do preenchimento e da confirmação explícita do médico.
struct DopplerHepaticoDraft: Codable, Equatable, Sendable {
    enum FlowDirection: String, Codable, Sendable {
        case hepatopetal, hepatofugal, absent = "ausente", other = "outro"
    }

    enum VascularPatency: String, Codable, Sendable {
        case notAssessed = "not_assessed", patent, thrombosis
    }

    enum SpectralPattern: String, Codable, Sendable {
        case notAssessed = "not_assessed", preserved, altered, other
    }

    enum PortalStatus: String, Codable, Sendable {
        case notAssessed = "not_assessed", absent, suspected, confirmed
    }

    enum PortalPathologyKind: String, Codable, Sendable {
        case portalHypertension = "portal_hypertension"
        case portalThrombosis = "portal_thrombosis"
        case other
    }

    struct RequiredVessel: Codable, Equatable, Sendable {
        var patency: VascularPatency?
        var caliberCm: Double?
        var velocityCms: Double?
        var flow: FlowDirection?
        var spectralPattern: SpectralPattern?
        var peakSystolicVelocityCms: Double?
        var endDiastolicVelocityCms: Double?
        var resistanceIndex: Double?
    }

    struct OptionalVessel: Codable, Equatable, Sendable {
        var evaluated: Bool
        var patency: VascularPatency?
        var caliberCm: Double?
        var velocityCms: Double?
        var flow: FlowDirection?
        var spectralPattern: SpectralPattern?
        var peakSystolicVelocityCms: Double?
        var endDiastolicVelocityCms: Double?
        var resistanceIndex: Double?

        private enum CodingKeys: String, CodingKey {
            case evaluated, patency, caliberCm, velocityCms, flow, spectralPattern
            case peakSystolicVelocityCms, endDiastolicVelocityCms, resistanceIndex
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(evaluated, forKey: .evaluated)
            guard evaluated else { return }
            try container.encodeIfPresent(patency, forKey: .patency)
            try container.encodeIfPresent(caliberCm, forKey: .caliberCm)
            try container.encodeIfPresent(velocityCms, forKey: .velocityCms)
            try container.encodeIfPresent(flow, forKey: .flow)
            try container.encodeIfPresent(spectralPattern, forKey: .spectralPattern)
            try container.encodeIfPresent(peakSystolicVelocityCms, forKey: .peakSystolicVelocityCms)
            try container.encodeIfPresent(endDiastolicVelocityCms, forKey: .endDiastolicVelocityCms)
            try container.encodeIfPresent(resistanceIndex, forKey: .resistanceIndex)
        }

        func settingEvaluated(_ newValue: Bool) -> Self {
            guard newValue else { return .notEvaluated }
            var copy = self
            copy.evaluated = true
            return copy
        }

        static let notEvaluated = Self(
            evaluated: false, patency: nil, caliberCm: nil, velocityCms: nil,
            flow: nil, spectralPattern: nil, peakSystolicVelocityCms: nil,
            endDiastolicVelocityCms: nil, resistanceIndex: nil
        )
    }

    struct PortalPathology: Codable, Equatable, Sendable {
        var status: PortalStatus
        var kind: PortalPathologyKind?
        var evidence: String?
        var physicianConfirmed: Bool

        func settingStatus(_ newValue: PortalStatus) -> Self {
            if newValue == .absent || newValue == .notAssessed {
                return .init(status: newValue, kind: nil, evidence: nil, physicianConfirmed: false)
            }
            return .init(status: newValue, kind: kind, evidence: evidence, physicianConfirmed: physicianConfirmed)
        }
    }

    var schemaVersion = PendingClinicalModelContracts.schemaVersion
    var categoryCode = ReportCategory.dopplerHepatico.rawValue
    var physicianReviewed = false
    var normalHemodynamicsConfirmed: Bool
    var portalVein: RequiredVessel
    var hepaticVeins: OptionalVessel
    var splenicVein: OptionalVessel
    var superiorMesentericVein: OptionalVessel
    var commonHepaticArtery: OptionalVessel
    var portalPathology: PortalPathology

    static let empty = Self(
        normalHemodynamicsConfirmed: false,
        portalVein: .init(
            patency: .notAssessed, caliberCm: nil, velocityCms: nil, flow: nil,
            spectralPattern: nil, peakSystolicVelocityCms: nil,
            endDiastolicVelocityCms: nil, resistanceIndex: nil
        ),
        hepaticVeins: .notEvaluated,
        splenicVein: .notEvaluated,
        superiorMesentericVein: .notEvaluated,
        commonHepaticArtery: .notEvaluated,
        portalPathology: .init(
            status: .notAssessed, kind: nil, evidence: nil, physicianConfirmed: false
        )
    )

    var activationIssues: [ClinicalContractIssue] {
        var issues = physicianReviewIssues(physicianReviewed)
        issues += genericVesselIssues(portalVein, field: "portalVein", requiresVelocity: true, code: "PORTAL_VEIN_REQUIRED")
        if portalVein.patency == nil || portalVein.patency == .notAssessed {
            issues.append(.init("PORTAL_PATENCY_REQUIRED", field: "portalVein.patency", message: "Informe a perviedade da veia porta."))
        }

        let optionals: [(String, OptionalVessel, Bool)] = [
            ("hepaticVeins", hepaticVeins, true),
            ("splenicVein", splenicVein, true),
            ("superiorMesentericVein", superiorMesentericVein, true),
            ("commonHepaticArtery", commonHepaticArtery, false),
        ]
        for (field, vessel, requiresVelocity) in optionals where vessel.evaluated {
            issues += genericVesselIssues(vessel.requiredValue, field: field, requiresVelocity: requiresVelocity, code: "OPTIONAL_VESSEL_INCOMPLETE")
            if vessel.patency == nil || vessel.patency == .notAssessed {
                issues.append(.init("VESSEL_PATENCY_REQUIRED", field: "\(field).patency", message: "Vaso marcado como avaliado exige perviedade informada."))
            }
        }

        if hepaticVeins.evaluated && (hepaticVeins.spectralPattern == nil || hepaticVeins.spectralPattern == .notAssessed) {
            issues.append(.init("HEPATIC_VEINS_PATTERN_REQUIRED", field: "hepaticVeins.spectralPattern", message: "Veias hepáticas avaliadas exigem padrão espectral informado."))
        }
        if commonHepaticArtery.evaluated {
            if commonHepaticArtery.peakSystolicVelocityCms == nil
                || commonHepaticArtery.endDiastolicVelocityCms == nil
                || commonHepaticArtery.resistanceIndex == nil
                || commonHepaticArtery.spectralPattern == nil
                || commonHepaticArtery.spectralPattern == .notAssessed {
                issues.append(.init("HEPATIC_ARTERY_HEMODYNAMICS_REQUIRED", field: "commonHepaticArtery", message: "Artéria hepática comum avaliada exige velocidades sistólica e diastólica, índice de resistência e padrão espectral."))
            }
            issues += arteryNumberIssues(commonHepaticArtery)
        }

        let pathology = portalPathology
        if pathology.status == .notAssessed {
            issues.append(.init("PORTAL_STATUS_REQUIRED", field: "portalPathology.status", message: "Revise a situação portal antes de liberar o laudo."))
        }
        if portalVein.flow == .hepatofugal && pathology.status == .absent {
            issues.append(.init("HEPATOFUGAL_FLOW_WITHOUT_PORTAL_FINDING", field: "portalPathology.status", message: "Fluxo hepatofugal não pode coexistir com situação portal marcada como ausente."))
        }
        if pathology.status == .suspected || pathology.status == .confirmed {
            if pathology.kind == nil || (pathology.evidence?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0) < 3 || !pathology.physicianConfirmed {
                issues.append(.init("PORTAL_CONCLUSION_INCOMPLETE", field: "portalPathology", message: "Hipertensão, trombose ou outra alteração vascular exige tipo, critérios descritos e confirmação médica."))
            }
        } else if pathology.kind != nil || pathology.evidence?.isEmpty == false || pathology.physicianConfirmed {
            issues.append(.init("PORTAL_FINDING_STATUS_MISMATCH", field: "portalPathology.status", message: "Tipo, critérios ou confirmação de alteração vascular exigem situação marcada como suspeita ou confirmada."))
        }

        if pathology.status == .absent {
            for (field, flow, expected) in evaluatedFlows where flow != expected {
                issues.append(.init("ABNORMAL_FLOW_WITHOUT_PORTAL_FINDING", field: "\(field).flow", message: "Fluxo ausente, de direção não fisiológica ou com padrão não descrito exige registrar a alteração."))
            }
            if evaluatedPatencies.contains(where: { $0 != .patent }) {
                issues.append(.init("NONPATENT_VESSEL_WITHOUT_FINDING", field: "portalPathology.status", message: "Perviedade alterada ou não avaliada não pode coexistir com conclusão vascular normal."))
            }
            if [hepaticVeins, commonHepaticArtery].contains(where: { $0.evaluated && $0.spectralPattern != .preserved }) {
                issues.append(.init("ALTERED_PATTERN_WITHOUT_FINDING", field: "portalPathology.status", message: "Padrão espectral alterado ou não descrito exige registrar a alteração e os critérios revisados."))
            }
            if !normalHemodynamicsConfirmed {
                issues.append(.init("NORMAL_HEMODYNAMICS_UNCONFIRMED", field: "normalHemodynamicsConfirmed", message: "A conclusão normal exige confirmação médica explícita de coerência entre medidas, fluxos e contexto do exame."))
            }
        } else if normalHemodynamicsConfirmed {
            issues.append(.init("NORMAL_CONFIRMATION_STATUS_MISMATCH", field: "normalHemodynamicsConfirmed", message: "A confirmação de normalidade só pode ser usada quando a situação vascular foi revisada como ausente."))
        }
        return issues
    }

    private var evaluatedFlows: [(String, FlowDirection, FlowDirection)] {
        var values: [(String, FlowDirection, FlowDirection)] = []
        if let flow = portalVein.flow { values.append(("portalVein", flow, .hepatopetal)) }
        if hepaticVeins.evaluated, let flow = hepaticVeins.flow { values.append(("hepaticVeins", flow, .hepatofugal)) }
        if splenicVein.evaluated, let flow = splenicVein.flow { values.append(("splenicVein", flow, .hepatopetal)) }
        if superiorMesentericVein.evaluated, let flow = superiorMesentericVein.flow { values.append(("superiorMesentericVein", flow, .hepatopetal)) }
        if commonHepaticArtery.evaluated, let flow = commonHepaticArtery.flow { values.append(("commonHepaticArtery", flow, .hepatopetal)) }
        return values
    }

    private var evaluatedPatencies: [VascularPatency?] {
        [portalVein.patency] + [hepaticVeins, splenicVein, superiorMesentericVein, commonHepaticArtery]
            .filter(\.evaluated).map(\.patency)
    }

    private func genericVesselIssues(_ vessel: RequiredVessel, field: String, requiresVelocity: Bool, code: String) -> [ClinicalContractIssue] {
        var issues: [ClinicalContractIssue] = []
        if vessel.caliberCm == nil || vessel.flow == nil || (requiresVelocity && vessel.velocityCms == nil) {
            issues.append(.init(code, field: field, message: field == "portalVein" ? "Veia porta exige calibre, velocidade e direção do fluxo informados pelo médico." : "Vaso marcado como avaliado exige calibre, velocidade aplicável e direção do fluxo."))
        }
        if vessel.caliberCm.map({ !$0.isFinite || $0 <= 0 }) == true {
            issues.append(.init("VESSEL_CALIBER_INVALID", field: "\(field).caliberCm", message: "O calibre deve ser positivo."))
        }
        if vessel.velocityCms.map({ !$0.isFinite || $0 < 0 }) == true {
            issues.append(.init("VESSEL_VELOCITY_INVALID", field: "\(field).velocityCms", message: "A velocidade não pode ser negativa."))
        }
        if vessel.velocityCms == 0 && vessel.flow != .absent {
            issues.append(.init("ZERO_VELOCITY_WITH_PRESENT_FLOW", field: "\(field).velocityCms", message: "Velocidade zero só pode ser registrada quando o fluxo estiver ausente."))
        }
        return issues
    }

    private func arteryNumberIssues(_ vessel: OptionalVessel) -> [ClinicalContractIssue] {
        var issues: [ClinicalContractIssue] = []
        if vessel.peakSystolicVelocityCms.map({ !$0.isFinite || $0 <= 0 }) == true {
            issues.append(.init("ARTERY_PSV_INVALID", field: "commonHepaticArtery.peakSystolicVelocityCms", message: "A velocidade de pico sistólico deve ser positiva."))
        }
        if vessel.endDiastolicVelocityCms.map({ !$0.isFinite || $0 < 0 }) == true {
            issues.append(.init("ARTERY_EDV_INVALID", field: "commonHepaticArtery.endDiastolicVelocityCms", message: "A velocidade diastólica final não pode ser negativa."))
        }
        if vessel.resistanceIndex.map({ !$0.isFinite || $0 < 0 || $0 > 1 }) == true {
            issues.append(.init("ARTERY_RI_INVALID", field: "commonHepaticArtery.resistanceIndex", message: "O índice de resistência deve estar entre 0 e 1."))
        }
        return issues
    }
}

private extension DopplerHepaticoDraft.OptionalVessel {
    var requiredValue: DopplerHepaticoDraft.RequiredVessel {
        .init(
            patency: patency, caliberCm: caliberCm, velocityCms: velocityCms,
            flow: flow, spectralPattern: spectralPattern,
            peakSystolicVelocityCms: peakSystolicVelocityCms,
            endDiastolicVelocityCms: endDiastolicVelocityCms,
            resistanceIndex: resistanceIndex
        )
    }
}
