import Foundation

/// Contrato portável do esquema de miomas.
///
/// Os nomes, valores e coordenadas são intencionalmente idênticos ao contrato
/// compartilhado usado no Android. O editor Swift mantém `figo == nil` enquanto
/// a classificação não foi confirmada; na fronteira portátil esse estado vira
/// `figoConfirmed == false` e continua bloqueado para envio.
struct MyomaSchemeContract: Codable, Equatable, Sendable {
    static let currentVersion = "myoma-scheme/v1"
    static let myomaExamType = "MIOMAS"

    struct Point: Codable, Equatable, Sendable {
        var x: Double
        var y: Double
    }

    enum Location: String, Codable, Sendable {
        case notInformed = "not_informed"
        case anterior
        case posterior
        case lateralDireita = "lateral_direita"
        case lateralEsquerda = "lateral_esquerda"
        case fundo
        case cervical
    }

    enum Echo: String, Codable, Sendable {
        case hipoecoica
        case heterogenea
        case calcificada
        case degenerada
    }

    struct Finding: Codable, Equatable, Sendable, Identifiable {
        var id: UUID
        var figo: Int
        var figoConfirmed: Bool
        var sizeMaxMm: Double?
        var location: Location
        var echo: Echo?
        var sagittalPoint: Point?
        var axialPoint: Point?

        private enum CodingKeys: String, CodingKey {
            case id, figo, figoConfirmed, sizeMaxMm, location, echo, sagittalPoint, axialPoint
        }

        /// O contrato Zod exige as chaves anuláveis. O encoder sintetizado do
        /// Swift omite Optional.none; aqui elas são emitidas explicitamente como
        /// `null`, preservando o mesmo shape entre as plataformas.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(figo, forKey: .figo)
            try container.encode(figoConfirmed, forKey: .figoConfirmed)
            if let sizeMaxMm { try container.encode(sizeMaxMm, forKey: .sizeMaxMm) } else { try container.encodeNil(forKey: .sizeMaxMm) }
            try container.encode(location, forKey: .location)
            if let echo { try container.encode(echo, forKey: .echo) } else { try container.encodeNil(forKey: .echo) }
            if let sagittalPoint { try container.encode(sagittalPoint, forKey: .sagittalPoint) } else { try container.encodeNil(forKey: .sagittalPoint) }
            if let axialPoint { try container.encode(axialPoint, forKey: .axialPoint) } else { try container.encodeNil(forKey: .axialPoint) }
        }
    }

    var contractVersion: String = MyomaSchemeContract.currentVersion
    var examType: String = MyomaSchemeContract.myomaExamType
    var findings: [Finding]

    var activationIssues: [ClinicalContractIssue] {
        var issues: [ClinicalContractIssue] = []
        if contractVersion != Self.currentVersion {
            issues.append(.init("MYOMA_CONTRACT_VERSION_INVALID", field: "contractVersion", message: "Versão incompatível do contrato de miomas."))
        }
        if examType != Self.myomaExamType {
            issues.append(.init("MYOMA_EXAM_TYPE_INVALID", field: "examType", message: "O esquema precisa usar o tipo MIOMAS."))
        }
        if findings.isEmpty {
            issues.append(.init("MYOMA_FINDINGS_REQUIRED", field: "findings", message: "Adicione ao menos um mioma antes de enviar o esquema."))
        }
        if findings.count > 20 {
            issues.append(.init("MYOMA_FINDINGS_LIMIT", field: "findings", message: "O esquema aceita no máximo 20 miomas."))
        }
        if Set(findings.map(\.id)).count != findings.count {
            issues.append(.init("MYOMA_ID_DUPLICATED", field: "findings", message: "Cada mioma precisa ter um identificador único."))
        }
        for (index, finding) in findings.enumerated() {
            if !(0...8).contains(finding.figo) {
                issues.append(.init("FIGO_INVALID", field: "findings.\(index).figo", message: "A categoria FIGO deve estar entre 0 e 8."))
            }
            if !finding.figoConfirmed {
                issues.append(.init("FIGO_UNCONFIRMED", field: "findings.\(index).figoConfirmed", message: "Confirme a categoria FIGO antes de enviar o esquema."))
            }
            if let diameter = finding.sizeMaxMm, diameter <= 0 || diameter > 500 {
                issues.append(.init("DIAMETER_INVALID", field: "findings.\(index).sizeMaxMm", message: "O maior diâmetro deve estar entre 0 e 500 mm."))
            }
        }
        return issues
    }

    init(findings: [Finding]) {
        self.findings = findings
    }

    init(editorFindings: [MyomaFinding]) {
        findings = editorFindings.map { finding in
            Finding(
                id: finding.id,
                figo: finding.figo ?? 4,
                figoConfirmed: finding.figo != nil,
                sizeMaxMm: finding.sizeMaxMm,
                location: Location(finding.localizacao),
                echo: finding.ecotextura.map(Echo.init),
                sagittalPoint: finding.sagPoint.map { Point(x: Double($0.x), y: Double($0.y)) },
                axialPoint: finding.axPoint.map { Point(x: Double($0.x), y: Double($0.y)) }
            )
        }
    }
}

private extension MyomaSchemeContract.Location {
    init(_ value: MyomaLocation) {
        switch value {
        case .notInformed: self = .notInformed
        case .anterior: self = .anterior
        case .posterior: self = .posterior
        case .lateralDireita: self = .lateralDireita
        case .lateralEsquerda: self = .lateralEsquerda
        case .fundo: self = .fundo
        case .cervical: self = .cervical
        }
    }
}

private extension MyomaSchemeContract.Echo {
    init(_ value: MyomaEcho) {
        switch value {
        case .hipoecoica: self = .hipoecoica
        case .heterogenea: self = .heterogenea
        case .calcificada: self = .calcificada
        case .degenerada: self = .degenerada
        }
    }
}
