import SwiftUI

extension String {
    /// Retorna o texto com placeholders `____` (4 ou mais underscores) destacados
    /// em "hidrocor" roxo — efeito visual de "ponto a revisar" no laudo gerado.
    ///
    /// Detecta sequências de 4+ underscores e aplica background roxo claro +
    /// texto roxo escuro. Funciona em qualquer `Text` que aceite `AttributedString`.
    ///
    /// Exemplo:
    ///   "DBP de ____ mm" → "DBP de ____ mm" (com ____ destacado em roxo)
    var laudoHighlighted: AttributedString {
        var attr = AttributedString(self)

        // Swift Regex (iOS 16+) — detecta 4+ underscores consecutivos
        let regex = /_{4,}/

        // Itera matches de trás pra frente pra não invalidar offsets
        let matchesArray = Array(self.matches(of: regex))
        for match in matchesArray.reversed() {
            let nsRange = NSRange(match.range, in: self)
            guard let utf16Lower = self.utf16.index(self.utf16.startIndex, offsetBy: nsRange.location, limitedBy: self.utf16.endIndex),
                  let utf16Upper = self.utf16.index(utf16Lower, offsetBy: nsRange.length, limitedBy: self.utf16.endIndex),
                  let attrLower = AttributedString.Index(utf16Lower, within: attr),
                  let attrUpper = AttributedString.Index(utf16Upper, within: attr) else {
                continue
            }
            let attrRange = attrLower..<attrUpper

            // Hidrocor: background roxo claro + texto roxo escuro + sublinhado sutil
            // Cor escolhida: violet/purple no tom médico (não muito vibrante)
            attr[attrRange].backgroundColor = Color(hex: "EDE9FE") // violet-100 — fundo
            attr[attrRange].foregroundColor = Color(hex: "6D28D9") // violet-700 — texto
        }

        return attr
    }
}
