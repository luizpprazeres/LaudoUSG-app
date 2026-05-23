import Foundation

public struct DopplerFindings: Sendable, Equatable {
    public var ig: GestationalAge?
    public var uterinaDireitaIP: Double?
    public var uterinaEsquerdaIP: Double?
    public var uterinasMediaIP: Double?
    public var umbilicalIP: Double?
    public var cerebralMediaIP: Double?
    public var ductoVenoso: DuctoVenosoFlow?

    public init(
        ig: GestationalAge? = nil,
        uterinaDireitaIP: Double? = nil,
        uterinaEsquerdaIP: Double? = nil,
        uterinasMediaIP: Double? = nil,
        umbilicalIP: Double? = nil,
        cerebralMediaIP: Double? = nil,
        ductoVenoso: DuctoVenosoFlow? = nil
    ) {
        self.ig = ig
        self.uterinaDireitaIP = uterinaDireitaIP
        self.uterinaEsquerdaIP = uterinaEsquerdaIP
        self.uterinasMediaIP = uterinasMediaIP
        self.umbilicalIP = umbilicalIP
        self.cerebralMediaIP = cerebralMediaIP
        self.ductoVenoso = ductoVenoso
    }
}

public enum DuctoVenosoFlow: Sendable, Equatable {
    case ondaAPresente
    case ondaANegativa
    case ondaAPositiva
}

public struct GestationalAge: Sendable, Equatable {
    public let weeks: Int
    public let days: Int
    public let source: IGSource

    public init(weeks: Int, days: Int, source: IGSource) {
        self.weeks = weeks
        self.days = days
        self.source = source
    }
}

public enum IGSource: Sendable, Equatable {
    case dum
    case primeiraUSG
    case biometria
    case textual
}

public enum DopplerParser {
    public static func parse(achados: String, today: Date = Date()) -> DopplerFindings {
        DopplerFindings(
            ig: parseGestationalAge(in: achados, today: today),
            uterinaDireitaIP: parseUterinaDireitaIP(in: achados),
            uterinaEsquerdaIP: parseUterinaEsquerdaIP(in: achados),
            uterinasMediaIP: parseUterinasMediaIP(in: achados),
            umbilicalIP: parseUmbilicalIP(in: achados),
            cerebralMediaIP: parseCerebralMediaIP(in: achados),
            ductoVenoso: parseDuctoVenoso(in: achados)
        )
    }

    /// Extrai a data da DUM do input livre. Reusa o mesmo parser interno
    /// usado pelo `parse(achados:)`. Útil pra atalhos que precisam da Date
    /// original (não da IG calculada).
    public static func extractDUM(achados: String) -> Date? {
        parseDUM(in: achados)
    }

    private static func parseGestationalAge(in text: String, today: Date) -> GestationalAge? {
        if let dum = parseDUM(in: text),
           let result = GestationalAgeCalculator.calcByDUM(dum: dum, today: today) {
            return GestationalAge(weeks: result.weeks, days: result.days, source: .dum)
        }

        if let primeiraUSG = parsePrimeiraUSG(in: text),
           let result = GestationalAgeCalculator.calcByUSG(
               usgDate: primeiraUSG.date,
               usgWeeks: primeiraUSG.weeks,
               usgDays: primeiraUSG.days,
               today: today
           ) {
            return GestationalAge(weeks: result.weeks, days: result.days, source: .primeiraUSG)
        }

        if let biometria = parseBiometria(in: text) {
            return biometria
        }

        return parseTextualIG(in: text)
    }

    private static func parseDUM(in text: String) -> Date? {
        if let match = text.firstMatch(
            of: /(?i)\bdum(?:\s+em)?\s*[:\-]?\s*(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})/
        ) {
            return makeDate(
                day: Int(match.1),
                month: Int(match.2),
                year: normalizedYear(String(match.3))
            )
        }

        guard let match = text.firstMatch(
            of: /(?i)\bdum(?:\s+em)?\s*[:\-]?\s*(\d{1,2})\s+de\s+(\p{L}+)\s+de\s+(\d{4})/
        ) else {
            return nil
        }

        return makeDate(
            day: Int(match.1),
            month: monthNumber(from: String(match.2)),
            year: Int(match.3)
        )
    }

    private static func parsePrimeiraUSG(in text: String) -> (weeks: Int, days: Int, date: Date)? {
        guard let match = text.firstMatch(
            of: /(?is)\b(?:1[ªa]?\s*usg|primeira\s+usg?|primeira\s+us)\b\s*[:\-]?\s*(?:ig\s*)?(\d{1,2})\s*(?:s|semanas?)(?:\s*(?:e\s*)?(\d)\s*(?:d|dias?))?.*?\bem\s+(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})/
        ),
        let weeks = Int(match.1),
        let day = Int(match.3),
        let month = Int(match.4),
        let date = makeDate(day: day, month: month, year: normalizedYear(String(match.5))) else {
            return nil
        }

        let days = match.2.flatMap { Int($0) } ?? 0
        guard (0...6).contains(days) else { return nil }
        return (weeks, days, date)
    }

    private static func parseBiometria(in text: String) -> GestationalAge? {
        guard let match = text.firstMatch(
            of: /(?i)\b(?:cf|fl|f[eê]mur)\b\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(mm|cm)?/
        ),
        let value = decimalValue(from: String(match.1)) else {
            return nil
        }

        let unit = match.2.map { String($0).lowercased() }
        let femurLengthInCentimeters = unit == "mm" || value > 20 ? value / 10 : value

        guard femurLengthInCentimeters > 0 else { return nil }

        // Hadlock 1984 FL dating formula: GA weeks = 10.35 + 2.46 * FL(cm) + 0.17 * FL(cm)^2.
        let weeksDecimal = 10.35
            + 2.46 * femurLengthInCentimeters
            + 0.17 * femurLengthInCentimeters * femurLengthInCentimeters
        let totalDays = Int((weeksDecimal * 7).rounded())

        return GestationalAge(weeks: totalDays / 7, days: totalDays % 7, source: .biometria)
    }

    private static func parseTextualIG(in text: String) -> GestationalAge? {
        if let match = text.firstMatch(
            of: /(?i)\b(\d{1,2})\s*s(?:em(?:anas?)?)?\s*(\d)\s*d\b/
        ),
        let weeks = Int(match.1),
        let days = Int(match.2),
        (0...6).contains(days) {
            return GestationalAge(weeks: weeks, days: days, source: .textual)
        }

        guard let match = text.firstMatch(
            of: /(?i)\b(\d{1,2})\s*(?:semanas?|sem|s)\b(?:\s*(?:e\s*)?(\d)\s*(?:dias?|d)\b)?/
        ),
        let weeks = Int(match.1) else {
            return nil
        }

        let days = match.2.flatMap { Int($0) } ?? 0
        guard (0...6).contains(days) else { return nil }
        return GestationalAge(weeks: weeks, days: days, source: .textual)
    }

    private static func parseUmbilicalIP(in text: String) -> Double? {
        guard let match = text.firstMatch(
            of: /(?i)\b(?:au|art[eé]ria\s+umbilical|umbilical)\b(?:\s+(?:ip|pulsatilidade))?\s*[:=]?\s*(\d+(?:[.,]\d+)?)/
        ) else {
            return nil
        }

        return decimalValue(from: String(match.1))
    }

    private static func parseCerebralMediaIP(in text: String) -> Double? {
        guard let match = text.firstMatch(
            of: /(?i)\b(?:acm|art[eé]ria\s+cerebral\s+m[eé]dia|cerebral\s+m[eé]di[ao])\b(?:\s+ip)?\s*[:=]?\s*(\d+(?:[.,]\d+)?)/
        ) else {
            return nil
        }

        return decimalValue(from: String(match.1))
    }

    private static func parseUterinaDireitaIP(in text: String) -> Double? {
        if let match = text.firstMatch(
            of: /(?i)\buterinas?\s*(?:direita|dir)\b(?:\s+ip)?\s*[:=]?\s*(\d+(?:[.,]\d+)?)/
        ) {
            return decimalValue(from: String(match.1))
        }

        guard let match = text.firstMatch(
            of: /(?i)\buterinas?\s*[:\-]?\s*d(?:ir(?:eita)?)?\s*[:=]?\s*(\d+(?:[.,]\d+)?)/
        ) else {
            return nil
        }

        return decimalValue(from: String(match.1))
    }

    private static func parseUterinaEsquerdaIP(in text: String) -> Double? {
        if let match = text.firstMatch(
            of: /(?i)\buterinas?\s*(?:esquerda|esq)\b(?:\s+ip)?\s*[:=]?\s*(\d+(?:[.,]\d+)?)/
        ) {
            return decimalValue(from: String(match.1))
        }

        guard let match = text.firstMatch(
            of: /(?i)\buterinas?\s*[:\-]?\s*e(?:sq(?:uerda)?)?\s*[:=]?\s*(\d+(?:[.,]\d+)?)/
        ) else {
            return nil
        }

        return decimalValue(from: String(match.1))
    }

    private static func parseUterinasMediaIP(in text: String) -> Double? {
        guard let match = text.firstMatch(
            of: /(?i)\b(?:uterinas?\s+m[eé]dia|m[eé]dia\s+(?:das\s+)?uterinas?)\b(?:\s+ip)?\s*[:=]?\s*(\d+(?:[.,]\d+)?)/
        ) else {
            return nil
        }

        return decimalValue(from: String(match.1))
    }

    private static func parseDuctoVenoso(in text: String) -> DuctoVenosoFlow? {
        guard let match = text.firstMatch(
            of: /(?is)\bducto\s+venoso\b.*?\bonda\s+a\b\s*[:\-]?\s*(presente|negativa|positiva|ausente|reversa)\b/
        ) else {
            return nil
        }

        switch String(match.1).lowercased() {
        case "presente":
            return .ondaAPresente
        case "positiva":
            return .ondaAPositiva
        case "negativa", "ausente", "reversa":
            return .ondaANegativa
        default:
            return nil
        }
    }

    private static func decimalValue(from capture: String) -> Double? {
        Double(capture.replacingOccurrences(of: ",", with: "."))
    }

    private static func normalizedYear(_ capture: String) -> Int? {
        guard let year = Int(capture) else { return nil }
        return capture.count == 2 ? 2000 + year : year
    }

    private static func makeDate(day: Int?, month: Int?, year: Int?) -> Date? {
        guard let day, let month, let year else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        return calendar.date(from: components)
    }

    private static func monthNumber(from text: String) -> Int? {
        switch text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR")).lowercased() {
        case "janeiro": return 1
        case "fevereiro": return 2
        case "marco": return 3
        case "abril": return 4
        case "maio": return 5
        case "junho": return 6
        case "julho": return 7
        case "agosto": return 8
        case "setembro": return 9
        case "outubro": return 10
        case "novembro": return 11
        case "dezembro": return 12
        default: return nil
        }
    }
}
