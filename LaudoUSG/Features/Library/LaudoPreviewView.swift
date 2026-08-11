import SwiftUI

/// Como o laudo fica de verdade.
///
/// A tela de edição mostra o modelo frase a frase, o que é bom para mexer e
/// ruim para julgar: o médico não reconhece o próprio laudo numa lista de
/// frases soltas. Aqui ele vê o texto inteiro, do jeito que sai — e troca de
/// cenário para conferir o gemelar, a gestação inicial, o oligoâmnio.
///
/// O que ele mudou aparece destacado. O resto é o modelo padrão.
struct LaudoPreviewView: View {
    let previas: [ReportPreview]

    @State private var cenario: String?

    private var atual: ReportPreview? {
        previas.first(where: { $0.cenario == cenario }) ?? previas.first
    }

    /// Linhas que a personalização acrescentou ou reescreveu, para destacar.
    private var alteradas: Set<String> {
        guard let atual else { return [] }
        var s = Set<String>()
        for m in atual.mudancas {
            for linha in (m.depois ?? "").split(separator: "\n", omittingEmptySubsequences: false) {
                let t = linha.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { s.insert(t) }
            }
        }
        return s
    }

    private func ehCabecalho(_ linha: String) -> Bool {
        let t = linha.trimmingCharacters(in: .whitespaces)
        guard t.count >= 4 else { return false }
        return t == t.uppercased() && t.rangeOfCharacter(from: .letters) != nil
    }

    var body: some View {
        if previas.isEmpty {
            Text("Ainda não há como mostrar o laudo desta categoria.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .padding(Spacing.md)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(previas) { p in
                            let ativo = p.cenario == (atual?.cenario ?? "")
                            Button {
                                cenario = p.cenario
                            } label: {
                                Text(p.nome)
                                    .font(TextStyle.captionMedium)
                                    .foregroundStyle(ativo ? .white : AppSurface.textSecondary)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, 6)
                                    .background(
                                        ativo
                                            ? (p.patologico ? SemanticColor.warningText : BrandColor.primary)
                                            : AppSurface.muted,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                if let atual {
                    Text(
                        atual.mudou
                            ? "Em verde, o que você mudou."
                            : "Neste caso o seu laudo sai igual ao modelo padrão."
                    )
                    .font(TextStyle.caption)
                    .foregroundStyle(atual.mudou ? BrandColor.primaryDeep : AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.md)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(
                                Array(atual.laudoPersonalizado.split(separator: "\n", omittingEmptySubsequences: false).enumerated()),
                                id: \.offset
                            ) { _, linha in
                                let texto = String(linha)
                                let limpa = texto.trimmingCharacters(in: .whitespaces)
                                let destaque = !limpa.isEmpty && alteradas.contains(limpa)
                                Text(texto.isEmpty ? " " : texto)
                                    .font(TextStyle.body)
                                    .fontWeight(ehCabecalho(texto) ? .bold : (destaque ? .semibold : .regular))
                                    .foregroundStyle(destaque ? BrandColor.primaryDeep : AppSurface.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(destaque ? BrandColor.primarySoft : .clear)
                            }
                        }
                        .padding(Spacing.sm)
                        .background(AppSurface.card, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.xl)
                    }
                }
            }
        }
    }
}
