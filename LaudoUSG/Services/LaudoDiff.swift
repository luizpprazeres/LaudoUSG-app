import Foundation

/// Diferença entre duas versões do laudo, para a prévia do "Ajustar laudo".
///
/// Calculada NO APP (LCS por linha + LCS por palavra dentro de cada linha trocada)
/// para destacar exatamente o que mudou. Não depende de `changed_lines` do
/// servidor — as duas contas são independentes e a do app é a que o médico vê.
enum LaudoDiff {
    struct Token: Equatable {
        let text: String
        let changed: Bool
    }

    struct Change: Equatable, Identifiable {
        enum Kind: Equatable { case replaced, inserted, removed }

        let id: Int
        let kind: Kind
        /// Linha (1-based) no texto antigo; nas inserções, a do texto novo.
        let line: Int
        let before: [Token]
        let after: [Token]

        var beforeText: String { before.map(\.text).joined() }
        var afterText: String { after.map(\.text).joined() }
    }

    static func changes(from old: String, to new: String) -> [Change] {
        let oldLines = normalize(old)
        let newLines = normalize(new)
        let ops = lcsOps(oldLines, newLines)

        var result: [Change] = []
        var removed: [(Int, String)] = []
        var inserted: [(Int, String)] = []

        func flush() {
            let paired = min(removed.count, inserted.count)
            for i in 0..<paired {
                let (oldIndex, before) = removed[i]
                let (_, after) = inserted[i]
                let words = wordDiff(before, after)
                result.append(Change(id: result.count, kind: .replaced, line: oldIndex + 1, before: words.before, after: words.after))
            }
            for (oldIndex, before) in removed.dropFirst(paired) {
                result.append(Change(id: result.count, kind: .removed, line: oldIndex + 1, before: [Token(text: before, changed: true)], after: []))
            }
            for (newIndex, after) in inserted.dropFirst(paired) {
                result.append(Change(id: result.count, kind: .inserted, line: newIndex + 1, before: [], after: [Token(text: after, changed: true)]))
            }
            removed.removeAll()
            inserted.removeAll()
        }

        for op in ops {
            switch op {
            case .equal:
                flush()
            case .delete(let index):
                removed.append((index, oldLines[index]))
            case .insert(let index):
                inserted.append((index, newLines[index]))
            }
        }
        flush()
        // Linha em branco que entra ou sai sozinha (renumeração da conclusão) não
        // é informação para o médico.
        return result
            .filter { !($0.beforeText.trimmingCharacters(in: .whitespaces).isEmpty && $0.afterText.trimmingCharacters(in: .whitespaces).isEmpty) }
            .enumerated()
            .map { Change(id: $0.offset, kind: $0.element.kind, line: $0.element.line, before: $0.element.before, after: $0.element.after) }
    }

    /// Proposta RECUSADA pelo servidor: o texto editado não volta (vem o original),
    /// só as linhas trocadas. Serve para mostrar o que a IA tentou, nunca para aplicar.
    static func proposal(from changedLines: [EditReportChangedLine]) -> [Change] {
        changedLines.enumerated().compactMap { offset, line in
            let before = line.before ?? ""
            let after = line.after ?? ""
            if before.trimmingCharacters(in: .whitespaces).isEmpty && after.trimmingCharacters(in: .whitespaces).isEmpty {
                return nil
            }
            if line.before == nil {
                return Change(id: offset, kind: .inserted, line: line.line, before: [], after: [Token(text: after, changed: true)])
            }
            if line.after == nil {
                return Change(id: offset, kind: .removed, line: line.line, before: [Token(text: before, changed: true)], after: [])
            }
            let words = wordDiff(before, after)
            return Change(id: offset, kind: .replaced, line: line.line, before: words.before, after: words.after)
        }
    }

    // MARK: - Implementação

    private enum Op: Equatable {
        case equal
        case delete(Int)
        case insert(Int)
    }

    private static func normalize(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
    }

    private static func lcsOps<T: Equatable>(_ a: [T], _ b: [T]) -> [Op] {
        let n = a.count
        let m = b.count
        guard n > 0 || m > 0 else { return [] }
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
                }
            }
        }
        var ops: [Op] = []
        var i = 0
        var j = 0
        while i < n && j < m {
            if a[i] == b[j] {
                ops.append(.equal)
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                ops.append(.delete(i))
                i += 1
            } else {
                ops.append(.insert(j))
                j += 1
            }
        }
        while i < n { ops.append(.delete(i)); i += 1 }
        while j < m { ops.append(.insert(j)); j += 1 }
        return ops
    }

    /// Palavras com o espaço que as segue, para a reconstrução ficar idêntica.
    private static func words(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSpace = false
        for character in line {
            let isSpace = character == " " || character == "\t"
            if isSpace {
                current.append(character)
                inSpace = true
            } else {
                if inSpace {
                    tokens.append(current)
                    current = ""
                    inSpace = false
                }
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func wordDiff(_ before: String, _ after: String) -> (before: [Token], after: [Token]) {
        let a = words(before)
        let b = words(after)
        let key: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        let ops = lcsOps(a.map(key), b.map(key))
        var beforeTokens: [Token] = []
        var afterTokens: [Token] = []
        var i = 0
        var j = 0
        for op in ops {
            switch op {
            case .equal:
                beforeTokens.append(Token(text: a[i], changed: false))
                afterTokens.append(Token(text: b[j], changed: false))
                i += 1
                j += 1
            case .delete:
                beforeTokens.append(Token(text: a[i], changed: true))
                i += 1
            case .insert:
                afterTokens.append(Token(text: b[j], changed: true))
                j += 1
            }
        }
        return (merge(beforeTokens), merge(afterTokens))
    }

    /// Junta tokens vizinhos do mesmo tipo — o destaque fica em blocos legíveis.
    private static func merge(_ tokens: [Token]) -> [Token] {
        var merged: [Token] = []
        for token in tokens {
            if let last = merged.last, last.changed == token.changed {
                merged[merged.count - 1] = Token(text: last.text + token.text, changed: last.changed)
            } else {
                merged.append(token)
            }
        }
        return merged
    }
}
