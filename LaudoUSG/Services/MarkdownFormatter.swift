import Foundation

enum MarkdownFormatter {
    private static let knownHeadingPrefixes: [String] = [
        "ULTRASSONOGRAFIA",
        "ULTRASSOM",
        "USG",
        "ECOGRAFIA",
        "ANÁLISE",
        "ANALISE",
        "TÉCNICA",
        "TECNICA",
        "COMENTÁRIOS",
        "COMENTARIOS",
        "ACHADOS",
        "OS SEGUINTES ASPECTOS",
        "CONCLUSÃO",
        "CONCLUSAO",
        "OBSERVAÇÕES",
        "OBSERVACOES",
        "AVALIAÇÃO",
        "AVALIACAO",
        "INDICAÇÃO",
        "INDICACAO",
        "PACIENTE",
        "DADOS CLÍNICOS",
        "DADOS CLINICOS"
    ]

    static func highlightHeadings(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let processed: [String] = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("**"),
                  isHeading(trimmed)
            else { return line }
            let leadingWhitespace = String(line.prefix { $0.isWhitespace })
            return "\(leadingWhitespace)**\(trimmed)**"
        }
        return processed.joined(separator: "\n")
    }

    static func removeHighlights(_ text: String) -> String {
        let pattern = #"\*\*(.+?)\*\*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "$1"
        )
    }

    private static func isHeading(_ line: String) -> Bool {
        let normalized = line.uppercased()
        if knownHeadingPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return true
        }
        if line.hasSuffix(":") {
            let withoutColon = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
            return isAllUppercase(withoutColon) && withoutColon.count >= 4
        }
        return isAllUppercase(line) && line.count >= 4
    }

    private static func isAllUppercase(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { CharacterSet.uppercaseLetters.contains($0) }
    }
}
