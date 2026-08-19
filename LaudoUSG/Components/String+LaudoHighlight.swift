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

    /// Versão para EXIBIÇÃO (modo leitura): destaca as LINHAS que pedem atenção,
    /// com DUAS cores, porque são dois problemas diferentes.
    ///
    /// - **roxo** — falta um dado (`____`). O laudo está incompleto.
    /// - **âmbar** — há algo divergente (`[REVISAR — ...]`). O dado existe, mas o
    ///   sistema desconfia dele.
    ///
    /// Enquanto as duas compartilhavam o roxo, o médico via "falta alguma coisa"
    /// numa frase completa e ia procurar o que não estava faltando — aconteceu em
    /// 19/08, na frase da 1ª ultrassonografia. A cor precisa dizer o que fazer:
    /// roxo, preencher; âmbar, conferir.
    ///
    /// Havendo os dois na mesma linha, o âmbar vence: uma divergência ativa pesa
    /// mais que uma lacuna, e a lacuna continua visível no próprio `____`.
    ///
    /// O marcador verboso vira um "(?)" discreto (some sozinho ao copiar/enviar).
    var laudoHighlighted: AttributedString {
        var result = AttributedString("")
        let lines = self.components(separatedBy: "\n")

        for (i, line) in lines.enumerated() {
            let hasPlaceholder = line.contains("____")   // falta o dado
            let hasReview = line.contains("[REVISAR")    // o dado é duvidoso

            // Marcador verboso → "(?)" discreto na exibição.
            let displayLine = hasReview
                ? line.replacing(String.reviewMarker, with: " (?)")
                : line

            var attrLine = AttributedString(displayLine)
            if hasReview {
                // Âmbar: fundo amber-100 + texto amber-800.
                attrLine.backgroundColor = Color(hex: "FEF3C7")
                attrLine.foregroundColor = Color(hex: "92400E")
            } else if hasPlaceholder {
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
