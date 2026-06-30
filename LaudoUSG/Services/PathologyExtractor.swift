import Foundation

struct PathologyAggregation: Identifiable {
    let id: String
    let categoryCode: String
    let totalReports: Int
    let pathologies: [(label: String, count: Int)]
}

enum PathologyExtractor {
    private struct Pattern {
        let expression: String
        let label: String
    }

    private static let patternsByCategory: [String: [Pattern]] = [
        "OBSTETRICA": [
            Pattern(expression: "oligodrâmnio|oligoâmnio", label: "Oligoâmnio"),
            Pattern(expression: "poliidrâmnio|polihidrâmnio", label: "Polidrâmnio"),
            Pattern(expression: "placenta\\s+pr[eé]via", label: "Placenta prévia"),
            Pattern(expression: "colo\\s+(?:uterino\\s+)?curto", label: "Colo uterino curto"),
            Pattern(expression: "restrição\\s+(?:de\\s+)?crescimento|ciur|rciu", label: "CIUR/RCIU"),
            Pattern(expression: "gemelar|trigemelar", label: "Gestação múltipla"),
            Pattern(expression: "descolamento\\s+(?:de\\s+)?placenta", label: "Descolamento de placenta"),
            Pattern(expression: "pr[eé]-ecl[aâ]mpsia", label: "Pré-eclâmpsia (suspeita)")
        ],
        "MORFOLOGICO": [
            Pattern(expression: "malforma[cç][aã]o", label: "Malformação fetal"),
            Pattern(expression: "hidrocefalia", label: "Hidrocefalia"),
            Pattern(expression: "fenda\\s+(?:labial|palatina)", label: "Fenda labial/palatina"),
            Pattern(expression: "gastrosquise|onfalocele", label: "Defeito de parede abdominal"),
            Pattern(expression: "restrição\\s+(?:de\\s+)?crescimento|ciur|rciu", label: "CIUR/RCIU"),
            Pattern(expression: "cardiopatia|cardíaco.*anormal|coração.*anormal", label: "Cardiopatia fetal")
        ],
        "TIREOIDE": [
            Pattern(expression: "nódulo", label: "Nódulo tireoidiano"),
            Pattern(expression: "b[oó]cio", label: "Bócio"),
            Pattern(expression: "ti-?rads\\s*[45]", label: "TI-RADS 4 ou 5"),
            Pattern(expression: "tireoidite", label: "Tireoidite"),
            Pattern(expression: "hipotireoidismo|hipertireoidismo", label: "Disfunção tireoidiana"),
            Pattern(expression: "calcifica[cç][aã]o", label: "Calcificação")
        ],
        "MAMARIA": [
            Pattern(expression: "nódulo", label: "Nódulo mamário"),
            Pattern(expression: "cisto", label: "Cisto mamário"),
            Pattern(expression: "bi-?rads\\s*[456]", label: "BI-RADS ≥ 4"),
            Pattern(expression: "microc[aá]lcif", label: "Microcalcificações"),
            Pattern(expression: "linfonodo", label: "Linfonodomegalia axilar"),
            Pattern(expression: "espiculad", label: "Lesão espiculada")
        ],
        "PELVE_FEMININA": [
            Pattern(expression: "mioma|leiomioma", label: "Mioma uterino"),
            Pattern(expression: "adenomiose", label: "Adenomiose"),
            Pattern(expression: "cisto\\s+(?:ovariano|de\\s+ov[aá]rio)", label: "Cisto ovariano"),
            Pattern(expression: "endometrioma", label: "Endometrioma"),
            Pattern(expression: "pcos|policist", label: "Ovários policísticos"),
            Pattern(expression: "hidrossalpinge", label: "Hidrossalpinge")
        ],
        "ABDOMEN_TOTAL": [
            Pattern(expression: "esteatose", label: "Esteatose hepática"),
            Pattern(expression: "litíase\\s+(?:biliar|vesicular)|cálculo.*vesícula", label: "Litíase biliar"),
            Pattern(expression: "cisto\\s+(?:hepático|renal)", label: "Cisto hepático/renal"),
            Pattern(expression: "hepatomegalia", label: "Hepatomegalia"),
            Pattern(expression: "dilatação.*biliar|via\\s+biliar.*dilat", label: "Dilatação de vias biliares"),
            Pattern(expression: "esplenomegalia", label: "Esplenomegalia")
        ],
        "VIAS_URINARIAS": [
            Pattern(expression: "litíase\\s+renal|cálculo.*renal", label: "Litíase renal"),
            Pattern(expression: "hidronefrose|pelvicaliectasia", label: "Hidronefrose"),
            Pattern(expression: "hiperplasia\\s+(?:benigna\\s+)?(?:de\\s+)?pr[oó]stata|hbp", label: "HBP"),
            Pattern(expression: "cisto\\s+renal", label: "Cisto renal"),
            Pattern(expression: "ureterolítiase", label: "Ureterolitíase")
        ],
        "DOPPLER": [
            Pattern(expression: "estenose", label: "Estenose arterial"),
            Pattern(expression: "trombose|tvp", label: "Trombose venosa"),
            Pattern(expression: "placa\\s+(?:aterosclerótica|calcificada)", label: "Placa aterosclerótica"),
            Pattern(expression: "aneurisma", label: "Aneurisma"),
            Pattern(expression: "insufici[eê]ncia\\s+venosa", label: "Insuficiência venosa")
        ],
        "DOPPLER_OBSTETRICO": [
            Pattern(expression: "ip\\s+(?:elevado|aumentado)", label: "IP elevado"),
            Pattern(expression: "di[aá]stole\\s+(?:zero|ausente)", label: "Diástole zero/ausente"),
            Pattern(expression: "di[aá]stole\\s+reversa", label: "Diástole reversa"),
            Pattern(expression: "centraliza[cç][aã]o", label: "Centralização fetal")
        ],
        "MUSCULOESQUELETICO_V2": [
            Pattern(expression: "rotura", label: "Rotura tendínea"),
            Pattern(expression: "tendinit|tendinop", label: "Tendinopatia"),
            Pattern(expression: "calcifica[cç][aã]o\\s+(?:tend[aã]o|ten)", label: "Tendinite calcificante"),
            Pattern(expression: "efus[aã]o\\s+articular", label: "Efusão articular"),
            Pattern(expression: "bursite", label: "Bursite")
        ]
    ]

    static func extract(reports: [Report]) -> [PathologyAggregation] {
        let reportsByCategory = Dictionary(grouping: reports, by: \.categoryCode)

        return reportsByCategory.compactMap { categoryCode, categoryReports in
            guard categoryReports.count >= 10, let patterns = patternsByCategory[categoryCode] else {
                return nil
            }

            var counts: [String: Int] = [:]
            for report in categoryReports {
                let text = report.displayText
                guard !text.isEmpty else { continue }
                for pattern in patterns where matches(pattern.expression, in: text) {
                    counts[pattern.label, default: 0] += 1
                }
            }

            let pathologies = counts
                .map { (label: $0.key, count: $0.value) }
                .sorted {
                    if $0.count == $1.count { return $0.label < $1.label }
                    return $0.count > $1.count
                }
                .prefix(5)

            guard !pathologies.isEmpty else { return nil }

            return PathologyAggregation(
                id: categoryCode,
                categoryCode: categoryCode,
                totalReports: categoryReports.count,
                pathologies: Array(pathologies)
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalReports == rhs.totalReports { return lhs.categoryCode < rhs.categoryCode }
            return lhs.totalReports > rhs.totalReports
        }
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
