import Foundation

/// Parser determinístico (regex pt-BR) que extrai miomas do laudo gerado →
/// gera o esquema automaticamente, igual mama/tireoide. O médico ajusta no editor.
///
/// Estratégia: separa o laudo em blocos (frases) que descrevem um mioma; por
/// bloco extrai FIGO (explícito "FIGO N" ou inferido do tipo), maior eixo,
/// localização e ecotextura. Cruza FIGO da conclusão com a descrição por ordem.
enum MyomaFindingsParser {

    static func parse(_ text: String) -> [MyomaFinding] {
        guard !text.isEmpty else { return [] }
        let explicit = explicitFigos(text)
        let blocks = miomaBlocks(text)

        var out: [MyomaFinding] = []
        for (i, b) in blocks.enumerated() {
            let figo = figoInline(b) ?? figoFromType(b) ?? (i < explicit.count ? explicit[i] : 4)
            out.append(
                MyomaFinding(
                    figo: figo,
                    sizeMaxMm: maxAxisMm(b),
                    localizacao: location(b) ?? .anterior,
                    ecotextura: echo(b)
                )
            )
        }
        // Laudo só com "categoria FIGO N" (sem descrição dimensional)? Cria deles.
        if out.isEmpty && !explicit.isEmpty {
            out = explicit.map { MyomaFinding(figo: $0) }
        }
        return out
    }

    // MARK: - Blocos

    /// Frases que descrevem um mioma (mioma/leiomioma/miomatoso, ou nódulo com
    /// tipo FIGO + medida). Dedup por (tamanho×localização) pra não contar 2x a
    /// mesma lesão citada no corpo e na conclusão.
    private static func miomaBlocks(_ text: String) -> [String] {
        let sentences = text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var described: [String] = []   // descrição COM medida (corpo) = a instância real
        var loose: [String] = []       // menciona mioma/FIGO mas sem medida (conclusão)
        for s in sentences {
            let hasMioma = match(#"mioma|leiomioma|miomatos"#, s)
            let hasTyped = match(#"intramural|submucos|subseros"#, s)
            let hasSize = maxAxisMm(s) != nil
            // Inclui a descrição do CORPO mesmo sem a palavra "mioma" (tipo + medida
            // ou tipo + nódulo/parede/miométrio).
            let isMyoma = hasMioma
                || (hasTyped && (hasSize || match(#"n[óo]dul|parede|mi[oó]metri|f[úu]ndic|cervical"#, s)))
            guard isMyoma else { continue }
            if hasSize { described.append(s) } else { loose.append(s) }
        }
        // Instâncias vêm das descrições COM medida; a conclusão (FIGO sem medida)
        // só alimenta o explicitFigos. Sem nenhuma descrição → usa as soltas.
        return described.isEmpty ? loose : described
    }

    // MARK: - Extração

    private static func explicitFigos(_ text: String) -> [Int] {
        var out: [Int] = []
        if let re = try? NSRegularExpression(pattern: #"FIGO\s*[:\-]?\s*([0-8])"#, options: [.caseInsensitive]) {
            let ns = text as NSString
            for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                if let n = Int(ns.substring(with: m.range(at: 1))) { out.append(n) }
            }
        }
        return out
    }

    private static func figoInline(_ s: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"FIGO\s*[:\-]?\s*([0-8])"#, options: [.caseInsensitive]) else { return nil }
        let ns = s as NSString
        if let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) {
            return Int(ns.substring(with: m.range(at: 1)))
        }
        return nil
    }

    /// Infere FIGO pelo tipo + modificadores (pediculado, ≥50%, contato endométrio).
    private static func figoFromType(_ s: String) -> Int? {
        let pediculado = match(#"pediculad"#, s)
        let maior = match(#"≥\s*50|maior\s+que\s+50|>\s*50|predomin[âa]ncia\s+(extra|intra)"#, s)
        if match(#"cervical|do\s+colo"#, s) { return 8 }
        if match(#"submucos"#, s) { return pediculado ? 0 : (maior ? 2 : 1) }
        if match(#"subseros"#, s) { return pediculado ? 7 : (maior ? 5 : 6) }
        if match(#"intramural"#, s) {
            return match(#"contato\s+com\s+(o\s+)?endom[ée]trio|toca\s+(a\s+)?cavidade|deformando\s+a\s+cavidade"#, s) ? 3 : 4
        }
        return nil
    }

    /// Maior eixo em mm. "medindo 2,3 x 1,8 x 2,0 cm" → 23. Também "de X cm".
    private static func maxAxisMm(_ s: String) -> Double? {
        let ns = s as NSString
        // multi-eixo: número (x|por|×) número [(x|por|×) número] (cm|mm)
        let multi = #"(\d+(?:,\d+)?)\s*(?:x|por|×)\s*(\d+(?:,\d+)?)(?:\s*(?:x|por|×)\s*(\d+(?:,\d+)?))?\s*(cm|mm)"#
        if let re = try? NSRegularExpression(pattern: multi, options: [.caseInsensitive]),
           let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) {
            var dims: [Double] = []
            for i in 1...3 where m.range(at: i).location != NSNotFound {
                dims.append(num(ns.substring(with: m.range(at: i))))
            }
            let unit = ns.substring(with: m.range(at: 4)).lowercased()
            let maxV = dims.max() ?? 0
            return unit == "cm" ? maxV * 10 : maxV
        }
        // eixo único: "medindo X cm" / "de X cm"
        let single = #"(?:medindo|de)\s+(\d+(?:,\d+)?)\s*(cm|mm)"#
        if let re = try? NSRegularExpression(pattern: single, options: [.caseInsensitive]),
           let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) {
            let v = num(ns.substring(with: m.range(at: 1)))
            let unit = ns.substring(with: m.range(at: 2)).lowercased()
            return unit == "cm" ? v * 10 : v
        }
        return nil
    }

    private static func location(_ s: String) -> MyomaLocation? {
        if match(#"parede\s+anterior|face\s+anterior|\banterior\b"#, s) { return .anterior }
        if match(#"parede\s+posterior|face\s+posterior|\bposterior\b"#, s) { return .posterior }
        if match(#"lateral\s+direita|à\s+direita|\bdireita\b"#, s) { return .lateralDireita }
        if match(#"lateral\s+esquerda|à\s+esquerda|\besquerda\b"#, s) { return .lateralEsquerda }
        if match(#"fundo\s+uterino|no\s+fundo|f[úu]ndic"#, s) { return .fundo }
        if match(#"cervical|do\s+colo"#, s) { return .cervical }
        return nil
    }

    private static func echo(_ s: String) -> MyomaEcho? {
        if match(#"calcific"#, s) { return .calcificada }
        if match(#"degener"#, s) { return .degenerada }
        if match(#"heterog"#, s) { return .heterogenea }
        if match(#"hipoec"#, s) { return .hipoecoica }
        return nil
    }

    // MARK: - Helpers

    private static func match(_ pattern: String, _ text: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        return re.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }
    private static func num(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}
