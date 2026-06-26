# P7 — Painel Admin Testbench (LaudoUSG Lab)

> Layout ASCII das 5 telas pra alimentar `/frontend-design` e `/impeccable`.
> Stack: Next.js 15 App Router + Tailwind + Supabase (auth + DB) + workspace monorepo.
> URL alvo: `lab.laudousg.com` (subdomínio Vercel).

---

## 🎯 Propósito do painel

Permitir ao médico-empreendedor (Luiz) **iterar regras/snippets/templates do RAG sem precisar mexer em código**, com observabilidade total de como cada laudo foi montado.

Funcionalidades-chave:
1. **Rodar inputs de teste** e ver o laudo gerado em tempo real, com source map de TUDO que entrou (similarity scores incluídos)
2. **Editar markdown** dos blocks (regras, frases, templates) com versionamento git
3. **Visualizar audit** das últimas gerações (priority logic em ação, blocks skipped)
4. **Re-ingestar** automaticamente após salvar edit

---

## 🎨 Design tokens (alinhados com o app iOS)

**Cores principais** (de `LaudoUSG/DesignSystem/Color+Tokens.swift`):
- `primary` = `#059669` (emerald-600)
- `primaryDeep` = `#065F46` (emerald-800)
- `primarySoft` = `#D1FAE5` (emerald-100)
- `primaryTint` = `#ECFDF5` (emerald-50)
- `wordmark` = `#18533F` (verde escuro brand)

**Cores semânticas:**
- Erro = `#DC2626` (red-600)
- Aviso = `#D97706` (amber-600)
- Sucesso = `#059669` (= primary)
- Info = `#0EA5E9` (sky-500)
- Hidrocor (placeholder) = `#6D28D9` (violet-700) com fundo `#EDE9FE` (violet-100)

**Tipografia:**
- Sans: Inter (igual ao app)
- Display: Barlow (igual)
- Mono: JetBrains Mono / SF Mono (pra editor markdown e código)

**Espaçamento (Tailwind padrão):**
- Container max: `max-w-7xl`
- Padding global: `px-6 lg:px-8`
- Espaçamento cards: `gap-6`

---

## 🗂 Estrutura global de navegação

```
┌──────────────────────────────────────────────────────────────────────┐
│  ☰  LaudoUSG.lab    [Categoria ▾]                  Luiz  [Sair]  🌙  │ ← Header (sticky)
├──────────────────────────────────────────────────────────────────────┤
│ ┌───────┐                                                            │
│ │       │  ┌──────────────────────────────────────────────────────┐  │
│ │ ⎙ Home│  │                                                      │  │
│ │       │  │           CONTEÚDO DA TELA ATIVA                     │  │
│ │ 🧪 Test│  │                                                     │  │
│ │ 📋 Audit  │                                                     │  │
│ │ ✎ Blocks│  │                                                    │  │
│ │ 👁 Review │  │                                                    │  │
│ │       │  │                                                      │  │
│ │ ⚙ Config│  │                                                     │  │
│ └───────┘  └──────────────────────────────────────────────────────┘  │
│ Sidebar                                                              │
└──────────────────────────────────────────────────────────────────────┘
 64px       resto da viewport
```

**Sidebar (~64px collapsada / ~220px expandida no hover):**
- Home (⎙)
- Testbench (🧪)
- Audit (📋)
- Blocks Editor (✎)
- Reviewer (👁)
- Config (⚙) — settings de quotas, prompts globais, etc.

**Header sticky:**
- Brand `LaudoUSG.lab` (logo + ".lab" em emerald-deep)
- Seletor de categoria global (afeta scope de várias telas)
- User menu (logout, theme toggle)

---

## 📺 TELA 1 — Home / Dashboard

```
┌──────────────────────────────────────────────────────────────────────┐
│  Olá Luiz 👋                                          [⚡ Novo teste]  │
│  Painel de calibração e diagnóstico do RAG                           │
│                                                                      │
│  ┌─────────────────────┬─────────────────────┬──────────────────────┐│
│  │  📚 Blocks ativos    │  ⚡ Laudos hoje      │  ⚠ Skipped médio    ││
│  │                     │                     │                      ││
│  │      487            │      23             │      4.2/laudo       ││
│  │   ↑ +12 esta sem    │   ↑ +18% vs ontem   │   ↓ -1.3 vs ontem   ││
│  └─────────────────────┴─────────────────────┴──────────────────────┘│
│                                                                      │
│  📂 Categorias                                                       │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │ OBSTETRICA          84 blocks    ★★★★★  últimos 7 laudos: 100% OK│ │
│  │ PELVE_FEMININA      99 blocks    ★★★★☆  últimos 7 laudos: 86%   │ │
│  │ TIREOIDE            66 blocks    ★★★★★  últimos 7 laudos: 100%  │ │
│  │ MAMARIA             84 blocks    ★★★★☆  últimos 7 laudos: 92%   │ │
│  │ DOPPLER_OBSTETRICO  66 blocks    ★★★★★  últimos 7 laudos: 100%  │ │
│  │ ABDOMEN_TOTAL       78 blocks    ★★★★☆  últimos 7 laudos: 85%   │ │
│  └──────────────────────────────────────────────────────────────────┘│
│                                                                      │
│  📰 Atividade recente                                                │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │ 14:35  TIREOIDE  — geração concluída, 24 blocks usados            ││
│  │ 14:21  ABDOMEN   — edição em "figado-variantes" → re-ingestado    ││
│  │ 13:58  OBSTETRICA— novo teste no testbench (input curto)           ││
│  │ 13:42  MAMARIA   — geração com warning RAG_EMPTY (corrigido)      ││
│  │                                          [Ver tudo →]              ││
│  └──────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

**Componentes-chave:**
- 3 cards de métricas no topo (total blocks, laudos hoje, skipped médio)
- Lista de categorias com mini-rating + indicador qualidade últimos 7 laudos
- Atividade recente (últimas 10-15 ações: gerações, edits, ingest)

---

## 📺 TELA 2 — Testbench (a mais importante)

```
┌──────────────────────────────────────────────────────────────────────┐
│  🧪 Testbench                              Categoria: [OBSTETRICA ▾] │
│                                            Style:     [CLÁSSICO ▾]   │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ INPUT (achados do médico):                                      │ │
│  │ ┌────────────────────────────────────────────────────────────┐  │ │
│  │ │ Cole ou digite aqui o input do médico…                     │  │ │
│  │ │ Exemplo: "30 semanas. Feto único cefálico. BCF 142. DBP    │  │ │
│  │ │ 7,5 cm. CC 27,3 cm. CA 23,0 cm. CF 5,4 cm. Peso 1240g…"   │  │ │
│  │ │                                                            │  │ │
│  │ └────────────────────────────────────────────────────────────┘  │ │
│  │ [ Inputs salvos ▾ ] [ 🎤 Gravar ] [ Limpar ]    [ ▶ Gerar laudo] │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─────────────────────────────────┬─────────────────────────────┐  │
│  │ 📄 LAUDO GERADO                  │ 🔍 SOURCE MAP                │  │
│  │ ──────────────────────────       │ ──────────────────────────  │  │
│  │ ULTRASSONOGRAFIA OBSTÉTRICA      │ Modelos:              2/2   │  │
│  │                                  │   ✓ template-padrao (100)   │  │
│  │ COMENTÁRIOS:                     │     sim=0.78                │  │
│  │ Exame realizado com transdutor…  │   ✓ template-inicial (100)  │  │
│  │ [ditado em violet — passa hover  │     sim=0.45  (não usado)   │  │
│  │  pra ver origem do bloco]        │                             │  │
│  │                                  │ Regras:              7/10   │  │
│  │ OS SEGUINTES ASPECTOS FORAM…     │   ✓ ordem-secoes (99)       │  │
│  │ Feto único, em apresentação      │     sim=0.42  universal     │  │
│  │ cefálica, com dorso à esquerda…  │   ✓ peso-fetal (75)         │  │
│  │                                  │     sim=0.71  ⚡ key match  │  │
│  │ CONCLUSÃO:                       │   ✓ liquido-amniotico (95)  │  │
│  │ 1) Gestação em torno de 30 sem.  │   ...                       │  │
│  │ 2) Líquido amniótico normal.     │                             │  │
│  │ 3) O peso fetal encontra-se      │ Frases:              4/8   │  │
│  │    abaixo do percentil 10…       │   ✓ biometria-fetal (75)    │  │
│  │ 4) Convém, a critério clínico…   │   ...                       │  │
│  │                                  │                             │  │
│  │ [Copiar] [Comparar com baseline] │ ⚠ Skipped (cortados quota): │  │
│  │                                  │   ✗ template-inicial (100)  │  │
│  │                                  │     sim=0.45  motivo: quota  │  │
│  │                                  │   ✗ Cisto hepático (legacy) │  │
│  │                                  │     sim=0.62  motivo: kind  │  │
│  └─────────────────────────────────┴─────────────────────────────┘  │
│                                                                      │
│  ⚡ Estatísticas da geração                                          │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │ Tempo total: 8.3s   Structurer: 2.1s   Writer: 5.8s   Tokens: 2.3k││
│  │ Latência first-token: 4.2s    Custo OpenAI: ~$0.012               ││
│  └──────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

**Interações:**
- **Hover** num pedaço do laudo gerado → highlight do block correspondente no source map (e vice-versa)
- **Click** num block do source map → abre Editor (Tela 4) com aquele block em foco
- **Click** em skipped → abre detalhes (similarity, motivo da exclusão)
- **"Comparar com baseline"** → diff side-by-side com laudo gerado anteriormente (pra testar mudança de regra)

**Cores no source map:**
- Universal (priority 90+) = emerald-100 bg, emerald-700 text
- Contextual 75-80 = sky-100 bg, sky-700 text
- Contextual 60-70 = gray-100 bg, gray-700 text
- Skipped = red-50 bg, red-600 text (com strikethrough sutil)

---

## 📺 TELA 3 — Audit log

```
┌──────────────────────────────────────────────────────────────────────┐
│  📋 Audit log                                                        │
│  Filtros:  [Categoria ▾]  [Pipeline ▾]  [Últimos 7 dias ▾]  [🔍]    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │ ╳ ABDOMEN_TOTAL   17:14   23s   26 blocks   7 skipped   ⚡         ││
│  │     "Fígado de aspecto normal. Vesícula com cálculo…"             ││
│  │     ▸ ver detalhes                                                ││
│  ├──────────────────────────────────────────────────────────────────┤│
│  │ ✓ DOPPLER_OBSTETR 16:49   12s   20 blocks   0 skipped              ││
│  │     "32 semanas. Feto único cefálico…"                            ││
│  ├──────────────────────────────────────────────────────────────────┤│
│  │ ⚠ MAMARIA         16:47   8s    22 blocks   0 skipped              ││
│  │     "Cisto simples mama direita 0,8cm…"                            ││
│  │     ⚠ 2 pontos a revisar no sanity                                ││
│  ├──────────────────────────────────────────────────────────────────┤│
│  │ ...                                                                ││
│  └──────────────────────────────────────────────────────────────────┘│
│                                                                      │
│  Detalhe da seleção:                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │ generation_audit.id = b968d77e-…                                  ││
│  │                                                                   ││
│  │ Input:    "Fígado de aspecto normal..."                            ││
│  │ Output:   [expand]                                                ││
│  │ Pipeline: v1   prompt_version: 1.2   contract: a3b2…              ││
│  │                                                                   ││
│  │ Retrieved (26):                          Skipped (7):              ││
│  │ ┌─────────────────────────────┐         ┌─────────────────────┐   ││
│  │ │ modelo  100   0.755   templ │         │ modelo  88  0.655   │   ││
│  │ │ regra    99   0.641   funca │         │ modelo  70  0.641   │   ││
│  │ │ ...                          │         │ frase   80  0.527   │   ││
│  │ └─────────────────────────────┘         └─────────────────────┘   ││
│  │ [Abrir no Testbench] [Reviewer] [Re-rodar com regra X]            ││
│  └──────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

**Indicadores:**
- ✓ verde = OK
- ⚠ amarelo = warning (sanity issues, RAG_EMPTY)
- ╳ vermelho = erro
- ⚡ destaque = laudo com skipped grande (possível calibração ruim)

---

## 📺 TELA 4 — Blocks Editor (Markdown)

```
┌──────────────────────────────────────────────────────────────────────┐
│  ✎ Blocks Editor                                                     │
│                                                                      │
│  ┌──────────────────┬──────────────────────────────────────────────┐ │
│  │ 📁 Tree           │ 📄 figado-variantes.md          [versionado] │ │
│  │                  │                                                │ │
│  │ ▾ OBSTETRICA     │ ┌────────────────────────────────────────────┐│ │
│  │   ▸ modelo  (2)  │ │ ---                                        ││ │
│  │   ▾ regra   (8)  │ │ id: abdomen-total-regra-figado-variantes  ││ │
│  │     ordem-secoes │ │ category: ABDOMEN_TOTAL                    ││ │
│  │     preservar… │ │ kind: regra                                 ││ │
│  │     ★ peso-fetal │ │ priority: 75                               ││ │
│  │   ▸ frase   (6)  │ │ priority_tier: contextual                  ││ │
│  │   ▸ conclusao(3) │ │ ---                                        ││ │
│  │   ▸ excecao (2)  │ │                                            ││ │
│  │                  │ │ GATILHOS DE APLICAÇÃO:                     ││ │
│  │ ▸ PELVE_FEMININA │ │ - esteatose                                 ││ │
│  │ ▸ TIREOIDE       │ │ - doença hepática crônica                  ││ │
│  │ ▸ MAMARIA        │ │ - área poupada                              ││ │
│  │ ▸ DOPPLER_OBSTET │ │ - cisto hepático                            ││ │
│  │ ▾ ABDOMEN_TOTAL  │ │                                            ││ │
│  │   ▸ modelo  (2)  │ │ ESTEATOSE HEPÁTICA LEVE                    ││ │
│  │   ▾ regra   (10) │ │ Corpo: "Fígado de dimensões normais, com   ││ │
│  │     ★ figado-vari│ │ discreto aumento da ecogenicidade…"        ││ │
│  │     vesicula-…  │ │                                            ││ │
│  │     rins-vari…  │ │ Conclusão: "Esteatose hepática, grau leve."││ │
│  │     ...         │ │                                            ││ │
│  │                  │ │ ESTEATOSE HEPÁTICA MODERADA                ││ │
│  │ + Novo bloco     │ │ Corpo: "Fígado de dimensões normais,       ││ │
│  │                  │ │ apresentando aumento difuso…"              ││ │
│  │                  │ │                                            ││ │
│  │                  │ │ [...]                                      ││ │
│  │                  │ └────────────────────────────────────────────┘│ │
│  │                  │                                                │ │
│  │                  │ Versão atual: 1.0.0 (5 dias)  Último edit: c1 │ │
│  │                  │ Edits recentes: [2026-05-21] [2026-05-19]    │ │
│  │                  │                                                │ │
│  │                  │ [💾 Salvar (re-ingest)] [Revert] [Visualizar]  │ │
│  └──────────────────┴──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**Funcionalidades:**
- Tree navegável (categoria → kind → block)
- Editor markdown (Codemirror 6 ou Monaco)
- Frontmatter editável visualmente (não só raw YAML)
- Indicador ★ pra blocks recentemente alterados
- Botão **"Salvar (re-ingest)"** dispara: commit no git → ingest na DB (similar ao script atual)
- Histórico de versões (git log do arquivo)
- Botão "Visualizar" abre preview de como o block fica no system message

---

## 📺 TELA 5 — Reviewer (forense)

```
┌──────────────────────────────────────────────────────────────────────┐
│  👁 Reviewer  — Laudo b968d77e (ABDOMEN_TOTAL, 17:14)                │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Laudo gerado:                                                    │ │
│  │                                                                  │ │
│  │ ULTRASSONOGRAFIA DO ABDOME TOTAL                                 │ │
│  │ ╔══════════════════════════════════════╗ ← hover destaca       │ │
│  │ ║ COMENTÁRIOS:                          ║   source: template-padrao │
│  │ ║ Exame realizado com transdutor de 4.0║   priority: 100        │ │
│  │ ╚══════════════════════════════════════╝   similarity: 0.755   │ │
│  │                                                                  │ │
│  │ OS SEGUINTES ASPECTOS FORAM OBSERVADOS:                          │ │
│  │ Fígado de aspecto normal.                                        │ │
│  │ ┌──────────────────────────────────────────────────────────┐    │ │
│  │ │ Vesícula biliar com imagem hiperecoica, móvel, medindo 1.2 cm│ │
│  │ │ no seu maior eixo, ocasionando sombra acústica.              │ │
│  │ └──────────────────────────────────────────────────────────┘    │ │
│  │   ↑ source: vesicula-e-vias-biliares-variantes (75)             │ │
│  │     similarity: 0.71  · contextual                              │ │
│  │     ⓘ Bloco editado em 2026-05-21 14:21                         │ │
│  │     [Abrir no editor] [Ver histórico]                          │ │
│  │                                                                  │ │
│  │ Rim direito com cisto simples de 2,3 x 1,4 x 1,8 cm…              │ │
│  │ ↑ source: rins-variantes (75)  · sim 0.68                         │ │
│  │                                                                  │ │
│  │ […]                                                              │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  📈 Análise:                                                         │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ • Blocks usados:        7 de 26 retrieved (27% aproveitamento)  │ │
│  │ • Blocks ignorados:     19 (de baixa similarity, esperado)      │ │
│  │ • Blocks skipped:        7 (cortados por quota)                 │ │
│  │ • Cobertura textual:    96% do laudo veio de blocks identificados│ │
│  │ • Trechos do LLM puro:  4% (transições, conectores)             │ │
│  │                                                                  │ │
│  │ ⚠ Sugestões:                                                    │ │
│  │ • "Cisto hepático simples" foi skipped (quota frase=8 estourou) │ │
│  │   Considere fundir variants ou bumpar priority                  │ │
│  │ • Block "Modelo alternativo Doppler esplânc" entrou com sim 0.65│ │
│  │   mas não foi usado no output. Investigar relevância.           │ │
│  └────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**Funcionalidades:**
- Hover/click numa parte do laudo → balão flutuante com source + priority + similarity + link pro editor
- Análise quantitativa: cobertura, blocks usados vs ignorados, % LLM puro
- Sugestões automáticas baseadas em padrões (skipped frequente, similarity baixa, etc.)

---

## 📐 Componentes reusáveis a criar

| Componente | Uso |
|---|---|
| `<MetricCard>` | Cards do dashboard (número grande + delta + label) |
| `<BlockChip>` | Pill com priority + similarity + kind (cor variável) |
| `<CategoryTree>` | Sidebar tree no Blocks Editor |
| `<MarkdownEditor>` | Codemirror wrapper com syntax highlight + frontmatter form |
| `<SourceMapBadge>` | Marca trecho do laudo com block origem (hover) |
| `<SimilarityBar>` | Barra horizontal 0-1 com cor gradient |
| `<AuditRow>` | Item da lista de audit (categoria, tempo, blocks, status) |
| `<Sidebar>` | Layout principal com nav |
| `<PageHeader>` | Header sticky com breadcrumb + actions |

---

## 🔐 Auth & permissões

- **Single user inicial**: whitelist por email (`luizp02121@gmail.com` ou similar)
- Supabase auth com magic link
- Middleware Next.js (`middleware.ts`) bloqueia rotas se não autenticado
- Tabela `admin_users` futuro (quando expandir)

---

## 🛠 Stack técnica detalhada

```
apps/lab/
├── package.json                    next 15, react 19, tailwind 4
├── next.config.ts
├── tsconfig.json                   extends ../../tsconfig.base.json
├── tailwind.config.ts              extends tokens do app iOS
├── middleware.ts                   auth + redirect
├── src/
│   ├── app/
│   │   ├── layout.tsx              sidebar + header sticky
│   │   ├── page.tsx                home/dashboard
│   │   ├── testbench/
│   │   │   ├── page.tsx
│   │   │   └── components/
│   │   ├── audit/
│   │   │   ├── page.tsx
│   │   │   └── [id]/page.tsx       detalhe de uma geração
│   │   ├── blocks/
│   │   │   ├── page.tsx
│   │   │   └── [category]/[kind]/[slug]/page.tsx
│   │   ├── reviewer/
│   │   │   └── [id]/page.tsx
│   │   ├── login/page.tsx
│   │   └── api/
│   │       ├── testbench/run/route.ts       proxy pra /api/generate
│   │       ├── blocks/[...path]/route.ts    CRUD markdown
│   │       └── audit/[id]/route.ts          query Supabase
│   ├── components/
│   ├── lib/
│   │   ├── supabase/
│   │   └── knowledge/             leitura do packages/knowledge/
│   └── styles/
│       └── globals.css
```

---

## 🚦 Próximas ações (em paralelo)

1. **Você roda `/frontend-design`** com este arquivo como input → mockups visuais
2. **Você roda `/impeccable`** depois pra polir componentes
3. **dex1** setup `apps/lab/` skeleton (Next.js 15 + Tailwind + Supabase auth) — em paralelo
4. **c1 (eu)** orquestra + implementa partes mais complexas (testbench, source map, etc.)
5. **Claude Code** opera Supabase MCP pra queries necessárias
