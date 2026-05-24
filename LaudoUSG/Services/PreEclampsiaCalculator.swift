import Foundation

/// Triagem simplificada de risco de pré-eclâmpsia no 1º trimestre (FMF Algorithm
/// simplificado). Versão MVP usa fatores de risco materno + MAP + Doppler uterinas.
///
/// Versão completa do FMF requer também PAPP-A e PlGF (biomarkers séricos). Esta
/// versão simplificada retorna risco categórico baseado nos inputs disponíveis em
/// ultrassonografia.
enum PreEclampsiaCalculator {
    struct PEInput: Sendable {
        let idadeMaterna: Int           // anos
        let imc: Double                 // kg/m²
        let mapMmHg: Double             // pressão arterial média
        let uterinaPiMedio: Double      // IP médio das artérias uterinas (calculado D+E/2)
        let igWeeks: Int                // idade gestacional (11-13+6 ideal)
        let primigesta: Bool            // sem partos prévios
        let antecedentePE: Bool         // PE em gestação anterior
        let hasOrSLE: Bool              // hipertensão crônica, diabetes, lúpus, SAF
    }

    enum Risk: String, Sendable {
        case baixo
        case intermediario
        case alto

        var label: String {
            switch self {
            case .baixo: return "Baixo risco de pré-eclâmpsia"
            case .intermediario: return "Risco intermediário de pré-eclâmpsia"
            case .alto: return "Alto risco de pré-eclâmpsia"
            }
        }

        var recomendacao: String {
            switch self {
            case .baixo: return "Acompanhamento de rotina pré-natal."
            case .intermediario: return "Considerar profilaxia com AAS 100-150 mg/dia até 36 semanas. Reavaliar com Doppler de uterinas no 2º trimestre."
            case .alto: return "Recomenda-se profilaxia com AAS 100-150 mg/dia (preferencialmente iniciada antes de 16 semanas) + acompanhamento em centro de medicina fetal. Monitorar com Doppler de uterinas seriado."
            }
        }
    }

    struct PEResult: Sendable {
        let risk: Risk
        let pontos: Int
        let fatores: [String]
        let insertBloco: String
    }

    /// Avaliação categórica simplificada por contagem de fatores de risco + valor
    /// dos parâmetros ecográficos. Não substitui FMF risk calculator completo
    /// (que requer PAPP-A + PlGF + MoM ajustado).
    static func calculate(_ input: PEInput) -> PEResult? {
        guard input.idadeMaterna >= 12, input.idadeMaterna <= 60 else { return nil }
        guard input.imc > 10, input.imc < 60 else { return nil }
        guard input.mapMmHg > 50, input.mapMmHg < 200 else { return nil }
        guard input.uterinaPiMedio > 0 else { return nil }
        guard input.igWeeks >= 11, input.igWeeks <= 24 else { return nil }

        var pontos = 0
        var fatores: [String] = []

        // Fatores maternos (alto peso)
        if input.antecedentePE { pontos += 3; fatores.append("Antecedente de pré-eclâmpsia") }
        if input.hasOrSLE { pontos += 3; fatores.append("Comorbidade vascular/autoimune (HAS/DM/LES/SAF)") }
        if input.idadeMaterna >= 40 { pontos += 2; fatores.append("Idade materna ≥ 40 anos") }
        else if input.idadeMaterna >= 35 { pontos += 1; fatores.append("Idade materna 35-39 anos") }
        if input.imc >= 35 { pontos += 2; fatores.append("Obesidade grau II+ (IMC ≥ 35)") }
        else if input.imc >= 30 { pontos += 1; fatores.append("Obesidade grau I (IMC 30-34,9)") }
        if input.primigesta { pontos += 1; fatores.append("Primigesta") }

        // MAP (mediana ~ 85-90 mmHg no 1T; >95 = elevada)
        if input.mapMmHg >= 100 { pontos += 2; fatores.append("MAP elevada (≥ 100 mmHg)") }
        else if input.mapMmHg >= 95 { pontos += 1; fatores.append("MAP moderadamente elevada (95-99 mmHg)") }

        // Doppler uterinas: IP > P95 ≈ 2.35 no 1T (Plasencia 2007)
        if input.uterinaPiMedio >= 2.35 { pontos += 2; fatores.append("IP médio uterinas acima do percentil 95 (≥ 2,35)") }
        else if input.uterinaPiMedio >= 1.80 { pontos += 1; fatores.append("IP médio uterinas elevado (1,80-2,34)") }

        let risk: Risk
        if pontos >= 5 { risk = .alto }
        else if pontos >= 2 { risk = .intermediario }
        else { risk = .baixo }

        let mapFmt = String(format: "%.0f", input.mapMmHg)
        let uterinaFmt = String(format: "%.2f", input.uterinaPiMedio).replacingOccurrences(of: ".", with: ",")

        let fatoresList = fatores.isEmpty ? "Nenhum fator de risco identificado." : fatores.map { "- \($0)" }.joined(separator: "\n")

        let bloco = """
        Triagem de pré-eclâmpsia (1º trimestre):
        - Idade materna: \(input.idadeMaterna) anos
        - IMC: \(String(format: "%.1f", input.imc).replacingOccurrences(of: ".", with: ",")) kg/m²
        - Pressão arterial média (MAP): \(mapFmt) mmHg
        - IP médio das artérias uterinas: \(uterinaFmt)
        - Primigesta: \(input.primigesta ? "Sim" : "Não")
        - Antecedente de PE: \(input.antecedentePE ? "Sim" : "Não")
        - Comorbidade vascular/autoimune: \(input.hasOrSLE ? "Sim" : "Não")

        Fatores identificados:
        \(fatoresList)

        Conclusão: \(risk.label) (pontuação \(pontos)). \(risk.recomendacao)

        Observação: triagem simplificada — para risco refinado (1 em N), considerar protocolo FMF completo com PAPP-A e PlGF séricos.
        """

        return PEResult(risk: risk, pontos: pontos, fatores: fatores, insertBloco: bloco)
    }
}
