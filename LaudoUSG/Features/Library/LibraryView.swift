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
struct LibraryView: View {
    var categoria: String = "OBSTETRICA"

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

    /// Slots na ordem do laudo, com a frase padrão. Gemelar repete o mesmo
    /// slot; aqui ele aparece uma vez só.
    private var linhas: [(slot: CatalogSlot, frase: String, variante: CatalogVariant)] {
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

    private var conteudo: some View {
        VStack(spacing: 0) {
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
                    if !itensDeConclusao.isEmpty { conclusaoAcrescentada }
                    Button {
                        textoEmEdicao = ""
                        modoEdicao = .conclusao
                    } label: {
                        Label("Acrescentar item à conclusão", systemImage: "plus.circle")
                            .font(TextStyle.bodyMedium)
                    }
                    .foregroundStyle(BrandColor.primary)
                    .padding(.top, Spacing.xs)
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
                Text("Este é o modelo padrão do laudo obstétrico. Toque em qualquer frase para mudar a redação, tirá-la do laudo, ou acrescentar outra depois dela.")
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

    private var modeloEmTextoCorrido: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(estado?.catalogo.cabecalhos.corpo ?? "")
                .font(TextStyle.caption)
                .tracking(1)
                .foregroundStyle(AppSurface.textMuted)
                .padding(.bottom, Spacing.xs)

            ForEach(linhas, id: \.slot.id) { linha in
                frase(linha)
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
        let linha = linhas.first(where: { $0.slot.id == slot.id })
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
                                    Text(campo.replacingOccurrences(of: "_", with: " "))
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

    /// `{ig_semanas}` vira um pedaço destacado: é dado do exame, não texto fixo.
    private func fraseComDados(_ frase: String, cor: Color) -> Text {
        var resultado = Text("")
        var restante = Substring(frase)
        while let abre = restante.firstIndex(of: "{"),
              let fecha = restante[abre...].firstIndex(of: "}") {
            let antes = String(restante[restante.startIndex..<abre])
            let campo = String(restante[restante.index(after: abre)..<fecha])
                .replacingOccurrences(of: "_", with: " ")
            resultado = resultado
                + Text(antes).foregroundStyle(cor)
                + Text(campo).foregroundStyle(BrandColor.primary).bold()
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
