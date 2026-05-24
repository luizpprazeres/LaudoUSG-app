import Foundation

/// Parser PT do texto do laudo mamário → array de `BreastFinding`.
/// Porta `lib/mamas/parseFindings.ts` da web com correções:
/// - Aceita "imagem" singular (regex `imagen+s?` da web não pegava)
/// - Ignora linhas após o header "CONCLUSÃO:" (evita capturar achados fantasma da conclusão)
/// - Ignora linhas que descrevem linfonodos axilares (não são achados mamários)
/// - Captura unidade (cm/mm) no `extractSize` e normaliza para mm
enum BreastFindingsParser {

    /// Extrai achados do texto do laudo. Cada achado vem com `source = .parsed`.
    static func parse(_ reportText: String) -> [BreastFinding] {
        var findings: [BreastFinding] = []
        var activeSide: BreastFinding.Side? = nil
        var inConclusion = false

        var normalized = reportText.replacingOccurrences(
            of: #"(?:\.\s+|;\s+)(?=(?:imagem|imagens|image|nódulo|nodulo|cisto|formação|formacao|lesão|lesao|área|area|outro|segunda?|adjacente|há\s+também|identifica-se|observa-se|nota-se|visualiza-se)\b)"#,
            with: ".\n",
            options: [.regularExpression, .caseInsensitive]
        )
        normalized = normalized.replacingOccurrences(
            of: #",?\s+e\s+(?=(?:nódulo|nodulo|cisto|imagem|imagens|outro|uma?|segunda?)\s)"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // Uma vez detectada a seção de conclusão, todas as linhas seguintes são puladas.
            // Isso previne capturar frases tipo "Cisto simples de mão na direita..." como achado fantasma.
            if isConclusionHeader(line) {
                inConclusion = true
                continue
            }
            if inConclusion { continue }

            if let s = extractSide(line) { activeSide = s }

            // Linhas descrevendo linfonodos axilares (sem menção a mama) não são achados mamários.
            if isAxillaryFinding(line) { continue }

            if !isFindingLine(line) { continue }

            let prev = i > 0 ? lines[i - 1] : ""
            let next = i < lines.count - 1 ? lines[i + 1] : ""
            let context = [prev, line, next].joined(separator: " ")

            guard let side = activeSide else { continue }

            let hora = extractHora(line) ?? extractHora(context)
            let quadrant = extractQuadrant(line) ?? extractQuadrant(context)
            let type = extractType(line)
            let size = extractSize(line) ?? extractSize(context)
            let dist = extractDistMamilo(line) ?? extractDistMamilo(context)

            if hora == nil && quadrant == nil {
                let sameHemisphere = findings.filter { $0.side == side }.count
                let defaultHoras = [12, 3, 9, 6, 1, 7, 11, 5]
                let autoHora = defaultHoras[sameHemisphere % defaultHoras.count]
                findings.append(BreastFinding(
                    side: side,
                    type: type,
                    hora: autoHora,
                    quadrant: nil,
                    sizeMax: size,
                    distMamilo: dist,
                    approximate: true,
                    source: .parsed
                ))
                continue
            }

            findings.append(BreastFinding(
                side: side,
                type: type,
                hora: hora,
                quadrant: quadrant,
                sizeMax: size,
                distMamilo: dist,
                approximate: hora == nil && quadrant != nil,
                source: .parsed
            ))
        }

        return deduplicate(findings)
    }

    // MARK: - Side

    private static func extractSide(_ text: String) -> BreastFinding.Side? {
        if let g = firstMatch(#"\bmama\s+(direita|esquerda)\b"#, in: text), g.count > 1 {
            return g[1].lowercased() == "direita" ? .direita : .esquerda
        }
        if let g = firstMatch(#"\b(?:à|na|da|pela)\s+(direita|esquerda)\b"#, in: text), g.count > 1 {
            return g[1].lowercased() == "direita" ? .direita : .esquerda
        }
        if let g = firstMatch(#"\b(MD|ME)\b"#, in: text, options: []), g.count > 1 {
            return g[1] == "MD" ? .direita : .esquerda
        }
        if let g = firstMatch(#"\b(direita|esquerda)\s*:"#, in: text), g.count > 1 {
            return g[1].lowercased() == "direita" ? .direita : .esquerda
        }
        return nil
    }

    // MARK: - Hora

    private static func extractHora(_ text: String) -> Int? {
        let p1 = #"(?:às?|as\b|das|ao|de|entre|na[s]?|horário\s+das?|posição\s+das?)\s+[\u{201C}"]?0?(\d{1,2})\s*(?:horas?|h\b)[\u{201D}"]?"#
        if let g = firstMatch(p1, in: text), g.count > 1, let h = Int(g[1]), h >= 1, h <= 12 {
            return h
        }
        let p2 = #"\b0?(1[0-2]|[1-9])\s*(?:horas?|h)\b"#
        if let g = firstMatch(p2, in: text), g.count > 1, let h = Int(g[1]), h >= 1, h <= 12 {
            return h
        }
        // Posições descritivas → hora inferida
        if regexMatches(#"retroareolar|periareolar|retropapilar|retromamilar"#, in: text) { return 12 }
        if regexMatches(#"cauda|prolongamento\s+axilar"#, in: text) { return 10 }
        if regexMatches(#"jun[çc][aã]o\s+dos?\s+quadrantes?\s+(?:superiores?|sup)"#, in: text) { return 12 }
        if regexMatches(#"jun[çc][aã]o\s+dos?\s+quadrantes?\s+(?:inferiores?|inf)"#, in: text) { return 6 }
        if regexMatches(#"jun[çc][aã]o\s+dos?\s+quadrantes?\s+(?:laterais?|lat)"#, in: text) { return 9 }
        if regexMatches(#"jun[çc][aã]o\s+dos?\s+quadrantes?\s+(?:mediais?|med)"#, in: text) { return 3 }
        return nil
    }

    // MARK: - Type
    //
    // Inteligência clínica: padrão ecográfico → tipo inferido mesmo sem o médico dizer "cisto" ou "nódulo".
    // - anecoico/conteúdo líquido → cisto (mesmo sem "cisto" no texto)
    // - hipo/iso/heterogênea → nódulo sólido
    // - lobulado → sólido lobulado
    // - calcificação → calcificação
    // - linfonodo (intramamário) → linfonodo
    private static func extractType(_ text: String) -> BreastFinding.FindingType {
        if regexMatches(#"calcifica[çc][aã]o|microcalcifica[çc][aã]o"#, in: text) { return .calcification }
        if regexMatches(#"anec[oó]ic[ao]|conte[úu]do\s+l[ií]quido|cisto\b"#, in: text) { return .cyst }
        if regexMatches(#"linfonodo|linfonode|gângl|gangl|intramamár"#, in: text) { return .lymphNode }
        if regexMatches(#"(lóbulo|lobulad[ao]|lobula[çc])"#, in: text) { return .solidLobulated }
        return .solid
    }

    // MARK: - Quadrant

    private static func extractQuadrant(_ text: String) -> BreastFinding.Quadrant? {
        // Forma composta: "súpero-lateral", "ínfero-medial" etc.
        let composto = #"quadrante\s+(?:s[uú]pero[-\s]?|superior\s+)(lateral|medial|externo|interno)|quadrante\s+(?:[ií]nfero[-\s]?|inferior\s+)(lateral|medial|externo|interno)"#
        if let g = firstMatch(composto, in: text), !g.isEmpty {
            let matched = g[0].lowercased()
            let isInf = matched.contains("ínfero") || matched.contains("infero") || matched.contains("inferior")
            let isLat = matched.contains("lateral") || matched.contains("externo")
            if !isInf && isLat { return .qsl }
            if !isInf && !isLat { return .qsm }
            if isInf && isLat { return .qil }
            if isInf && !isLat { return .qim }
        }
        // Forma simples: "quadrante superior lateral"
        let simples = #"quadrante\s+(superior|inferior)\s+(lateral|medial|externo|interno)"#
        if let g = firstMatch(simples, in: text), g.count > 2 {
            let vert = g[1].lowercased()
            let horiz = g[2].lowercased()
            let isLat = (horiz == "lateral" || horiz == "externo")
            if vert == "superior" && isLat { return .qsl }
            if vert == "superior" && !isLat { return .qsm }
            if vert == "inferior" && isLat { return .qil }
            if vert == "inferior" && !isLat { return .qim }
        }
        // Abreviatura: QSL, QIL, Q.S.L., etc.
        let abrev = #"\bQ[.]?([SI])[.]?([LMEe])[.]?(?=[^a-zA-Z]|$)"#
        if let g = firstMatch(abrev, in: text), g.count > 2 {
            let v = g[1].uppercased()
            let h = g[2].uppercased()
            let isLat = (h == "L" || h == "E")
            if v == "S" && isLat { return .qsl }
            if v == "S" && !isLat { return .qsm }
            if v == "I" && isLat { return .qil }
            if v == "I" && !isLat { return .qim }
        }
        return nil
    }

    // MARK: - Size
    //
    // Captura o maior eixo + unidade (cm/mm). Normaliza para mm.
    private static func extractSize(_ text: String) -> Double? {
        // "medindo 2,7 x 1,7 x 2,0 cm" ou "medindo 2,7 x 1,7 cm"
        let p1 = #"medindo\s+([\d,.]+)\s*[x×]\s*[\d,.]+(?:\s*[x×]\s*[\d,.]+)?\s*(cm|mm)?"#
        if let g = firstMatch(p1, in: text), g.count > 1,
           let v = Double(g[1].replacingOccurrences(of: ",", with: ".")) {
            let unit = g.count > 2 ? g[2].lowercased() : ""
            return unit == "cm" ? v * 10 : v
        }
        // "8 mm" ou "2,5 cm"
        let p2 = #"\b([\d,.]+)\s*(mm|milímetros?|cm|cent[ií]metros?)\b"#
        if let g = firstMatch(p2, in: text), g.count > 2,
           let v = Double(g[1].replacingOccurrences(of: ",", with: ".")) {
            let unit = g[2].lowercased()
            let isCm = unit.hasPrefix("cm") || unit.hasPrefix("cent")
            return isCm ? v * 10 : v
        }
        return nil
    }

    // MARK: - DistMamilo

    private static func extractDistMamilo(_ text: String) -> Double? {
        let patterns = [
            #"distando\s+[\d,.]+\s*cm.*?e\s+([\d,.]+)\s*cm\s+(?:até o mamilo|do mamilo|ao mamilo)"#,
            #"distando\s+([\d,.]+)\s*cm\s+(?:até o mamilo|do mamilo|ao mamilo)"#,
            #"([\d,.]+)\s*cm\s+(?:até o mamilo|do mamilo|ao mamilo)"#,
            #"a\s+([\d,.]+)\s*cm\s+d[oe]\s+mamilo"#,
        ]
        for p in patterns {
            if let g = firstMatch(p, in: text), g.count > 1,
               let v = Double(g[1].replacingOccurrences(of: ",", with: ".")) {
                return v
            }
        }
        return nil
    }

    // MARK: - Linhas

    /// Aceita "Imagem", "Imagens", "imagen", "image" — o regex `imagens?\b` da web era
    /// interpretado como `imagen + s?` e NÃO matchava "Imagem" singular.
    private static func isFindingLine(_ text: String) -> Bool {
        regexMatches(#"\b(nódulo|nodulo|nódulos|nodulos|cisto|cistos|imagem|imagens|image|formação|formações|formacao|formacoes|lesão|lesões|lesao|lesoes|área\s+focal|area\s+focal|foco\b|achado|altera[çc][aã]o\s+focal|massa|espessamento\s+focal|opacidade)\b"#, in: text)
    }

    /// Apenas o header "CONCLUSÃO:". Linhas seguintes a esse header são puladas via state `inConclusion`.
    private static func isConclusionHeader(_ text: String) -> Bool {
        regexMatches(#"^(?:conclus[aã]o|birads|bi-rads|\d+\.?\s*birads|impress[aã]o\s+diagn[oó]stica|parecer)"#, in: text)
    }

    /// Detecta frases descrevendo linfonodos axilares (NÃO mamários):
    /// "nas axilas", "na axila", "região axilar", "em axila" etc.
    /// Ignora se a linha também menciona "mama" (caso de "prolongamento axilar da mama").
    private static func isAxillaryFinding(_ text: String) -> Bool {
        let mentionsAxillary = regexMatches(#"\b(?:nas?\s+axilas?|regi[aã]o\s+axilar(?:es)?|em\s+(?:regi[aã]o\s+)?axilar?)\b"#, in: text)
        guard mentionsAxillary else { return false }
        let mentionsBreast = regexMatches(#"\bmama\b"#, in: text)
        return !mentionsBreast
    }

    // MARK: - Dedupe

    private static func deduplicate(_ findings: [BreastFinding]) -> [BreastFinding] {
        var unique: [BreastFinding] = []
        for f in findings {
            let isDup = unique.contains { u in
                guard u.side == f.side, u.type == f.type,
                      let uh = u.hora, let fh = f.hora else { return false }
                return abs(uh - fh) <= 1
            }
            if !isDup { unique.append(f) }
        }
        return unique
    }

    // MARK: - Regex helpers

    /// Retorna `[match completo, group1, group2, ...]` no primeiro match — ou `nil`.
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
