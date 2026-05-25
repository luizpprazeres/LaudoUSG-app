import Foundation

/// Parser PT do texto do laudo Doppler MMII → array de `VenousFinding`.
/// Porta `lib/vascular/venousCartography.ts` da web com fixes preventivos:
/// - Pula linhas após header CONCLUSÃO/IMPRESSÃO (evita captura fantasma igual mama)
/// - Side detection por chunk com fallback sticky pro último side conhecido
enum VenousFindingsParser {

    /// Extrai achados venosos do texto. Cada chunk de sentença gera 0+ findings.
    /// Findings de ambas as pernas podem vir misturados — a UI filtra por side.
    static func parse(_ reportText: String) -> [VenousFinding] {
        guard !reportText.isEmpty else { return [] }

        var findings: [VenousFinding] = []
        var lastKnownSide: VenousFinding.Side = .direita
        var seenKeys: Set<String> = []
        var inConclusion = false

        let chunks = sentenceChunks(reportText)

        for chunk in chunks {
            // Pula tudo após header CONCLUSÃO
            if isConclusionHeader(chunk) {
                inConclusion = true
                continue
            }
            if inConclusion { continue }

            // Side: detecta no chunk, ou herda do último (default = direita)
            let side = inferSide(chunk) ?? lastKnownSide
            lastKnownSide = side

            guard let status = inferStatus(chunk) else { continue }

            let matched = matchVessels(in: chunk)
            let isDeepSystem = regexMatches(#"sistema\s+(?:venoso\s+)?profundo|veias\s+profundas"#, in: chunk)

            // Se nenhum vaso explícito mas é trombose aguda ou sistema profundo,
            // assume VFC + VF + POP (sistema profundo padrão)
            let vessels: [VenousFinding.Vessel] = matched.isEmpty
                ? ((status == .tromboseAguda || isDeepSystem) ? [.vfc, .vf, .pop] : [])
                : matched

            guard !vessels.isEmpty else { continue }

            let region = inferRegion(chunk)
            let refluxSeconds = extractRefluxSeconds(chunk)
            let diameterMm = extractDiameterMm(chunk)
            let thrombus = extractThrombusOcclusion(chunk)
            let compressible = extractCompressible(chunk)

            for vessel in vessels {
                let segmentId = defaultSegmentId(vessel: vessel, region: region)
                let key = "\(side.rawValue)-\(segmentId)-\(status.rawValue)"
                if seenKeys.contains(key) { continue }
                seenKeys.insert(key)

                let view = defaultView(vessel: vessel, region: region)
                let finding = VenousFinding(
                    side: side,
                    segmentId: segmentId,
                    vessel: vessel,
                    view: view,
                    region: region,
                    status: status,
                    refluxSeconds: refluxSeconds,
                    diameterMm: diameterMm,
                    thrombusOcclusion: thrombus,
                    compressible: compressible,
                    source: .parsed
                )
                findings.append(finding)
            }
        }

        // Fallback: se nenhum achado mas texto sugere normalidade global → marca segmentos
        // principais como suficientes (pra perna esquerda — padrão da web)
        if findings.isEmpty,
           regexMatches(#"normal|sem\s+sinais\s+de\s+trombose|aus[eê]ncia\s+de\s+refluxo"#, in: reportText) {
            let defaultSet: [(VenousFinding.Vessel, VenousFinding.Region?)] = [
                (.vfc, nil), (.vf, nil), (.pop, nil),
                (.vsm, .coxaMedia), (.vsp, .pernaMedia)
            ]
            let side = inferSide(reportText) ?? .direita
            for (vessel, region) in defaultSet {
                let segmentId = defaultSegmentId(vessel: vessel, region: region)
                let view = defaultView(vessel: vessel, region: region)
                findings.append(VenousFinding(
                    side: side,
                    segmentId: segmentId,
                    vessel: vessel,
                    view: view,
                    region: region,
                    status: .suficiente,
                    source: .parsed
                ))
            }
        }

        return findings
    }

    // MARK: - Side

    private static func inferSide(_ text: String) -> VenousFinding.Side? {
        let normalized = normalize(text)
        if regexMatches(#"\besquerd[ao]\b|\bmie\b"#, in: normalized) { return .esquerda }
        if regexMatches(#"\bdireit[ao]\b|\bmid\b"#, in: normalized) { return .direita }
        return nil
    }

    // MARK: - Region

    private static func inferRegion(_ text: String) -> VenousFinding.Region? {
        let t = normalize(text)
        if regexMatches(#"coxa.{0,20}proximal|terco\s+proximal.{0,20}coxa|proximal.{0,15}coxa"#, in: t) { return .coxaProximal }
        if regexMatches(#"coxa.{0,20}media|terco\s+medio.{0,20}coxa|media.{0,15}coxa"#, in: t) { return .coxaMedia }
        if regexMatches(#"coxa.{0,20}distal|terco\s+distal.{0,20}coxa|distal.{0,15}coxa"#, in: t) { return .coxaDistal }
        if regexMatches(#"joelho|poplitea"#, in: t) { return .joelho }
        if regexMatches(#"perna.{0,20}proximal|panturrilha.{0,20}proximal"#, in: t) { return .pernaProximal }
        if regexMatches(#"perna.{0,20}distal|panturrilha.{0,20}distal|tornozelo"#, in: t) { return .pernaDistal }
        if regexMatches(#"perna|panturrilha"#, in: t) { return .pernaMedia }
        return nil
    }

    // MARK: - Status

    /// Ordem dos checks importa: termos mais específicos primeiro.
    private static func inferStatus(_ text: String) -> VenousFinding.Status? {
        let t = normalize(text)
        if regexMatches(#"sem\s+(?:sinais\s+de\s+)?refluxo|\bcompetente\b|\bsuficiente\b"#, in: t) { return .suficiente }
        if regexMatches(#"safenectom|retirad[ao]|ausencia.{0,15}safena"#, in: t) { return .safenectomizada }
        if regexMatches(#"extrafascial"#, in: t) { return .extrafascial }
        if regexMatches(#"recanaliz"#, in: t) { return .parcialRecanalizada }
        if regexMatches(#"sequela|pos[-\s]?tvp|cronica"#, in: t) { return .tromboseCronica }
        if regexMatches(#"tromb|incompressivel|material\s+ecogenico|ausencia\s+de\s+fluxo|sem\s+fluxo|oclus"#, in: t) { return .tromboseAguda }
        if regexMatches(#"reflux|incompet|insuficien"#, in: t) { return .refluxo }
        if regexMatches(#"pervi|compressivel"#, in: t) { return .suficiente }
        return nil
    }

    // MARK: - Vessel match

    private struct VesselAlias {
        let vessel: VenousFinding.Vessel
        let pattern: String
    }

    /// Ordem importa: termos mais específicos primeiro (ex: "femoral comum" antes de "femoral").
    private static let vesselAliases: [VesselAlias] = [
        .init(vessel: .vfc, pattern: #"\b(femoral\s+comum|vfc)\b"#),
        .init(vessel: .vfp, pattern: #"\b(femoral\s+profunda|vfp)\b"#),
        .init(vessel: .vfib, pattern: #"\b(fibulares?|vfib)\b"#),
        .init(vessel: .vtp, pattern: #"\b(tibiais\s+posteriores?|vtp)\b"#),
        .init(vessel: .pop, pattern: #"\b(popl[ií]tea|pop)\b"#),
        .init(vessel: .vsm, pattern: #"\b(safena\s+magna|vsm)\b"#),
        .init(vessel: .vsp, pattern: #"\b(safena\s+parva|vsp)\b"#),
        .init(vessel: .jsf, pattern: #"\b(jun[cç][aã]o\s+safeno[-\s]?femoral|cro[cç]a|jsf)\b"#),
        .init(vessel: .jsp, pattern: #"\b(jun[cç][aã]o\s+safeno[-\s]?popl[ií]tea|jsp)\b"#),
        .init(vessel: .perfurante, pattern: #"\b(perfurantes?)\b"#),
        .init(vessel: .colateral, pattern: #"\b(varicosidades?|colaterais?|tribut[aá]rias?)\b"#),
        .init(vessel: .vf, pattern: #"\b(veia\s+femoral|vf)\b"#),
    ]

    private static func matchVessels(in text: String) -> [VenousFinding.Vessel] {
        var found: [VenousFinding.Vessel] = []
        var seen: Set<String> = []
        for alias in vesselAliases {
            if regexMatches(alias.pattern, in: text), !seen.contains(alias.vessel.rawValue) {
                found.append(alias.vessel)
                seen.insert(alias.vessel.rawValue)
            }
        }
        return found
    }

    // MARK: - Defaults (vessel + region → view, segmentId)

    private static func defaultView(vessel: VenousFinding.Vessel, region: VenousFinding.Region?) -> VenousFinding.View {
        if vessel == .vsm || vessel == .jsf || vessel == .perfurante { return .medial }
        if vessel == .vsp || vessel == .jsp { return .posterior }
        if vessel == .pop && region == .joelho { return .posterior }
        if vessel == .colateral { return .posterior }
        return .anterior
    }

    private static func defaultSegmentId(vessel: VenousFinding.Vessel, region: VenousFinding.Region?) -> String {
        switch vessel {
        case .vsm:
            switch region {
            case .coxaProximal: return "vsm-coxa-proximal"
            case .coxaMedia: return "vsm-coxa-media"
            case .coxaDistal, .joelho: return "vsm-coxa-distal"
            default: return "vsm-perna"
            }
        case .vsp:
            return region == .pernaDistal ? "vsp-distal" : "vsp-proximal"
        case .pop:
            return "pop-posterior"
        case .perfurante:
            if let r = region, r.rawValue.starts(with: "coxa") { return "perfurante-coxa" }
            return "perfurante-perna"
        case .colateral:
            return "gastrocnemias"
        case .jsf: return "jsf"
        case .jsp: return "jsp"
        case .vfc: return "vfc"
        case .vf: return "vf"
        case .vfp: return "vfp"
        case .vtp: return "vtp"
        case .vfib: return "vfib"
        }
    }

    // MARK: - Métricas opcionais

    private static func extractRefluxSeconds(_ text: String) -> Double? {
        // Ex: "refluxo de 1,2 s", "refluxo 2 segundos", "1.5 seg"
        guard let g = firstMatch(#"(\d{1,2}(?:[,.]\d{1,2})?)\s*(?:s|seg|segundos?)\b"#, in: text), g.count > 1 else { return nil }
        return Double(g[1].replacingOccurrences(of: ",", with: "."))
    }

    private static func extractDiameterMm(_ text: String) -> Double? {
        // Ex: "calibre 6,5 mm", "diâmetro 8mm"
        guard let g = firstMatch(#"(\d{1,2}(?:[,.]\d{1,2})?)\s*mm"#, in: text), g.count > 1 else { return nil }
        return Double(g[1].replacingOccurrences(of: ",", with: "."))
    }

    private static func extractThrombusOcclusion(_ text: String) -> VenousFinding.ThrombusOcclusion? {
        if regexMatches(#"\bparcial"#, in: text) { return .parcial }
        if regexMatches(#"\btotal|oclus(?:ao|ão|iva)"#, in: text) { return .total }
        return nil
    }

    private static func extractCompressible(_ text: String) -> Bool? {
        if regexMatches(#"incompress"#, in: text) { return false }
        if regexMatches(#"compress"#, in: text) { return true }
        return nil
    }

    // MARK: - Helpers (chunks, normalize, regex)

    private static func sentenceChunks(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "\n"))
            .flatMap { line -> [String] in
                line.split(omittingEmptySubsequences: false) { c in
                    c == "." || c == "!" || c == "?" || c == ";"
                }.map(String.init)
            }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func isConclusionHeader(_ text: String) -> Bool {
        regexMatches(#"^(?:conclus[aã]o|impress[aã]o\s+diagn[oó]stica|impress[aã]o|parecer)\b"#, in: text)
    }

    /// Remove acentos pra simplificar regex (apenas em ASCII).
    private static func normalize(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR")).lowercased()
    }

    private static func firstMatch(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive]
    ) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                groups.append(String(text[r]))
            } else {
                groups.append("")
            }
        }
        return groups
    }

    private static func regexMatches(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive]
    ) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
