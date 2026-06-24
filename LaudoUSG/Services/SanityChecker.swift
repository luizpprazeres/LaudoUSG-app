import Foundation

struct LocalSanityIssue: Identifiable, Sendable, Hashable {
    var id: String { code }
    let code: String
    let severity: String
    let message: String
    let range: String?
}

enum SanityChecker {
    static func check(text: String, category: ReportCategory) -> [LocalSanityIssue] {
        var issues: [LocalSanityIssue] = []

        issues.append(contentsOf: checkPlaceholders(in: text))
        issues.append(contentsOf: checkMeasurementMagnitude(in: text))
        issues.append(contentsOf: checkLaterality(in: text))
        issues.append(contentsOf: checkDates(in: text))

        return issues
    }

    private static func checkPlaceholders(in text: String) -> [LocalSanityIssue] {
        matches(
            pattern: #"____|\{LINHA_[A-Z_]+\}|\{CONCLUSAO_[A-Z_]+\}"#,
            in: text
        ).map { match in
            LocalSanityIssue(
                code: "placeholder_vazado",
                severity: "critical",
                message: "Placeholder de template apareceu no laudo.",
                range: match
            )
        }
    }

    private static func checkMeasurementMagnitude(in text: String) -> [LocalSanityIssue] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(\d+(?:[,.]\d+)?)\s*(cm³|cm3|mm³|mm3|ml|mL|mm|cm)\b"#,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { result in
            guard
                let matchRange = Range(result.range, in: text),
                let valueRange = Range(result.range(at: 1), in: text),
                let unitRange = Range(result.range(at: 2), in: text)
            else {
                return nil
            }

            let rawValue = String(text[valueRange]).replacingOccurrences(of: ",", with: ".")
            let unit = String(text[unitRange]).lowercased()
            guard unit == "cm", (Double(rawValue) ?? 0) > 99 else { return nil }

            return LocalSanityIssue(
                code: "medida_magnitude_estranha",
                severity: "warning",
                message: "Medida em centímetros com magnitude improvável para ultrassonografia.",
                range: String(text[matchRange])
            )
        }
    }

    private static func checkLaterality(in text: String) -> [LocalSanityIssue] {
        let separators = ["\n\n", "comparativo", "bilateral", "respectivamente", "direito:", "esquerdo:"]
        let lower = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let words = lower.split { !$0.isLetter }.map(String.init)
        var issues: [LocalSanityIssue] = []

        for index in words.indices where words[index] == "direito" || words[index] == "direita" {
            let end = min(words.count, index + 8)
            let windowWords = words[index..<end]
            guard windowWords.contains("esquerdo") || windowWords.contains("esquerda") else { continue }

            let windowText = windowWords.joined(separator: " ")
            guard !separators.contains(where: { lower.contains($0) }) else { continue }

            issues.append(
                LocalSanityIssue(
                    code: "lateralidade_inconsistente",
                    severity: "warning",
                    message: "Lateralidades direita e esquerda aparecem muito próximas sem separador claro.",
                    range: windowText
                )
            )
            break
        }

        return issues
    }

    private static func checkDates(in text: String) -> [LocalSanityIssue] {
        matches(pattern: #"\b(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})\b"#, in: text).compactMap { match in
            let parts = match.split(separator: "/").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            let day = parts[0], month = parts[1]
            let year = parts[2] < 100 ? 2000 + parts[2] : parts[2]
            // #10: valida dias reais do mês (pega 31/04, 29/02 não-bissexto etc.)
            guard !isValidCalendarDate(day: day, month: month, year: year) else { return nil }

            return LocalSanityIssue(
                code: "data_invalida",
                severity: "warning",
                message: "Data com dia ou mês inválido.",
                range: match
            )
        }
    }

    private static func isValidCalendarDate(day: Int, month: Int, year: Int) -> Bool {
        guard month >= 1, month <= 12, day >= 1 else { return false }
        let leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
        let daysInMonth = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return day <= daysInMonth[month - 1]
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { result in
            guard let matchRange = Range(result.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }
}
