import Foundation

/// Uma sugestão do `/api/ditado/revisar` (opção D do estudo de transcrição de 12/10/2026).
/// `start`/`end` são posições UTF-16 no texto enviado (o padrão do servidor em JavaScript).
struct DitadoSuggestion: Decodable, Hashable, Identifiable, Sendable {
    let start: Int
    let end: Int
    let original: String
    /// nil = só aviso ("confira esta medida").
    let replacement: String?
    /// negacao | centena | escala | grafia | medida
    let kind: String
    let confidence: Double
    /// true = troca segura, entra sozinha (com desfazer).
    let automatic: Bool

    var id: String { "\(kind)|\(start)|\(original)" }
    /// Chave estável para não sugerir de novo o que o médico já recusou.
    var dismissKey: String { "\(kind)|\(original.lowercased())|\(replacement ?? "")" }
}

struct DitadoReviewResponse: Decodable, Sendable {
    let enabled: Bool
    let suggestions: [DitadoSuggestion]
}

/// O que a faixa "Revisão do ditado" mostra.
struct DitadoReviewState: Equatable, Sendable {
    struct Applied: Hashable, Identifiable, Sendable {
        let id: String
        let original: String
        let replacement: String
        var start: Int
        /// Desfeita, não volta a ser aplicada na próxima revisão.
        let dismissKey: String
        /// "formato" (número/medida/unidade) aparece agrupado numa linha só.
        var kind: String = ""
    }
    var applied: [Applied] = []
    var pending: [DitadoSuggestion] = []
    var warnings: [DitadoSuggestion] = []
    var uncertainWords: [String] = []

    var isEmpty: Bool { applied.isEmpty && pending.isEmpty && warnings.isEmpty && uncertainWords.isEmpty }
    /// Trocas de formato (número/medida) — uma linha só na faixa.
    var formatted: [Applied] { applied.filter { $0.kind == "formato" } }
    /// Demais correções automáticas, uma linha cada.
    var corrected: [Applied] { applied.filter { $0.kind != "formato" } }
    var toReviewCount: Int { pending.count + warnings.count }
}

enum DitadoReviewEngine {
    /// Aplica as trocas automáticas (de trás para frente, conferindo o trecho) e separa o resto.
    static func apply(
        _ suggestions: [DitadoSuggestion],
        to text: String,
        uncertainWords: [String],
        dismissed: Set<String> = []
    ) -> (text: String, state: DitadoReviewState) {
        var out = text as NSString
        var state = DitadoReviewState()
        let fresh = suggestions.filter { !dismissed.contains($0.dismissKey) }
        let autos = fresh
            .filter { $0.automatic && $0.replacement != nil }
            .sorted { $0.start > $1.start }
        var deltas: [(at: Int, delta: Int)] = []
        for s in autos {
            let range = NSRange(location: s.start, length: s.end - s.start)
            guard s.start >= 0, s.end <= out.length, s.end > s.start,
                  out.substring(with: range) == s.original,
                  let rep = s.replacement else { continue }
            out = out.replacingCharacters(in: range, with: rep) as NSString
            deltas.append((s.start, (rep as NSString).length - (s.original as NSString).length))
            state.applied.append(.init(id: s.id, original: s.original, replacement: rep, start: s.start, dismissKey: s.dismissKey, kind: s.kind))
        }
        // as trocas foram de trás para frente: as posições anteriores continuam valendo,
        // mas as sugestões depois de uma troca andam o tamanho da diferença
        func shifted(_ p: Int) -> Int { p + deltas.filter { $0.at < p }.reduce(0) { $0 + $1.delta } }
        state.applied = state.applied.map { var a = $0; a.start = shifted(a.start); return a }.sorted { $0.start < $1.start }
        for s in fresh where !s.automatic || s.replacement == nil {
            let moved = DitadoSuggestion(start: shifted(s.start), end: shifted(s.end), original: s.original,
                                         replacement: s.replacement, kind: s.kind, confidence: s.confidence, automatic: false)
            if s.replacement == nil { state.warnings.append(moved) } else { state.pending.append(moved) }
        }
        let current = out as String
        state.uncertainWords = uncertainWords.filter { current.localizedCaseInsensitiveContains($0) }
        return (current, state)
    }

    /// Trecho legível para a linha da sugestão: o original + até 3 palavras seguintes, e o mesmo com a troca.
    /// Ex.: “6 sinais de colecistite” → “sem sinais de colecistite”.
    static func phrase(original: String, replacement: String?, near: Int, in text: String) -> (from: String, to: String?) {
        let ns = text as NSString
        guard let r = closest(of: original, in: ns, near: near) else { return (original, replacement) }
        let tailStart = r.location + r.length
        let rest = ns.substring(from: tailStart)
        let words = rest.split(separator: " ", omittingEmptySubsequences: true).prefix(3)
        var tail = words.joined(separator: " ")
        if let cut = tail.firstIndex(where: { ".;\n".contains($0) }) { tail = String(tail[..<cut]) }
        let sep = tail.isEmpty || rest.first == " " ? (tail.isEmpty ? "" : " ") : ""
        return (original + sep + tail, replacement.map { $0 + sep + tail })
    }

    private static func closest(of original: String, in ns: NSString, near: Int) -> NSRange? {
        var best: NSRange?
        var search = NSRange(location: 0, length: ns.length)
        while true {
            let r = ns.range(of: original, options: [], range: search)
            if r.location == NSNotFound { break }
            if best == nil || abs(r.location - near) < abs(best!.location - near) { best = r }
            let next = r.location + max(r.length, 1)
            if next >= ns.length { break }
            search = NSRange(location: next, length: ns.length - next)
        }
        return best
    }

    /// Troca `original` pela ocorrência mais perto de `near` (o texto pode ter andado). nil se sumiu.
    static func replaceNear(in text: String, original: String, with replacement: String, near: Int) -> String? {
        let ns = text as NSString
        guard let best = closest(of: original, in: ns, near: near) else { return nil }
        return ns.replacingCharacters(in: best, with: replacement)
    }
}

/// Chamada ao servidor. Qualquer falha = nenhuma sugestão (o ditado segue como está).
enum DitadoReviewService {
    private struct Body: Encodable { let texto: String; let categoria: String? }

    static func review(text: String, category: ReportCategory) async -> [DitadoSuggestion] {
        do {
            let r = try await APIClient.shared.post(
                "/api/ditado/revisar",
                body: Body(texto: text, categoria: category.rawValue),
                as: DitadoReviewResponse.self
            )
            return r.enabled ? r.suggestions : []
        } catch {
            return []
        }
    }
}
