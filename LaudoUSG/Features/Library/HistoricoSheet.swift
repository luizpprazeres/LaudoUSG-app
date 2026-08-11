import SwiftUI

/// As versões anteriores do modelo do médico.
///
/// Publicar não sobrescreve: a versão anterior é arquivada e continua legível.
/// Esta folha é onde isso deixa de ser detalhe de banco e vira algo que ele
/// pode usar — voltar para o que tinha antes, sem perder o que tem agora.
///
/// Restaurar cria um RASCUNHO, nunca publica direto: o modelo-base pode ter
/// mudado desde então, e é melhor a validação aparecer antes de o laudo mudar.
struct HistoricoSheet: View {
    let historico: [CustomizationVersion]
    let publicadaVersao: Int?
    let onRestaurar: (Int) -> Void

    private var versoes: [CustomizationVersion] {
        historico.sorted { $0.versao > $1.versao }
    }

    private func rotulo(_ v: CustomizationVersion) -> String {
        switch v.status {
        case "published": return "em uso"
        case "draft": return "rascunho"
        default: return "arquivada"
        }
    }

    private func data(_ iso: String?) -> String {
        guard let iso, let d = ISO8601DateFormatter.apiWithFractionalSeconds.date(from: iso)
            ?? ISO8601DateFormatter.api.date(from: iso) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d 'de' MMMM"
        return f.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Versões do seu modelo")
                .font(TextStyle.bodyLargeSemibold)

            if versoes.isEmpty {
                Text("Você ainda não publicou nenhuma versão. Quando publicar, as anteriores ficam guardadas aqui.")
                    .font(TextStyle.footnote)
                    .foregroundStyle(AppSurface.textSecondary)
            } else {
                Text("Nada é apagado. Trazer uma de volta cria um rascunho — você revisa antes de passar a usar.")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(versoes, id: \.id) { v in
                            let atual = v.versao == publicadaVersao
                            HStack(alignment: .center, spacing: Spacing.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Versão \(v.versao)")
                                            .font(TextStyle.bodyMedium)
                                            .foregroundStyle(AppSurface.textPrimary)
                                        Text(rotulo(v))
                                            .font(TextStyle.caption)
                                            .foregroundStyle(atual ? BrandColor.primaryDeep : AppSurface.textMuted)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                atual ? BrandColor.primarySoft : AppSurface.muted,
                                                in: Capsule()
                                            )
                                    }
                                    Text(
                                        "\(v.operations.count) alteração(ões)"
                                            + (data(v.publishedAt).isEmpty ? "" : " · \(data(v.publishedAt))")
                                    )
                                    .font(TextStyle.caption)
                                    .foregroundStyle(AppSurface.textSecondary)
                                    if v.baseDesatualizado {
                                        Text("escrita sobre uma versão anterior do modelo padrão")
                                            .font(TextStyle.caption)
                                            .foregroundStyle(SemanticColor.warningText)
                                    }
                                }
                                Spacer()
                                if !atual {
                                    Button("Trazer de volta") { onRestaurar(v.versao) }
                                        .font(TextStyle.captionMedium)
                                        .foregroundStyle(BrandColor.primary)
                                }
                            }
                            .padding(.vertical, Spacing.sm)
                            if v.versao != versoes.last?.versao {
                                Divider()
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
    }
}
