import Foundation

/// Parser PT do texto do laudo tireoidiano → array de `ThyroidFinding`.
/// Porta `lib/tireoide/parseFindings.ts` da web com fixes preventivos:
/// - State `inConclusion` pula linhas após header CONCLUSÃO (igual ao bug que tivemos no parser mama)
/// - `extractSizeMax` normaliza cm → mm
enum ThyroidFindingsParser {

    /// Extrai achados do texto do laudo. Cada achado vem com `source = .parsed`.
    static func parse(_ reportText: String) -> [ThyroidFinding] {
        var findings: [ThyroidFinding] = []
        var lastKnownSide: ThyroidFinding.Side? = nil

        let blocks = splitIntoFindingBlocks(reportText)

        for block in blocks {
            let side = extractSide(block) ?? lastKnownSide
            guard let s = side else { continue }
            lastKnownSide = s

            let type = extractType(block)
            let tercio = extractTercio(block)

            let finding = ThyroidFinding(
                side: s,
                tercio: tercio,
                type: type,
                shape: extractShape(block),
                sizeMax: extractSizeMax(block),
                margins: extractMargins(block),
                echogenicity: extractEchogenicity(block),
                tiRads: extractTiRads(block),
                approximate: tercio == nil && s != .istmo,
                source: .parsed
            )
            findings.append(finding)
        }

        return findings
    }

    // MARK: - Segmentation

    /// Quebra texto em blocos por sentença, filtra pelos que mencionam achados nodulares.
    /// Também pula tudo após o header CONCLUSÃO/IMPRESSÃO.
    private static func splitIntoFindingBlocks(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        // Quebra por ponto/ponto-e-vírgula seguido de espaço, ou newline
        let pieces = text.components(separatedBy: CharacterSet(charactersIn: "\n"))
            .flatMap { $0.split(separator: ".", omittingEmptySubsequences: false).flatMap { $0.split(separator: ";", omittingEmptySubsequences: false) } }
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var blocks: [String] = []
        var inConclusion = false

        for piece in pieces {
            if isConclusionHeader(piece) {
                inConclusion = true
                continue
            }
            if inConclusion { continue }

            if hasNoduleHeadword(piece) {
                blocks.append(piece)
            }
        }
        return blocks
    }

    private static func hasNoduleHeadword(_ text: String) -> Bool {
        regexMatches(
            #"\b(?:n[oó]dulo|formaç[aã]o\s+nodular|imagem\s+(?:anec[oó]ica|hipoec[oó]ica|isoec[oó]ica|hiperec[oó]ica|c[ií]stica)|cisto|microc[ií]sto|les[aã]o\s+focal|calcifica[çc][aã]o(?:es)?|microcalcifica[çc][aã]o(?:es)?)\b"#,
            in: text
        )
    }

    private static func isConclusionHeader(_ text: String) -> Bool {
        regexMatches(
            #"^(?:conclus[aã]o|birads|bi-rads|impress[aã]o\s+diagn[oó]stica|impress[aã]o|parecer|ti-rads|tirads)\b"#,
            in: text
        )
    }

    // MARK: - Side

    private static func extractSide(_ text: String) -> ThyroidFinding.Side? {
        if regexMatches(#"\bistmo\b"#, in: text) { return .istmo }

        if let g = firstMatch(#"\blobo\s+(direito|esquerdo|dir\.?|esq\.?)\b"#, in: text), g.count > 1 {
            let s = g[1].lowercased()
            return s.hasPrefix("d") ? .direito : .esquerdo
        }
        if let g = firstMatch(#"\b(LTD|LTE|LD|LE)\b"#, in: text, options: []), g.count > 1 {
            let a = g[1]
            return (a == "LTD" || a == "LD") ? .direito : .esquerdo
        }
        if let g = firstMatch(#"\b(?:à|na|do|pela)\s+(direita|esquerda)\b"#, in: text), g.count > 1 {
            return g[1].lowercased() == "direita" ? .direito : .esquerdo
        }
        return nil
    }

    // MARK: - Tercio

    private static func extractTercio(_ text: String) -> ThyroidFinding.Tercio? {
        if regexMatches(#"ter[çc]o\s+superior|polo\s+superior|porç[aã]o\s+superior|\bsuperior\b"#, in: text) {
            return .superior
        }
        if regexMatches(#"ter[çc]o\s+m[eé]dio|mes[oó]|porç[aã]o\s+m[eé]dia|\bm[eé]dio\b"#, in: text) {
            return .medio
        }
        if regexMatches(#"ter[çc]o\s+inferior|polo\s+inferior|porç[aã]o\s+inferior|\binferior\b"#, in: text) {
            return .inferior
        }
        return nil
    }

    // MARK: - Type
    //
    // Inteligência clínica: padrão ecográfico → tipo inferido mesmo sem o médico dizer.
    // - Anecoico → cisto; com septação/debris → misto
    // - Hipo/iso/heterogêneo → sólido (default)
    // - Esponjoso explícito → spongiform
    // - Calcificação só se NÃO houver estrutura nodular descrita junto
    private static func extractType(_ text: String) -> ThyroidFinding.FindingType {
        if regexMatches(#"esponjos[oa]|spongiform"#, in: text) { return .spongiform }

        let hasCalc = regexMatches(
            #"\bcalcifica[çc][aã]o|\bmicrocalcifica[çc][aã]o|hiperecoic[oa].{0,60}sombra\s*ac[úu]stica|sombra\s+ac[úu]stica|puntiform"#,
            in: text
        )
        let hasNodule = regexMatches(
            #"n[oó]dulo|formaç[aã]o\s+nodular|cisto|imagem\s+(?:anec|hipoecoic|isoec|hiperec)"#,
            in: text
        )
        if hasCalc && !hasNodule { return .calcification }

        if regexMatches(#"\bc[ií]stic[oa]\b|anec[oó]ic[oa]|conte[úu]do\s+l[ií]quido"#, in: text) {
            if regexMatches(#"s[oó]lid|parede\s+espessad|debris|septa"#, in: text) {
                return .mixed
            }
            return .cystic
        }

        if regexMatches(
            #"s[oó]lid[oa].{0,25}(?:c[ií]stic|liquid|anec)|(?:c[ií]stic|liquid|anec).{0,25}s[oó]lid"#,
            in: text
        ) {
            return .mixed
        }

        return .solid
    }

    // MARK: - Shape

    private static func extractShape(_ text: String) -> ThyroidFinding.Shape? {
        if regexMatches(#"lobulad[ao]|lobulações|macrolobulação|contornos?\s+lobulados?|lobulaç"#, in: text) {
            return .lobulated
        }
        if regexMatches(#"\boval\b|elips[oó]ide|alongad[ao]|formato\s+oval"#, in: text) {
            return .oval
        }
        if regexMatches(#"arredondad[ao]|redond[ao]|esf[eé]ric[ao]|formato\s+arredondado"#, in: text) {
            return .round
        }
        return nil
    }

    // MARK: - Margins

    private static func extractMargins(_ text: String) -> ThyroidFinding.Margins? {
        if regexMatches(#"espicul"#, in: text) { return .spiculated }
        if regexMatches(#"irregular|mal\s+definid"#, in: text) { return .irregular }
        if regexMatches(#"regular|bem\s+definid|circunscrit"#, in: text) { return .regular }
        return nil
    }

    // MARK: - Echogenicity

    private static func extractEchogenicity(_ text: String) -> ThyroidFinding.Echogenicity? {
        if regexMatches(#"anec[oó]ic"#, in: text) { return .anechoic }
        if regexMatches(#"hipoec[oó]ic"#, in: text) { return .hypo }
        if regexMatches(#"isoec[oó]ic"#, in: text) { return .iso }
        if regexMatches(#"hiperec[oó]ic"#, in: text) { return .hyper }
        if regexMatches(#"heterog[eê]ne|misto|mista"#, in: text) { return .mixed }
        return nil
    }

    // MARK: - SizeMax (sempre em mm)

    private static func extractSizeMax(_ text: String) -> Double? {
        var values: [Double] = []
        let parseNum: (String) -> Double = { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let toMm: (Double, String) -> Double = { v, unit in unit.lowercased() == "cm" ? v * 10 : v }

        // Padrão "2,1 x 1,8 x 2,4 cm" ou "2,1 x 1,8 cm"
        let multiPattern = #"(\d{1,3}(?:[.,]\d{1,2})?)\s*(?:x|×)\s*(\d{1,3}(?:[.,]\d{1,2})?)(?:\s*(?:x|×)\s*(\d{1,3}(?:[.,]\d{1,2})?))?\s*(mm|cm)"#
        for groups in allMatches(multiPattern, in: text) {
            guard groups.count >= 5 else { continue }
            let unit = groups[4]
            values.append(toMm(parseNum(groups[1]), unit))
            values.append(toMm(parseNum(groups[2]), unit))
            if !groups[3].isEmpty {
                values.append(toMm(parseNum(groups[3]), unit))
            }
        }

        // Se não capturou multi-eixo, tenta padrão single "8 mm" ou "1,2 cm"
        if values.isEmpty {
            let singlePattern = #"(\d{1,3}(?:[.,]\d{1,2})?)\s*(mm|cm)\b"#
            for groups in allMatches(singlePattern, in: text) {
                guard groups.count >= 3 else { continue }
                values.append(toMm(parseNum(groups[1]), groups[2]))
            }
        }

        guard let maxVal = values.max() else { return nil }
        return (maxVal * 10).rounded() / 10
    }

    // MARK: - TI-RADS

    private static func extractTiRads(_ text: String) -> Int? {
        if let g = firstMatch(#"\bTR\s*([1-5])\b|\bTI[-\s]?RADS\s*(?:categoria\s*)?([1-5])\b"#, in: text) {
            let raw = (g.count > 1 && !g[1].isEmpty) ? g[1] : (g.count > 2 ? g[2] : "")
            if let n = Int(raw), n >= 1, n <= 5 { return n }
        }
        return nil
    }

    // MARK: - Regex helpers

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

    private static func allMatches(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive]
    ) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.map { match in
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
