import SwiftUI

/// Texto de ajuda de uma opção de preferência, mostrado ao tocar no ⓘ.
///
/// O subtítulo da linha responde "o que é" em uma frase. Isto aqui responde
/// "por que eu escolheria isso" — que é a pergunta que faz o usuário decidir.
struct PreferenceInfo: Identifiable {
    let id: String
    let title: String
    /// Uma frase: o que essa opção é.
    let what: String
    /// Quando faz sentido escolher — o critério prático de decisão.
    let whenToUse: String
    /// O incômodo honesto. `nil` quando não há.
    let caveat: String?
}

// MARK: - Percentil obstétrico

extension PercentileSource {
    var info: PreferenceInfo {
        switch self {
        case .intergrowth21st:
            PreferenceInfo(
                id: rawValue,
                title: "Intergrowth-21st",
                what: "Curva internacional construída pela OMS a partir de gestações saudáveis e bem assistidas em vários países.",
                whenToUse: "É a referência recomendada hoje e o padrão do app. Descreve como o crescimento fetal deveria ser em condições ideais, e por isso serve igualmente bem para qualquer população.",
                caveat: "Por ser mais exigente que as curvas antigas, tende a apontar mais fetos abaixo do percentil esperado."
            )
        case .hadlock1991:
            PreferenceInfo(
                id: rawValue,
                title: "Hadlock 1991",
                what: "A curva clássica da ultrassonografia obstétrica, usada há décadas na maioria dos aparelhos e serviços.",
                whenToUse: "Escolha quando o seu serviço, o obstetra que acompanha ou o exame anterior da paciente usam Hadlock — assim os percentis continuam comparáveis entre exames.",
                caveat: "Foi derivada de uma população pequena e local. Costuma classificar menos fetos como pequenos que as curvas mais recentes."
            )
        case .whoMulticentre2017:
            PreferenceInfo(
                id: rawValue,
                title: "WHO Multicentre 2017",
                what: "Curva multicêntrica da OMS que, quando o sexo fetal é conhecido, aplica percentis específicos para menino e menina.",
                whenToUse: "Útil quando o sexo já está definido e você quer o percentil mais ajustado ao caso.",
                caveat: "Ainda em curadoria no app: sem o sexo definido, cai na curva geral."
            )
        }
    }
}

// MARK: - Ditado

extension TranscriptionEngine {
    var info: PreferenceInfo {
        switch self {
        case .laudousg:
            PreferenceInfo(
                id: rawValue,
                title: "Transcrição LaudoUSG",
                what: "O áudio é transcrito nos nossos servidores, com um vocabulário médico carregado de acordo com o exame que você escolheu.",
                whenToUse: "É a opção padrão e a que erra menos em termo técnico. Sabe que existe hipoecoico, colelitíase, BI-RADS e safena magna — e escreve número sempre do mesmo jeito.",
                caveat: "Precisa de internet. Sem conexão, o ditado não inicia."
            )
        case .nativa:
            PreferenceInfo(
                id: rawValue,
                title: "Transcrição nativa",
                what: "Usa o reconhecimento de voz do próprio iPhone. Nada é enviado pela internet — o áudio não sai do aparelho.",
                whenToUse: "Escolha quando a internet da clínica é ruim ou instável, ou quando você prefere que o áudio simplesmente não saia do celular.",
                caveat: "Não conhece o vocabulário médico do LaudoUSG, então erra mais termo técnico. E escreve números de forma inconsistente: às vezes \"37 semanas\", às vezes \"trinta e sete semanas\". Confira as medidas antes de gerar."
            )
        }
    }
}

// MARK: - Folha de explicação

struct PreferenceInfoSheet: View {
    let info: PreferenceInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    block(icon: "text.alignleft", title: "O que é", body: info.what)
                    block(icon: "checkmark.circle", title: "Quando escolher", body: info.whenToUse)
                    if let caveat = info.caveat {
                        block(icon: "exclamationmark.triangle", title: "Atenção", body: caveat)
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppSurface.background)
            .navigationTitle(info.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        // Meia tela: é ajuda, não conteúdo principal — o usuário não perde o contexto.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func block(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(title, systemImage: icon)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            Text(body)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
