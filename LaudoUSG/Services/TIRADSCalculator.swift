import Foundation

/// ACR TI-RADS (Thyroid Imaging Reporting and Data System) — pontuação por 5
/// features ecográficas do nódulo, total → categoria TR1-TR5 + recomendação
/// de seguimento ou punção baseado no tamanho do nódulo.
///
/// Pontuação: composição + ecogenicidade + forma + margem + focos ecogênicos.
enum TIRADSCalculator {
    enum Composicao: String, Sendable, CaseIterable, Identifiable {
        case cistico = "Cístico ou quase totalmente cístico"
        case spongiform = "Espongiforme"
        case misto = "Misto cístico-sólido"
        case solido = "Sólido ou quase totalmente sólido"

        var id: String { rawValue }
        var pontos: Int {
            switch self {
            case .cistico, .spongiform: return 0
            case .misto: return 1
            case .solido: return 2
            }
        }
    }

    enum Ecogenicidade: String, Sendable, CaseIterable, Identifiable {
        case anecoico = "Anecoico"
        case hiperIso = "Hiperecoico ou isoecoico"
        case hipo = "Hipoecoico"
        case muitoHipo = "Muito hipoecoico"

        var id: String { rawValue }
        var pontos: Int {
            switch self {
            case .anecoico: return 0
            case .hiperIso: return 1
            case .hipo: return 2
            case .muitoHipo: return 3
            }
        }
    }

    enum Forma: String, Sendable, CaseIterable, Identifiable {
        case maisLarga = "Mais larga que alta"
        case maisAlta = "Mais alta que larga"

        var id: String { rawValue }
        var pontos: Int {
            self == .maisAlta ? 3 : 0
        }
    }

    enum Margem: String, Sendable, CaseIterable, Identifiable {
        case lisaIndefinida = "Lisa ou mal definida"
        case lobuladaIrregular = "Lobulada ou irregular"
        case extensaoExtra = "Extensão extra-tireoideana"

        var id: String { rawValue }
        var pontos: Int {
            switch self {
            case .lisaIndefinida: return 0
            case .lobuladaIrregular: return 2
            case .extensaoExtra: return 3
            }
        }
    }

    enum FocosEcogenicos: String, Sendable, CaseIterable, Identifiable {
        case nenhum = "Nenhum ou caudas de cometa grandes"
        case macroCalcif = "Macrocalcificações"
        case perifericaContinua = "Periféricas (contínuas)"
        case puntiformes = "Punctiformes ecogênicos (microcalcificações)"

        var id: String { rawValue }
        var pontos: Int {
            switch self {
            case .nenhum: return 0
            case .macroCalcif: return 1
            case .perifericaContinua: return 2
            case .puntiformes: return 3
            }
        }
    }

    struct TIRADSInput: Sendable {
        let composicao: Composicao
        let ecogenicidade: Ecogenicidade
        let forma: Forma
        let margem: Margem
        let focosEcogenicos: FocosEcogenicos
        let maiorEixoCm: Double
    }

    enum Categoria: String, Sendable {
        case tr1, tr2, tr3, tr4, tr5

        var label: String {
            switch self {
            case .tr1: return "TR1 — Benigno"
            case .tr2: return "TR2 — Não suspeito"
            case .tr3: return "TR3 — Minimamente suspeito"
            case .tr4: return "TR4 — Moderadamente suspeito"
            case .tr5: return "TR5 — Altamente suspeito"
            }
        }
    }

    struct TIRADSResult: Sendable {
        let pontos: Int
        let categoria: Categoria
        let recomendacao: String
        let insertBloco: String
    }

    static func calculate(_ input: TIRADSInput) -> TIRADSResult {
        let total = input.composicao.pontos
            + input.ecogenicidade.pontos
            + input.forma.pontos
            + input.margem.pontos
            + input.focosEcogenicos.pontos

        let cat: Categoria
        if total == 0 { cat = .tr1 }
        else if total <= 2 { cat = .tr2 }
        else if total <= 3 { cat = .tr3 }
        else if total <= 6 { cat = .tr4 }
        else { cat = .tr5 }

        let recomendacao = recomendar(categoria: cat, tamanho: input.maiorEixoCm)
        let bloco = """
        Avaliação TI-RADS (ACR) do nódulo (\(String(format: "%.1f", input.maiorEixoCm).replacingOccurrences(of: ".", with: ",")) cm em maior eixo):
        - Composição: \(input.composicao.rawValue) (\(input.composicao.pontos) pts)
        - Ecogenicidade: \(input.ecogenicidade.rawValue) (\(input.ecogenicidade.pontos) pts)
        - Forma: \(input.forma.rawValue) (\(input.forma.pontos) pts)
        - Margem: \(input.margem.rawValue) (\(input.margem.pontos) pts)
        - Focos ecogênicos: \(input.focosEcogenicos.rawValue) (\(input.focosEcogenicos.pontos) pts)
        - Pontuação total: \(total) pontos.

        Conclusão: \(cat.label). \(recomendacao)
        """

        return TIRADSResult(pontos: total, categoria: cat, recomendacao: recomendacao, insertBloco: bloco)
    }

    private static func recomendar(categoria: Categoria, tamanho rawTamanho: Double) -> String {
        // #8: arredonda a 1 casa antes de comparar com os cutoffs — evita que
        // 1,5 cm vire 1,4999 por imprecisão de parsing e perca a indicação.
        let tamanho = (rawTamanho * 10).rounded() / 10
        switch categoria {
        case .tr1, .tr2:
            return "Sem necessidade de seguimento adicional ou punção."
        case .tr3:
            if tamanho >= 2.5 { return "Recomenda-se punção aspirativa por agulha fina (PAAF)." }
            if tamanho >= 1.5 { return "Recomenda-se seguimento ultrassonográfico em 1, 3 e 5 anos." }
            return "Sem necessidade de PAAF ou seguimento."
        case .tr4:
            if tamanho >= 1.5 { return "Recomenda-se PAAF." }
            if tamanho >= 1.0 { return "Recomenda-se seguimento ultrassonográfico em 1, 2, 3 e 5 anos." }
            return "Sem necessidade de PAAF — seguimento clínico."
        case .tr5:
            if tamanho >= 1.0 { return "Recomenda-se PAAF — alta suspeita de malignidade." }
            if tamanho >= 0.5 { return "Recomenda-se seguimento ultrassonográfico anual." }
            return "Acompanhamento clínico — nódulo abaixo do limiar de intervenção."
        }
    }
}
