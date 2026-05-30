import Foundation

enum Sex: String, Codable, Sendable, Hashable, CaseIterable {
    case male
    case female
    case unisex

    var displayName: String {
        switch self {
        case .male: "masculino"
        case .female: "feminino"
        case .unisex: "não informado"
        }
    }
}

enum SexDetector {
    static func detect(_ text: String) -> Sex {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unisex
        }

        let negative = firstRange(
            in: text,
            pattern: #"\b(sem\s+genit[aá]lia\s+vis[ií]vel|genit[aá]lia\s+n[aã]o\s+visualizada)\b"#
        )
        let male = firstRange(
            in: text,
            pattern: #"\b(genit[aá]lia(\s+externa)?\s+masculina|sexo\s+masculino|saco\s+escrotal|p[eê]nis\s+fetal|test[ií]culos?\s+vis[ií]veis|fet[oa]\s+do\s+sexo\s+masculino)\b"#
        )
        let female = firstRange(
            in: text,
            pattern: #"\b(genit[aá]lia(\s+externa)?\s+feminina|sexo\s+feminino|grandes?\s+l[aá]bios|ov[aá]rios?\s+fetais|fet[oa]\s+do\s+sexo\s+feminino)\b"#
        )

        if let negative, let match = earliest(male, female), negative.lowerBound <= match.lowerBound {
            return .unisex
        }
        if let male, let female {
            return male.lowerBound < female.lowerBound ? .male : .female
        }
        if male != nil { return .male }
        if female != nil { return .female }
        return .unisex
    }

    private static func firstRange(in text: String, pattern: String) -> Range<String.Index>? {
        text.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]
        )
    }

    private static func earliest(
        _ lhs: Range<String.Index>?,
        _ rhs: Range<String.Index>?
    ) -> Range<String.Index>? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): lhs.lowerBound < rhs.lowerBound ? lhs : rhs
        case let (lhs?, nil): lhs
        case let (nil, rhs?): rhs
        case (nil, nil): nil
        }
    }
}
