import SwiftUI

/// Biblioteca — o modelo de laudo do médico.
///
/// Era um "em breve". Agora é onde ele ajusta o modelo padrão: trocar a
/// redação de uma frase, tirar uma que não usa, acrescentar outra depois dela.
///
/// O modelo aparece como TEXTO CORRIDO, não como formulário — o médico precisa
/// reconhecer o próprio laudo ao olhar a tela. As alterações aparecem no ponto
/// exato: frase antiga riscada, nova logo abaixo.
///
/// Duas cores, dois significados que não podem se confundir:
///   verde  → a redação DELE (personalização, ele escolheu)
///   âmbar  → o que o SISTEMA escreve quando há um achado (ele não escolhe)
///
/// Nada muda nos laudos até "Passar a usar". Antes disso é rascunho.
/// Qual seção está recebendo uma frase nova. Um tipo, e não `String?`, porque
/// `sheet(item:)` pede `Identifiable` — e nomear a intenção custa menos que a
/// gambiarra de embrulhar a string.
private struct SecaoEmFoco: Identifiable, Hashable {
    let id: String
}

struct LibraryView: View {
    /// A categoria de partida. Deixou de ser a ÚNICA: era `var categoria =
    /// "OBSTETRICA"` cravado, e por isso o médico só via o modelo obstétrico
    /// por mais que o backend passasse a servir as outras doze.
    var categoriaInicial: String = "OBSTETRICA"

    @State private var categoria: String = "OBSTETRICA"
    @State private var categorias: [ModelCustomizationService.CategoriaDaBiblioteca] = []
    /// A lista já veio do SERVIDOR? Enquanto for `false`, cada `carregar()`
    /// tenta de novo.
    ///
    /// Sem isto o guard era `categorias.isEmpty` — e como a falha preenchia o
    /// array com o fallback de uma categoria, a condição nunca mais era
    /// verdadeira: a primeira tentativa malsucedida congelava o menu escondido
    /// pelo resto da sessão da tela, e nem "Tentar de novo" recuperava.
    @State private var categoriasDoServidor = false
    /// Qual cenário do modelo está aberto (gestação padrão / inicial / gemelar,
    /// 1º / 2º / 3º trimestre…). Índice em `estado.catalogo.modelos`.
    @State private var cenario = 0
    /// A linha do modelo aberta para edição.
    @State private var slotDoModelo: LinhaDoModelo?
    /// A seção que vai receber uma frase NOVA — "corpo" ou "conclusao".
    @State private var secaoRecebendoFrase: SecaoEmFoco?
    /// A linha sob o dedo durante o arrasto — desenha onde a frase vai cair.
    @State private var linhaSobArrasto: String?
    /// A variante de achado aberta para edição.
    @State private var varianteDeAchado: AchadoEmFoco?

    struct AchadoEmFoco: Identifiable {
        let slot: String
        let variante: CatalogVariant
        let texto: String
        var id: String { "\(slot)|\(variante.id)" }
    }
    @State private var estado: CustomizationState?
    @State private var operacoes: [ReportOperation] = []
    @State private var carregando = true
    @State private var salvando = false
    @State private var erro: String?
    /// A falha foi "o servidor ainda não tem isto"? Não é erro do app, e não
    /// deve ser pintada de vermelho — o Luiz leu a tela e achou que tinha
    /// quebrado. É informação: o app está à frente do backend.
    @State private var aguardandoServidor = false
    @State private var recusa: [String]?
    @State private var variacaoSelecionada: String?
    /// Alterna entre editar o modelo e ver o laudo pronto.
    @State private var aba: Aba = .modelo
    @State private var mostrandoHistorico = false

    enum Aba: String, CaseIterable { case modelo, laudo }

    @State private var slotEmFoco: CatalogSlot?
    @State private var modoEdicao: ModoEdicao?
    @State private var textoEmEdicao = ""

    enum ModoEdicao: Identifiable {
        case trocar(CatalogSlot)
        case depois(CatalogSlot)
        case conclusao
        var id: String {
            switch self {
            case .trocar(let s): return "trocar-\(s.id)"
            case .depois(let s): return "depois-\(s.id)"
            case .conclusao: return "conclusao"
            }
        }
    }

    // MARK: - Derivados

    /// Os cenários do modelo — "Gestação padrão", "Segundo trimestre"…
    private var modelos: [ModeloProjetado] { estado?.catalogo.modelos ?? [] }

    /// As linhas do cenário aberto, na ordem e na seção em que saem no laudo.
    ///
    /// Vêm do SERVIDOR. A tela montava isto sozinha — pegava a "variante
    /// padrão" de cada slot da ordem do corpo — e três defeitos vinham daí: a
    /// conclusão não aparecia (a ordem do corpo não a contém), COMENTÁRIOS
    /// também não, e slots CONDICIONAIS de achado vazavam para o modelo de
    /// rotina, fazendo um descolamento placentário aparecer como linha de
    /// exame normal.
    private var linhasDoModelo: [LinhaDoModelo] {
        guard !modelos.isEmpty else { return [] }
        return modelos[min(cenario, modelos.count - 1)].linhas
    }

    /// Os achados condicionais — fora do modelo, mas editáveis.
    private var achados: [AchadoProjetado] { estado?.catalogo.achados ?? [] }

    /// Fallback para backend anterior a `modelos`: monta como antes.
    private var linhasLegado: [(slot: CatalogSlot, frase: String, variante: CatalogVariant)] {
        guard let catalogo = estado?.catalogo else { return [] }
        let porId = Dictionary(uniqueKeysWithValues: catalogo.slots.map { ($0.id, $0) })
        var vistos = Set<String>()
        return (catalogo.ordens.first?.slots ?? []).compactMap { id in
            guard !vistos.contains(id) else { return nil }
            vistos.insert(id)
            guard let slot = porId[id],
                  let v = slot.variantePadrao,
                  let frase = v.frase else { return nil }
            return (slot, frase, v)
        }
    }

    private var variacaoAtiva: ModelVariation? {
        guard let id = variacaoSelecionada else { return nil }
        return estado?.variacoes?.first(where: { $0.id == id })
    }

    /// O que o achado escolhido muda, por slot. `antes` vem do backend já COM a
    /// personalização aplicada — é a frase que ESTE médico teria, e por isso é
    /// ela que aparece riscada, não a do catálogo-base.
    private var efeitoPorSlot: [String: (antes: String, corpo: String, conclusao: String?)] {
        var m: [String: (antes: String, corpo: String, conclusao: String?)] = [:]
        for mu in variacaoAtiva?.mudancas ?? [] where mu.secao == "corpo" {
            m[mu.slot] = (mu.antes ?? "", mu.depois ?? "", nil)
        }
        for mu in variacaoAtiva?.mudancas ?? [] where mu.secao == "conclusao" {
            if var atual = m[mu.slot] {
                atual.conclusao = mu.depois
                m[mu.slot] = atual
            }
        }
        return m
    }

    private func operacao(de slotId: String) -> ReportOperation? {
        operacoes.first(where: { $0.op != "insert_phrase_after" && $0.slot == slotId })
    }
    private func inseridas(apos slotId: String) -> [ReportOperation] {
        operacoes.filter { $0.op == "insert_phrase_after" && $0.anchor == slotId }
    }
    private var itensDeConclusao: [ReportOperation] {
        operacoes.filter { $0.op == "append_conclusion_item" }
    }
    /// "Existe rascunho" é o que o SERVIDOR diz — não `!operacoes.isEmpty`.
    ///
    /// Desde que `operacoes` passou a cair no publicado quando não há rascunho,
    /// contar operações diria "tem rascunho" para quem só tem personalização
    /// publicada, e o rodapé ofereceria "Publicar" em vez de "Voltar ao padrão".
    private var temRascunho: Bool { estado?.rascunho != nil }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppSurface.background.ignoresSafeArea()
            if carregando && estado == nil {
                ProgressView().tint(BrandColor.primary)
            } else if let erro, estado == nil {
                falhaAoCarregar(erro)
            } else if estado != nil {
                conteudo
            }
        }
        .navigationTitle("Biblioteca")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !(estado?.historico ?? []).isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { mostrandoHistorico = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Versões anteriores")
                }
            }
        }
        .sheet(isPresented: $mostrandoHistorico) {
            HistoricoSheet(
                historico: estado?.historico ?? [],
                publicadaVersao: estado?.publicado?.versao,
                onRestaurar: { v in
                    mostrandoHistorico = false
                    Task { await restaurar(v) }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .task { await carregar() }
        .sheet(item: $slotEmFoco) { slot in
            acoesDaFrase(slot)
                .presentationDetents([.height(300)])
        }
        .sheet(item: $modoEdicao) { modo in
            editorDeTexto(modo)
                .presentationDetents([.medium])
        }
        .sheet(item: $slotDoModelo) { linha in
            editorDeLinha(linha)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $varianteDeAchado) { foco in
            editorDeAchado(foco)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $secaoRecebendoFrase) { secao in
            editorDeFraseNova(secao)
                .presentationDetents([.medium])
        }
    }

    private func falhaAoCarregar(_ mensagem: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: aguardandoServidor ? "clock.arrow.circlepath" : "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(aguardandoServidor ? AppSurface.textMuted : SemanticColor.errorText)
            Text(mensagem)
                .font(TextStyle.body)
                .foregroundStyle(aguardandoServidor ? AppSurface.textSecondary : SemanticColor.errorText)
                .multilineTextAlignment(.center)
            Button("Tentar de novo") { Task { await carregar() } }
                .font(TextStyle.bodySemibold)
                .foregroundStyle(BrandColor.primary)
        }
        .padding(Spacing.lg)
    }

    /// Qual exame o médico está editando.
    ///
    /// Um menu, e não um Picker segmentado: são treze categorias, e um
    /// segmentado com treze vira uma fileira ilegível.
    private var seletorDeCategoria: some View {
        Menu {
            ForEach(categorias) { c in
                Button {
                    guard c.categoria != categoria else { return }
                    categoria = c.categoria
                    // Trocar de exame descarta o que estava em edição AQUI —
                    // as operações são de outra categoria e não fazem sentido
                    // na nova. O rascunho gravado no servidor não é tocado.
                    operacoes = []
                    variacaoSelecionada = nil
                    Task { await carregar() }
                } label: {
                    Label(c.rotulo, systemImage: c.categoria == categoria ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(rotuloAtual).font(TextStyle.bodyLargeMedium)
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(BrandColor.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
    }

    /// Qual VARIANTE DE EXAME está aberta — gestação padrão/inicial/gemelar,
    /// 1º/2º/3º trimestre. É um segundo nível abaixo da categoria, e existe
    /// porque uma categoria não tem um modelo só: o morfológico são três
    /// exames sob o mesmo nome, e dois estavam invisíveis.
    private var seletorDeCenario: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(modelos.enumerated()), id: \.element.id) { i, m in
                    Button {
                        cenario = i
                    } label: {
                        Text(m.nome)
                            .font(TextStyle.caption)
                            .foregroundStyle(i == cenario ? .white : AppSurface.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                i == cenario ? BrandColor.primary : AppSurface.muted,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
        }
    }

    /// Editor de uma linha do modelo.
    private func editorDeLinha(_ linha: LinhaDoModelo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Como você escreve esta frase")
                .font(TextStyle.bodyLargeSemibold)
            fraseComChips(linha, cor: AppSurface.textSecondary)

            if !linha.dados.isEmpty {
                // Os dados obrigatórios precisam sobreviver à redação nova — é
                // o que impede uma frase reescrita de apagar uma medida.
                Text("Toque para inserir o dado do exame na sua frase:")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                HStack {
                    ForEach(Array(linha.dados.enumerated()), id: \.offset) { _, d in
                        Button {
                            textoEmEdicao += d.marcador
                        } label: {
                            Text(d.obrigatorio ? "\(d.rotulo) *" : d.rotulo)
                                .font(TextStyle.caption)
                                .foregroundStyle(BrandColor.primaryDeep)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 4)
                                .background(BrandColor.primarySoft, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if linha.dados.contains(where: { $0.obrigatorio }) {
                    Text("* precisa aparecer na sua frase — é o dado que o exame mediu.")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                }
            }

            TextEditor(text: $textoEmEdicao)
                .font(TextStyle.bodyLarge)
                .frame(minHeight: 110)
                .padding(Spacing.xs)
                .background(AppSurface.muted, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                SecondaryButton(title: "Cancelar") { slotDoModelo = nil }
                PrimaryButton(title: "Guardar") {
                    // Só a redação desta linha muda; o que foi ACRESCENTADO
                    // depois dela é outra operação e sobrevive.
                    let novas = operacoes.filter { !($0.op != "insert_phrase_after" && $0.alvo == linha.slot) }
                        + [.replacePhrase(slot: linha.slot, value: textoEmEdicao)]
                    slotDoModelo = nil
                    Task { await aplicar(novas) }
                }
            }

            Divider()

            /**
             Aqui só o que age SOBRE ESTA FRASE.

             "Acrescentar" saiu daqui: dividia o mesmo campo de texto com o
             "Guardar", que abre pré-preenchido com a frase da casa — para
             escrever uma frase nova era preciso apagar a original primeiro, e o
             botão ficava travado até o texto diferir. Frase nova agora nasce no
             fim da seção, onde o médico a enxerga no lugar em que vai entrar.
             */
            if linha.removivel {
                Button(role: .destructive) {
                    let novas = operacoes.filter { $0.alvo != linha.slot } + [.removeSlot(linha.slot)]
                    slotDoModelo = nil
                    Task { await aplicar(novas) }
                } label: {
                    Label("Tirar esta frase do meu modelo", systemImage: "minus.circle")
                        .font(TextStyle.bodyLargeMedium)
                }
            }

            if operacoes.contains(where: { $0.alvo == linha.slot }) {
                Button(role: .destructive) {
                    let novas = operacoes.filter { $0.alvo != linha.slot }
                    slotDoModelo = nil
                    Task { await aplicar(novas) }
                } label: {
                    Label("Desfazer tudo nesta frase", systemImage: "arrow.uturn.backward")
                        .font(TextStyle.bodyLargeMedium)
                }
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .onAppear { textoEmEdicao = linha.frase }
    }

    /// Editor de uma variante de ACHADO.
    private func editorDeAchado(_ foco: AchadoEmFoco) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Como você descreve este achado")
                .font(TextStyle.bodyLargeSemibold)
            Text(foco.texto.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
            Text("Esta frase só entra no laudo quando você dita o achado. Ela não pode sair do modelo, e o dado do exame precisa continuar nela.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)

            TextEditor(text: $textoEmEdicao)
                .font(TextStyle.bodyLarge)
                .frame(minHeight: 110)
                .padding(Spacing.xs)
                .background(AppSurface.muted, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                SecondaryButton(title: "Cancelar") { varianteDeAchado = nil }
                PrimaryButton(title: "Guardar") {
                    let novas = operacoes.filter { !($0.slot == foco.slot && $0.variant == foco.variante.id) }
                        + [ReportOperation(op: "replace_phrase", slot: foco.slot,
                                           variant: foco.variante.id, value: textoEmEdicao)]
                    varianteDeAchado = nil
                    Task { await aplicar(novas) }
                }
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .onAppear { textoEmEdicao = foco.variante.frase ?? foco.texto }
    }

    private var rotuloAtual: String {
        categorias.first(where: { $0.categoria == categoria })?.rotulo ?? categoria
    }

    private var conteudo: some View {
        VStack(spacing: 0) {
            if categorias.count > 1 { seletorDeCategoria }
            if modelos.count > 1 { seletorDeCenario }
            // Editar × conferir: o médico precisa das duas visões, e elas não
            // cabem na mesma tela sem uma virar ruído da outra.
            Picker("", selection: $aba) {
                Text("Editar o modelo").tag(Aba.modelo)
                Text("Ver o laudo").tag(Aba.laudo)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)

            if aba == .laudo {
                LaudoPreviewView(previas: estado?.previa ?? [])
                    .padding(.top, Spacing.sm)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    cabecalho
                    if let recusa { avisoDeRecusa(recusa) }
                    if let variacoes = estado?.variacoes, !variacoes.isEmpty {
                        seletorDeAchados(variacoes)
                    }
                    modeloEmTextoCorrido
                    // O "Acrescentar item à conclusão" agora nasce NO FIM da
                    // conclusão, dentro da lista — ver `botaoAcrescentar`. Este
                    // aqui, solto no rodapé, virava um segundo botão idêntico.
                    if !itensDeConclusao.isEmpty { conclusaoAcrescentada }
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            }
            if temRascunho || estado?.publicado != nil { rodape }
        }
    }

    private var cabecalho: some View {
        // `nil` = backend antigo, que não informa; nesse caso não desminta.
        let ativa = estado?.personalizacaoAtiva ?? true
        return Group {
            if let pub = estado?.publicado {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ativa ? "Em uso nos seus laudos" : "Publicada, mas ainda não valendo")
                        .font(TextStyle.captionMedium)
                        .foregroundStyle(ativa ? BrandColor.primaryDeep : AppSurface.textSecondary)
                    Text("Versão \(pub.versao) · \(pub.operations.count) alteração(ões)")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textSecondary)
                    if !ativa {
                        Text("O servidor ainda não está aplicando personalizações nesta categoria. Ela passa a valer sem você precisar publicar de novo.")
                            .font(TextStyle.caption)
                            .foregroundStyle(AppSurface.textMuted)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
                .background(ativa ? BrandColor.primarySoft : AppSurface.muted, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Este é o modelo padrão do laudo de \(rotuloAtual.lowercased()). Toque em qualquer frase para mudar a redação, tirá-la do laudo, ou acrescentar outra depois dela.")
                    .font(TextStyle.footnote)
                    .foregroundStyle(AppSurface.textSecondary)
            }
        }
    }

    private func avisoDeRecusa(_ motivos: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Esta alteração não pode valer")
                .font(TextStyle.captionMedium)
                .foregroundStyle(SemanticColor.errorText)
            ForEach(motivos, id: \.self) { m in
                Text("• \(m)")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(SemanticColor.errorBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(SemanticColor.errorBorder, lineWidth: 1)
        )
    }

    private func seletorDeAchados(_ variacoes: [ModelVariation]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Ver o que muda no laudo quando há:")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    chip("Nada alterado", ativo: variacaoSelecionada == nil, cor: BrandColor.primary) {
                        variacaoSelecionada = nil
                    }
                    ForEach(variacoes) { v in
                        chip(v.nome, ativo: variacaoSelecionada == v.id, cor: SemanticColor.warningText) {
                            variacaoSelecionada = variacaoSelecionada == v.id ? nil : v.id
                        }
                    }
                }
            }
            if let v = variacaoAtiva {
                Text("\(v.descricao) Estas frases são escritas pelo sistema a partir do que você ditar — não dá para personalizá-las, justamente para que a sua redação de normalidade nunca apareça no lugar de um achado alterado.")
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(SemanticColor.warningBg, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Frases acrescentadas

    /// As frases novas ancoradas DEPOIS desta linha, na ordem em que ele escreveu.
    private func acrescentadasDepoisDe(_ slot: String) -> [ReportOperation] {
        operacoes.filter { $0.op == "insert_phrase_after" && $0.anchor == slot }
    }

    /// A última linha de uma seção — âncora de quem entra no fim dela.
    private func ultimaLinhaDa(_ secao: String) -> String? {
        linhasDoModelo.last(where: { $0.secao == secao })?.slot
    }

    /// Uma frase que o médico acrescentou. Aparece onde vai entrar no laudo.
    ///
    /// ARRASTÁVEL: segurar e puxar solta-a sobre outra linha, e ela passa a
    /// entrar depois daquela. Reposicionar é trocar a ÂNCORA — o servidor já
    /// entendia isso, então nada mudou do lado de lá.
    ///
    /// As cores vêm de `AppSurface`, não de `BrandColor`: o verde-claro do
    /// `BrandColor.primarySoft` é hex fixo, e no modo escuro recebia texto
    /// branco por cima. Branco sobre verde-claro não se lê.
    private func fraseAcrescentada(_ op: ReportOperation) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(AppSurface.onPrimarySoft.opacity(0.6))
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(op.value ?? "")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.onPrimarySoft)
                HStack(spacing: Spacing.md) {
                    Text("segure e arraste para mover")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.onPrimarySoft.opacity(0.7))
                    Button("Tirar", role: .destructive) {
                        Task { await aplicar(operacoes.filter { $0.id != op.id }) }
                    }
                    .font(TextStyle.caption)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xs)
        .background(AppSurface.primarySoft, in: RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 2)
        .draggable(op.id) {
            // A prévia que acompanha o dedo.
            Text(op.value ?? "")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.onPrimarySoft)
                .padding(Spacing.xs)
                .background(AppSurface.primarySoft, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    /// "+ Acrescentar frase" no fim de uma seção.
    ///
    /// É onde o médico pediu: como o item da conclusão, mas para qualquer
    /// seção — e ancorado na última linha dela, que é o que faz a frase nova
    /// sair no fim daquela parte do laudo.
    private func botaoAcrescentar(secao: String) -> some View {
        Button {
            textoEmEdicao = ""
            secaoRecebendoFrase = SecaoEmFoco(id: secao)
        } label: {
            Label(
                secao == "conclusao" ? "Acrescentar item à conclusão" : "Acrescentar frase aqui",
                systemImage: "plus.circle",
            )
            .font(TextStyle.bodyMedium)
        }
        .foregroundStyle(BrandColor.primary)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
    }

    /// Alvo invisível no TOPO de uma seção.
    ///
    /// Só aparece quando há algo sendo arrastado — fora isso é espaço morto. É
    /// como se chega ao começo de uma seção com uma operação que só sabe dizer
    /// "depois de".
    private func alvoDeTopo(anterior: String, secao: String) -> some View {
        Rectangle()
            .fill(linhaSobArrasto == "topo:\(secao)" ? BrandColor.primary : Color.clear)
            .frame(height: linhaSobArrasto == "topo:\(secao)" ? 2 : 10)
            .dropDestination(for: String.self) { ids, _ in
                receberArrasto(ids, depoisDe: anterior)
            } isTargeted: { dentro in
                linhaSobArrasto = dentro ? "topo:\(secao)" : nil
            }
    }

    /// Recebe uma frase arrastada: ela passa a entrar DEPOIS desta linha.
    ///
    /// `op.id` é o que viaja no arrasto — de lá se acha a operação inteira, o
    /// texto vem junto e nada precisa ser reescrito.
    private func receberArrasto(_ ids: [String], depoisDe slot: String) -> Bool {
        guard let id = ids.first,
              let op = operacoes.first(where: { $0.id == id }),
              op.anchor != slot else { return false }
        let novas = operacoes.filter { $0.id != id }
            + [.insertPhraseAfter(anchor: slot, value: op.value ?? "")]
        Task { await aplicar(novas) }
        return true
    }

    /// O editor da frase NOVA — campo em branco, porque é frase nova.
    private func editorDeFraseNova(_ foco: SecaoEmFoco) -> some View {
        let secao = foco.id
        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text(secao == "conclusao" ? "Novo item da conclusão" : "Nova frase do laudo")
                .font(TextStyle.bodyLargeSemibold)
            Text("Ela entra no fim desta parte do laudo. Depois de guardar, você pode movê-la para outro lugar.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)

            TextEditor(text: $textoEmEdicao)
                .font(TextStyle.bodyLarge)
                .frame(minHeight: 110)
                .padding(Spacing.xs)
                .background(AppSurface.muted, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                SecondaryButton(title: "Cancelar") { secaoRecebendoFrase = nil }
                PrimaryButton(title: "Guardar") {
                    let texto = textoEmEdicao.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !texto.isEmpty, let ancora = ultimaLinhaDa(secao) else {
                        secaoRecebendoFrase = nil
                        return
                    }
                    let novas = operacoes + [.insertPhraseAfter(anchor: ancora, value: texto)]
                    secaoRecebendoFrase = nil
                    Task { await aplicar(novas) }
                }
            }
            Spacer()
        }
        .padding(Spacing.lg)
    }

    private func chip(_ titulo: String, ativo: Bool, cor: Color, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(titulo)
                .font(TextStyle.captionMedium)
                .foregroundStyle(ativo ? .white : AppSurface.textSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background(ativo ? cor : AppSurface.muted, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// O cabeçalho de uma seção, como sai no laudo.
    private func cabecalhoDaSecao(_ secao: String) -> String {
        switch secao {
        case "tecnica": return "COMENTÁRIOS:"
        case "conclusao": return estado?.catalogo.cabecalhos.conclusao ?? "CONCLUSÃO:"
        default: return estado?.catalogo.cabecalhos.corpo ?? "OS SEGUINTES ASPECTOS FORAM OBSERVADOS:"
        }
    }

    private var modeloEmTextoCorrido: some View {
        VStack(alignment: .leading, spacing: 0) {
            if modelos.isEmpty {
                // Backend anterior a `modelos` — monta como antes.
                Text(estado?.catalogo.cabecalhos.corpo ?? "")
                    .font(TextStyle.caption).tracking(1)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.bottom, Spacing.xs)
                ForEach(linhasLegado, id: \.slot.id) { frase($0) }
            } else {
                // O cabeçalho entra a cada MUDANÇA de seção — é o que faz o
                // modelo se parecer com o laudo. Sem isto o corpo emendava na
                // conclusão sem o termo "CONCLUSÃO", que foi o que o Luiz viu
                // na tireoide e na mamária.
                ForEach(Array(linhasDoModelo.enumerated()), id: \.element.id) { i, linha in
                    if i == 0 || linhasDoModelo[i - 1].secao != linha.secao {
                        Text(cabecalhoDaSecao(linha.secao))
                            .font(TextStyle.caption).tracking(1)
                            .foregroundStyle(AppSurface.textMuted)
                            .padding(.top, i == 0 ? 0 : Spacing.md)
                            .padding(.bottom, Spacing.xs)
                    }
                    // ANTES da primeira frase da seção: a única posição que a
                    // âncora "depois de" não alcança sozinha. Resolve-se
                    // ancorando na ÚLTIMA linha da seção anterior — que é onde
                    // esta posição fica, no texto corrido do laudo.
                    if i > 0, linhasDoModelo[i - 1].secao != linha.secao {
                        alvoDeTopo(anterior: linhasDoModelo[i - 1].slot, secao: linha.secao)
                    }
                    linhaDoModelo(linha)
                        .dropDestination(for: String.self) { ids, _ in
                            receberArrasto(ids, depoisDe: linha.slot)
                        } isTargeted: { dentro in
                            linhaSobArrasto = dentro ? linha.slot : nil
                        }
                        .overlay(alignment: .bottom) {
                            // Onde ela vai cair, enquanto o dedo está em cima.
                            if linhaSobArrasto == linha.slot {
                                Rectangle()
                                    .fill(BrandColor.primary)
                                    .frame(height: 2)
                            }
                        }
                    // As frases NOVAS aparecem onde vão entrar no laudo, não
                    // numa lista à parte — é o ponto de mostrar o modelo como
                    // ele sai.
                    ForEach(acrescentadasDepoisDe(linha.slot), id: \.id) { op in
                        fraseAcrescentada(op)
                    }
                    // Fim da seção: o lugar de acrescentar. A TÉCNICA fica de
                    // fora — é o texto fixo do serviço, não achado do exame.
                    if linha.secao != "tecnica",
                       i == linhasDoModelo.count - 1 || linhasDoModelo[i + 1].secao != linha.secao {
                        botaoAcrescentar(secao: linha.secao)
                    }
                }
                if !achados.isEmpty { secaoDeAchados }
            }
        }
    }

    /// Uma frase do modelo — a redação, com os dados como chips.
    @ViewBuilder
    private func linhaDoModelo(_ linha: LinhaDoModelo) -> some View {
        let op = operacao(de: linha.slot)
        let removida = op?.op == "remove_slot"
        let trocadaPor = op?.op == "replace_phrase" ? op?.value : nil

        VStack(alignment: .leading, spacing: 3) {
            Button {
                guard linha.editavel else { return }
                slotDoModelo = linha
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    if removida || trocadaPor != nil {
                        fraseComChips(linha, cor: AppSurface.textMuted)
                            .strikethrough()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        fraseComChips(linha, cor: AppSurface.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let trocadaPor {
                        Text(trocadaPor.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(BrandColor.primaryDeep)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !linha.editavel, let motivo = linha.motivo {
                        Text(motivo)
                            .font(TextStyle.caption)
                            .foregroundStyle(AppSurface.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!linha.editavel)
        }
        .padding(.vertical, 2)
    }

    /// A frase com cada dado do exame desenhado como chip.
    ///
    /// O médico não vê `{dbp}` nem `____`: vê `[DBP]`. É o servidor que unifica
    /// as duas formas — a nomeada do catálogo escrito e a posicional do modelo
    /// derivado — em `dados`.
    private func fraseComChips(_ linha: LinhaDoModelo, cor: Color) -> Text {
        var resultado = Text("")
        var restante = Substring(linha.frase)
        var i = 0
        while i < linha.dados.count, let r = restante.range(of: linha.dados[i].marcador) {
            resultado = resultado
                + Text(String(restante[restante.startIndex..<r.lowerBound])).foregroundStyle(cor)
                + Text("[\(linha.dados[i].rotulo)]").foregroundStyle(BrandColor.primary).bold()
            restante = restante[r.upperBound...]
            i += 1
        }
        return (resultado + Text(String(restante)).foregroundStyle(cor)).font(TextStyle.bodyLarge)
    }

    /// Os achados — fora do modelo, em âmbar, editáveis.
    ///
    /// Âmbar porque não são o laudo de rotina: são o que o sistema escreve
    /// QUANDO o achado é ditado. Misturá-los com o modelo é o defeito que fazia
    /// um descolamento placentário aparecer como linha de exame normal.
    private var secaoDeAchados: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("QUANDO HÁ ACHADO")
                .font(TextStyle.caption).tracking(1)
                .foregroundStyle(SemanticColor.warningText)
                .padding(.top, Spacing.lg)
            Text("Estas frases só entram no laudo quando você dita o achado. Você pode mudar a redação; o dado do exame e a frase em si não podem sair.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
                .padding(.bottom, Spacing.xs)

            ForEach(achados) { achado in
                ForEach(achado.variantes, id: \.id) { v in
                    if let texto = v.frase ?? v.corpoExemplo {
                        Button {
                            guard v.editavel else { return }
                            varianteDeAchado = AchadoEmFoco(slot: achado.slot, variante: v, texto: texto)
                        } label: {
                            Text(texto.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(TextStyle.body)
                                .foregroundStyle(v.editavel ? AppSurface.textPrimary : AppSurface.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(!v.editavel)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func frase(_ linha: (slot: CatalogSlot, frase: String, variante: CatalogVariant)) -> some View {
        let op = operacao(de: linha.slot.id)
        let removida = op?.op == "remove_slot"
        let trocadaPor = op?.op == "replace_phrase" ? op?.value : nil
        let efeito = efeitoPorSlot[linha.slot.id]

        VStack(alignment: .leading, spacing: 3) {
            Button {
                abrir(linha.slot, frase: linha.frase, editavel: linha.variante.editavel)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    // A frase original — riscada quando muda ou sai
                    if let efeito {
                        Text(efeito.antes.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(AppSurface.textMuted)
                            .strikethrough()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if removida || trocadaPor != nil {
                        Text(semPlaceholders(linha.frase))
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(AppSurface.textMuted)
                            .strikethrough()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        fraseComDados(linha.frase, cor: AppSurface.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // O que o ACHADO põe no lugar
                    if let efeito {
                        Text(efeito.corpo.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(SemanticColor.warningText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let c = efeito.conclusao {
                            Text("na conclusão: \(c.trimmingCharacters(in: .whitespacesAndNewlines))")
                                .font(TextStyle.caption)
                                .foregroundStyle(SemanticColor.warningText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // A redação DELE — some quando o achado já assumiu a frase,
                    // porque ali ela não se aplica.
                    if let nova = trocadaPor, efeito == nil {
                        fraseComDados(nova, cor: SemanticColor.successText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if removida && efeito == nil {
                        Text("não aparece mais no laudo")
                            .font(TextStyle.caption)
                            .italic()
                            .foregroundStyle(AppSurface.textMuted)
                    }
                    if !linha.variante.editavel && op == nil && efeito == nil {
                        Text("escrita pelo sistema")
                            .font(TextStyle.caption)
                            .foregroundStyle(AppSurface.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            // Frases que ele acrescentou depois desta. Nascem como slot novo no
            // backend e não existem no catálogo — sem desenhá-las aqui, ele
            // acrescentaria uma frase e não a veria.
            ForEach(inseridas(apos: linha.slot.id)) { ins in
                Button {
                    Task { await aplicar(operacoes.filter { $0.id != ins.id }) }
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Text("+").foregroundStyle(SemanticColor.successText)
                        VStack(alignment: .leading, spacing: 1) {
                            fraseComDados(ins.value ?? "", cor: SemanticColor.successText)
                            Text("toque para desfazer")
                                .font(TextStyle.caption)
                                .foregroundStyle(AppSurface.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    private var conclusaoAcrescentada: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(estado?.catalogo.cabecalhos.conclusao ?? "")
                .font(TextStyle.caption)
                .tracking(1)
                .foregroundStyle(AppSurface.textMuted)
            ForEach(itensDeConclusao) { item in
                Button {
                    Task { await aplicar(operacoes.filter { $0.id != item.id }) }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("+ \(item.value ?? "")")
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(SemanticColor.successText)
                        Text("toque para desfazer")
                            .font(TextStyle.caption)
                            .foregroundStyle(AppSurface.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Spacing.sm)
    }

    private var rodape: some View {
        VStack(spacing: Spacing.xs) {
            if temRascunho {
                Text("\(operacoes.count) alteração(ões) ainda não valem nos seus laudos")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textSecondary)
                Button {
                    Task { await publicar() }
                } label: {
                    Text(salvando ? "Publicando…" : "Passar a usar nos meus laudos")
                        .font(TextStyle.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(BrandColor.primary, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(salvando)
                Button("Descartar alterações") {
                    Task { await aplicar([]) }
                }
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .disabled(salvando)
            } else if estado?.publicado != nil {
                Button("Voltar ao modelo padrão") {
                    Task { await desligar() }
                }
                .font(TextStyle.bodyMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .disabled(salvando)
            }
        }
        .padding(Spacing.md)
        .background(AppSurface.card)
        .overlay(alignment: .top) {
            Rectangle().fill(AppSurface.border).frame(height: 0.5)
        }
    }

    // MARK: - Sheets

    private func acoesDaFrase(_ slot: CatalogSlot) -> some View {
        // Caminho LEGADO (backend anterior a `modelos`) — as linhas montadas
        // pela própria tela. O caminho novo abre `slotDoModelo`.
        let linha = linhasLegado.first(where: { $0.slot.id == slot.id })
        let editavel = linha?.variante.editavel ?? false
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            if !editavel {
                Text("Esta frase não pode ser mudada")
                    .font(TextStyle.bodyLargeSemibold)
                Text(linha?.variante.motivo ?? "")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
            } else {
                Button("Trocar a redação") {
                    textoEmEdicao = operacao(de: slot.id)?.value ?? linha?.frase ?? ""
                    slotEmFoco = nil
                    modoEdicao = .trocar(slot)
                }
                .font(TextStyle.bodyLargeMedium)
                Divider()
                Button("Acrescentar frase depois desta") {
                    textoEmEdicao = ""
                    slotEmFoco = nil
                    modoEdicao = .depois(slot)
                }
                .font(TextStyle.bodyLargeMedium)
                Divider()
                if operacao(de: slot.id) != nil {
                    Button("Desfazer esta alteração", role: .destructive) {
                        let restantes = operacoes.filter {
                            !($0.op != "insert_phrase_after" && $0.slot == slot.id)
                        }
                        slotEmFoco = nil
                        Task { await aplicar(restantes) }
                    }
                    .font(TextStyle.bodyLargeMedium)
                } else if slot.obrigatorio {
                    Text("Esta frase é obrigatória e não pode sair do laudo.")
                        .font(TextStyle.footnote)
                        .foregroundStyle(AppSurface.textMuted)
                } else if !slot.podeSerRemovido {
                    // Slot de achado alterado: condicional, mas não removível.
                    Text("Esta frase descreve um achado alterado. Ela só aparece quando você dita o achado — e por isso não pode ser tirada do modelo.")
                        .font(TextStyle.footnote)
                        .foregroundStyle(AppSurface.textMuted)
                } else {
                    Button("Tirar do laudo", role: .destructive) {
                        let novas = operacoes.filter {
                            !($0.op != "insert_phrase_after" && $0.slot == slot.id)
                        } + [.removeSlot(slot.id)]
                        slotEmFoco = nil
                        Task { await aplicar(novas) }
                    }
                    .font(TextStyle.bodyLargeMedium)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
    }

    private func editorDeTexto(_ modo: ModoEdicao) -> some View {
        let slot: CatalogSlot? = {
            switch modo {
            case .trocar(let s), .depois(let s): return s
            case .conclusao: return nil
            }
        }()
        let titulo: String = {
            switch modo {
            case .trocar: return "Como você prefere escrever"
            case .depois: return "Frase a acrescentar depois"
            case .conclusao: return "Item a acrescentar na conclusão"
            }
        }()

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(titulo).font(TextStyle.bodyLargeSemibold)

            // Os dados do exame que a frase pode usar. Tocar insere no ponto
            // final do texto — o médico não precisa decorar a grafia exata da
            // chave, que é a parte chata de escrever isto à mão.
            if case .trocar = modo {
                let obrig = slot?.placeholdersObrigatorios ?? []
                let faltando = obrig.filter { !textoEmEdicao.contains("{\($0)}") }

                if !faltando.isEmpty {
                    // Avisa AQUI, não só ao salvar: o servidor recusaria, mas o
                    // médico já teria perdido a frase que estava escrevendo.
                    Label(
                        "Falta \(faltando.map { "{\($0)}" }.joined(separator: ", ")) — é o dado medido no exame, e sem ele o laudo perderia a medida.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.warningText)
                } else if !obrig.isEmpty {
                    Label(
                        "Conserve \(obrig.map { "{\($0)}" }.joined(separator: ", ")) — é o dado medido no exame.",
                        systemImage: "checkmark.circle"
                    )
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textSecondary)
                }

                if !obrig.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(obrig, id: \.self) { campo in
                                Button {
                                    textoEmEdicao += "{\(campo)}"
                                } label: {
                                    Text(rotuloDoDado(campo))
                                        .font(TextStyle.caption)
                                        .foregroundStyle(BrandColor.primaryDeep)
                                        .padding(.horizontal, Spacing.xs)
                                        .padding(.vertical, 4)
                                        .background(BrandColor.primarySoft, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            TextEditor(text: $textoEmEdicao)
                .font(TextStyle.bodyLarge)
                .frame(minHeight: 110)
                .padding(Spacing.xs)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(AppSurface.border, lineWidth: 1)
                )

            Button {
                let v = textoEmEdicao.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !v.isEmpty else { return }
                var novas = operacoes
                switch modo {
                case .trocar(let s):
                    novas = novas.filter { !($0.op != "insert_phrase_after" && $0.slot == s.id) }
                    novas.append(.replacePhrase(slot: s.id, value: v))
                case .depois(let s):
                    novas.append(.insertPhraseAfter(anchor: s.id, value: v))
                case .conclusao:
                    novas.append(.appendConclusionItem(v))
                }
                modoEdicao = nil
                Task { await aplicar(novas) }
            } label: {
                Text("Guardar")
                    .font(TextStyle.bodySemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(BrandColor.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!podeGuardar(modo))
            Spacer()
        }
        .padding(Spacing.lg)
    }

    /// Guardar só quando a frase tem conteúdo E conserva os dados obrigatórios.
    /// Deixar salvar e o servidor recusar seria tecnicamente correto e
    /// péssimo: o médico perderia o que escreveu.
    private func podeGuardar(_ modo: ModoEdicao) -> Bool {
        let v = textoEmEdicao.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return false }
        if case .trocar(let s) = modo {
            return s.placeholdersObrigatorios.allSatisfy { v.contains("{\($0)}") }
        }
        return true
    }

    // MARK: - Ações

    private func abrir(_ slot: CatalogSlot, frase: String, editavel: Bool) {
        // Com um achado ativo a tela é leitura: aquelas frases são do sistema.
        guard variacaoSelecionada == nil else { return }
        slotEmFoco = slot
    }

    private func carregar() async {
        carregando = true
        erro = nil
        aguardandoServidor = false
        // A lista de categorias e o modelo da categoria atual são consultas
        // INDEPENDENTES — em série, a tela esperava as duas somadas por nada.
        // `categorias()` nunca lança (cai no fallback), então pode correr solta.
        let listaPendente: Task<[ModelCustomizationService.CategoriaDaBiblioteca]?, Never>? =
            categoriasDoServidor
            ? nil
            : Task { await ModelCustomizationService.categorias() }
        if categorias.isEmpty { categoria = categoriaInicial }
        do {
            let e = try await ModelCustomizationService.fetch(categoria: categoria)
            estado = e
            // O que o médico está editando: o rascunho se houver, SENÃO o publicado.
            //
            // Ler só o rascunho era perda de dados: publicar zera o rascunho e move
            // as operações para `publicado`, então a tela voltava ao modelo padrão
            // ("não salvou") e a próxima edição partia de lista vazia — publicar de
            // novo apagava em silêncio tudo o que já estava publicado.
            operacoes = e.rascunho?.operations ?? e.publicado?.operations ?? []
        } catch is FeatureNotDeployed {
            aguardandoServidor = true
            self.erro = FeatureNotDeployed().errorDescription
        } catch {
            self.erro = error.localizedDescription
        }
        if let listaPendente {
            if let vindas = await listaPendente.value {
                categorias = vindas
                categoriasDoServidor = true
            } else if categorias.isEmpty {
                // Falhou e ainda não há nada na tela: mostra o mínimo, mas
                // `categoriasDoServidor` fica falso — a próxima carga tenta de novo.
                categorias = ModelCustomizationService.categoriasFallback
            }
        }
        carregando = false
    }

    private func aplicar(_ novas: [ReportOperation]) async {
        salvando = true
        recusa = nil
        do {
            if novas.isEmpty {
                try await ModelCustomizationService.discardDraft(categoria: categoria)
                operacoes = []
            } else {
                let r = try await ModelCustomizationService.saveDraft(
                    categoria: categoria, operations: novas
                )
                operacoes = r.operations
            }
            await carregar()
        } catch let recusado as CustomizationRefusal {
            // A recusa é informação, não falha: o backend explica por que aquela
            // alteração não pode valer. O rascunho local volta ao que era.
            recusa = recusado.reasons.isEmpty ? [recusado.message] : recusado.reasons
            // Mesma regra do carregamento: volta ao rascunho, ou ao publicado.
            operacoes = estado?.rascunho?.operations ?? estado?.publicado?.operations ?? []
        } catch {
            erro = error.localizedDescription
        }
        salvando = false
    }

    private func publicar() async {
        salvando = true
        recusa = nil
        do {
            try await ModelCustomizationService.publish(categoria: categoria)
            await carregar()
        } catch let recusado as CustomizationRefusal {
            recusa = recusado.reasons.isEmpty ? [recusado.message] : recusado.reasons
        } catch {
            erro = error.localizedDescription
        }
        salvando = false
    }

    private func restaurar(_ versao: Int) async {
        salvando = true
        recusa = nil
        do {
            try await ModelCustomizationService.restore(categoria: categoria, versao: versao)
            await carregar()
        } catch let recusado as CustomizationRefusal {
            recusa = recusado.reasons.isEmpty ? [recusado.message] : recusado.reasons
        } catch {
            erro = error.localizedDescription
        }
        salvando = false
    }

    private func desligar() async {
        salvando = true
        do {
            try await ModelCustomizationService.turnOff(categoria: categoria)
            await carregar()
        } catch {
            erro = error.localizedDescription
        }
        salvando = false
    }

    // MARK: - Texto

    /// O nome de um dado, como o médico o lê.
    ///
    /// O fallback existente — trocar `_` por espaço no nome da variável —
    /// produzia "dorso sufixo" e "peso extras". Com dois ou três dados
    /// adjacentes virava "apresentacaodorso sufixopolo sufixo", que foi o que o
    /// Luiz leu na tela. O servidor manda os rótulos; o fallback só vale contra
    /// backend antigo.
    private func rotuloDoDado(_ campo: String) -> String {
        estado?.catalogo.rotulosVariaveis?[campo]
            ?? campo.replacingOccurrences(of: "_", with: " ")
    }

    /// `{dbp}` vira um pedaço destacado: é dado do exame, não texto fixo.
    private func fraseComDados(_ frase: String, cor: Color) -> Text {
        var resultado = Text("")
        var restante = Substring(frase)
        while let abre = restante.firstIndex(of: "{"),
              let fecha = restante[abre...].firstIndex(of: "}") {
            let antes = String(restante[restante.startIndex..<abre])
            let campo = rotuloDoDado(String(restante[restante.index(after: abre)..<fecha]))
            // Os colchetes separam dados ADJACENTES. Sem eles, três seguidos
            // se fundem numa palavra só e o médico não sabe onde um termina.
            resultado = resultado
                + Text(antes).foregroundStyle(cor)
                + Text("[\(campo)]").foregroundStyle(BrandColor.primary).bold()
            restante = restante[restante.index(after: fecha)...]
        }
        resultado = resultado + Text(String(restante)).foregroundStyle(cor)
        return resultado.font(TextStyle.bodyLarge)
    }

    private func semPlaceholders(_ frase: String) -> String {
        var saida = ""
        var restante = Substring(frase)
        while let abre = restante.firstIndex(of: "{"),
              let fecha = restante[abre...].firstIndex(of: "}") {
            saida += restante[restante.startIndex..<abre]
            saida += String(restante[restante.index(after: abre)..<fecha])
                .replacingOccurrences(of: "_", with: " ")
            restante = restante[restante.index(after: fecha)...]
        }
        return saida + restante
    }
}

#Preview {
    NavigationStack { LibraryView() }
}
