import SwiftUI

extension String {
    /// Retorna o texto com LINHAS inteiras que contêm placeholders `____` (4+ underscores)
    /// destacadas em "hidrocor" roxo — efeito visual de "ponto a revisar" no laudo gerado.
    ///
    /// Destaca a LINHA inteira (não só o `____`) porque muitas vezes a palavra a revisar
    /// faz sentido no contexto da frase. Facilita revisão visual médica.
    ///
    /// Exemplo:
    ///   "DBP de ____ mm" → linha inteira em roxo
    ///   "Feto único" → sem highlight (sem placeholder)
    var laudoHighlighted: AttributedString {
        var attr = AttributedString(self)

        // Swift Regex (iOS 16+) — detecta 4+ underscores consecutivos
        let regex = /_{4,}/

        // Pra cada match, expandir o range pra LINHA INTEIRA (do \n anterior ao próximo \n)
        var lineRanges: [Range<String.Index>] = []
        for match in self.matches(of: regex) {
            let lineStart = lineStartIndex(for: match.range.lowerBound)
            let lineEnd = lineEndIndex(for: match.range.upperBound)
            lineRanges.append(lineStart..<lineEnd)
        }

        // De-duplicar linhas (múltiplos placeholders na mesma linha → 1 range só)
        // E aplicar highlight em cada linha única (ordem: de trás pra frente pra preservar índices)
        let uniqueRanges = Array(Set(lineRanges)).sorted { $0.lowerBound > $1.lowerBound }
        for lineRange in uniqueRanges {
            guard let attrLower = AttributedString.Index(lineRange.lowerBound, within: attr),
                  let attrUpper = AttributedString.Index(lineRange.upperBound, within: attr) else {
                continue
            }
            let attrRange = attrLower..<attrUpper

            // Hidrocor: background roxo claro + texto roxo escuro (linha inteira)
            attr[attrRange].backgroundColor = Color(hex: "EDE9FE") // violet-100 — fundo
            attr[attrRange].foregroundColor = Color(hex: "6D28D9") // violet-700 — texto
        }

        return attr
    }

    /// Encontra o início da linha que contém o índice dado (depois do `\n` anterior, ou início da string).
    private func lineStartIndex(for index: String.Index) -> String.Index {
        var i = index
        while i > self.startIndex {
            let prev = self.index(before: i)
            if self[prev] == "\n" { break }
            i = prev
        }
        return i
    }

    /// Encontra o fim da linha que contém o índice dado (até o próximo `\n` ou fim da string).
    private func lineEndIndex(for index: String.Index) -> String.Index {
        var i = index
        while i < self.endIndex {
            if self[i] == "\n" { break }
            i = self.index(after: i)
        }
        return i
    }
}
