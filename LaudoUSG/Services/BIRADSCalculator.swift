import Foundation

/// BI-RADS (Breast Imaging Reporting and Data System) — categorias 0-6 com
/// recomendação clínica de conduta/seguimento por categoria.
/// ACR BI-RADS 5th Edition (2013).
enum BIRADSCalculator {
    enum Category: String, Sendable, CaseIterable, Identifiable {
        case zero = "0"
        case um = "1"
        case dois = "2"
        case tres = "3"
        case quatroA = "4A"
        case quatroB = "4B"
        case quatroC = "4C"
        case cinco = "5"
        case seis = "6"

        var id: String { rawValue }
        var label: String { "BI-RADS \(rawValue)" }

        var descricao: String {
            switch self {
            case .zero: return "Avaliação incompleta — necessária avaliação complementar"
            case .um: return "Negativo"
            case .dois: return "Achados benignos"
            case .tres: return "Provavelmente benigno"
            case .quatroA: return "Suspeita baixa de malignidade"
            case .quatroB: return "Suspeita moderada de malignidade"
            case .quatroC: return "Suspeita alta de malignidade"
            case .cinco: return "Altamente sugestivo de malignidade"
            case .seis: return "Malignidade comprovada por biópsia"
            }
        }

        var recomendacao: String {
            switch self {
            case .zero: return "Recomenda-se avaliação por imagem complementar (mamografia, ressonância ou ultrassom adicional)."
            case .um: return "Recomenda-se seguimento de rotina conforme idade da paciente."
            case .dois: return "Recomenda-se seguimento de rotina conforme idade da paciente."
            case .tres: return "Recomenda-se seguimento por imagem em 6 meses."
            case .quatroA: return "Recomenda-se biópsia (PAAF ou core biopsy) para avaliação histopatológica."
            case .quatroB: return "Recomenda-se biópsia (core biopsy) para avaliação histopatológica."
            case .quatroC: return "Recomenda-se biópsia (core biopsy) e correlação com avaliação clínica multidisciplinar."
            case .cinco: return "Recomenda-se biópsia obrigatória e encaminhamento à mastologia/oncologia para conduta."
            case .seis: return "Manejo conforme protocolo oncológico vigente."
            }
        }

        var probMalignidade: String {
            switch self {
            case .zero: return "—"
            case .um: return "0%"
            case .dois: return "0%"
            case .tres: return "≤ 2%"
            case .quatroA: return "2-10%"
            case .quatroB: return "10-50%"
            case .quatroC: return "50-95%"
            case .cinco: return "≥ 95%"
            case .seis: return "100% (comprovada)"
            }
        }
    }

    struct BIRADSResult: Sendable, Hashable {
        let category: Category
        let insertBloco: String
    }

    static func calculate(category: Category, lateralidade: String?) -> BIRADSResult {
        let lateralidadeText = (lateralidade ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let mama = lateralidadeText.isEmpty ? "" : " — \(lateralidadeText)"

        let bloco = """
        Conclusão: \(category.label)\(mama) — \(category.descricao) (probabilidade de malignidade: \(category.probMalignidade)).

        \(category.recomendacao)
        """

        return BIRADSResult(category: category, insertBloco: bloco)
    }
}
