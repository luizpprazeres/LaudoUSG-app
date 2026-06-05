import SwiftUI

extension String {
    /// Regex dos marcadores de revisão que o LLM coloca no laudo, ex.:
    /// "[REVISAR — magnitude]", "[REVISAR — medida ambígua]",
    /// "[REVISAR — DSM requer 3 medidas...]", "[REVISAR — divergência...]".
    /// Inclui o espaço à esquerda pra remover limpo.
    private static let reviewMarker = try! Regex(#"\s*\[REVISAR\b[^\]]*\]"#)

    /// Texto do laudo SEM os marcadores `[REVISAR — ...]` — pra COPIAR / ENVIAR /
    /// SALVAR limpo, sem o médico precisar apagar à mão depois de corrigir.
    var strippedReviewMarkers: String {
        self.replacing(String.reviewMarker, with: "")
    }

    /// Versão para EXIBIÇÃO (modo leitura): destaca em roxo "hidrocor" as LINHAS
    /// que têm pontos a revisar — placeholders `____` ou marcadores `[REVISAR — ...]`.
    /// O marcador verboso vira um "(?)" discreto (some sozinho ao copiar/enviar).
    var laudoHighlighted: AttributedString {
        var result = AttributedString("")
        let lines = self.components(separatedBy: "\n")

        for (i, line) in lines.enumerated() {
            let hasPlaceholder = line.contains("____")   // placeholder de revisão
            let hasReview = line.contains("[REVISAR")

            // Marcador verboso → "(?)" discreto na exibição.
            let displayLine = hasReview
                ? line.replacing(String.reviewMarker, with: " (?)")
                : line

            var attrLine = AttributedString(displayLine)
            if hasPlaceholder || hasReview {
                // Hidrocor: fundo violet-100 + texto violet-700 (linha inteira).
                attrLine.backgroundColor = Color(hex: "EDE9FE")
                attrLine.foregroundColor = Color(hex: "6D28D9")
            }
            result.append(attrLine)
            if i < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        return result
    }
}
