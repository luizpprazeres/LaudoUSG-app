# ADR-0002 — Mapping `/laudousg/` → `packages/knowledge/`

| Campo | Valor |
|---|---|
| **Status** | Accepted |
| **Data** | 2026-05-20 |
| **Autores** | c1 (orquestrador), Explore agent (sondagem read-only) |
| **Supersedes** | nada |
| **Relacionado** | ADR-0001 (constraint 1.5.1 — `/laudousg/` é read-only) |

---

## 1. Contexto

ADR-0001 estabeleceu que `/laudousg/` (web em produção) é a **fonte de partida read-only** pra construir `packages/knowledge/` da nova arquitetura. Este ADR documenta o **mapeamento concreto**: quais arquivos do `/laudousg/` viram quais arquivos/tabelas em `packages/knowledge/`, com decisões de transformação.

Sondagem feita em 2026-05-20 pelo Explore agent (read-only). Tudo abaixo confirmado contra arquivos reais.

---

## 2. Correções factuais ao ADR-0001 (descobertas na sondagem)

### 2.1 São 34 categorias, não 13

ADR-0001 mencionava "13 categorias". Errado. Real: **34 categorias conhecidas** (em enum `Category` no `/laudousg/`):

**27 ativas** (em `ACTIVE_CATEGORIES`):
- **Obstétricas (3):** `OBSTETRICA`, `DOPPLER_OBSTETRICO`, `MORFOLOGICO`
- **Abdominais (3):** `ABDOMEN_TOTAL`, `ABDOMEN_TOTAL_DOPPLER`, `ABDOMEN_SUPERIOR`
- **Geniturinários (4):** `VIAS_URINARIAS`, `ESCROTAL`, `PROSTATA_TRANSRETAL`, `PROSTATA_SUPRAPUBICA`
- **Endócrino/Cervical (3):** `TIREOIDE`, `PARATIREOIDE`, `CERVICAL`
- **Mamário (1):** `MAMARIA`
- **Pélvico (1):** `PELVE_FEMININA`
- **Vascular Doppler (8):** `DOPPLER_CAROTIDAS`, `DOPPLER_VENOSO_MMII`, `DOPPLER_VENOSO_MMII_MEDIDAS`, `DOPPLER_ARTERIAL_MMII`, `DOPPLER_VENOSO_MMSS`, `DOPPLER_ARTERIAL_MMSS`, `DOPPLER_RENAL`, `DOPPLER_FISTULA_AV`
- **Musculoesquelético (3):** `MUSCULOESQUELETICO`, `MUSCULOESQUELETICO_V2`, `MUSCULOESQUELETICO_RARAS`
- **Diversos (7):** `REGIAO_INGUINAL`, `PAREDE_ABDOMINAL`, `PARTES_MOLES`, `TRANSFONTANELA`, `QUADRIL_INFANTIL`, `OCULAR`, `TORAX`, `GLANDULAS_SALIVARES`

**7 históricas/legado** (em `CATEGORIES` mas não `ACTIVE`):
- `DOPPLER` (catchall vazia)
- (demais: a confirmar com Luiz)

**Implicação:** Roadmap §5 do ADR-0001 já foi ajustado pra refletir 27 categorias ativas em Fase 3 (não 13).

### 2.2 NÃO existe RAG em produção pra geração

ADR-0001 mencionou implicitamente "RAG via pgvector já em uso". **Errado.**

Real: pgvector está rodando, mas APENAS pra feed de Insights (`/laudousg/lib/insights/v2-runner.ts` usando `text-embedding-3-small`). Pipeline de geração de laudos usa **few-shots fixos** + prompts nativos + regras + sanity check síncrono. Não há similaridade semântica em produção.

**Implicação pro plano novo:** "RAG" na nova arquitetura é **trabalho novo**, não expansão do existente. Mantém-se a recomendação de usar pgvector (já há infra), mas a query/ingest do RAG de laudos é nova.

### 2.3 Pipeline atual é mais sofisticado do que o ADR-0001 sugere

O `lib/promptBuilder.ts` injeta no system message em ordem hierárquica:

1. `categoryRules` (prompt nativo de `categoryDefaults.ts`)
2. `subspecialtyRules` (overlay ativado por keywords)
3. `globalRulesBlock` (regras invariáveis)
4. `writingStyleOverlay` (classic/direct)
5. `fewShots` (exemplos validados)
6. `negativePrompts` (proibições)
7. `cotInstruction` (Chain-of-Thought interno, ~40 linhas)
8. `globalRules` do usuário (customizado)
9. `stylePreferences` (camadas)

**Implicação:** a nova arquitetura precisa preservar essa sofisticação. O Composer (etapa 3 do pipeline novo) precisa replicar a hierarquia, não simplificar.

---

## 3. Mapping arquivo-a-arquivo

### 3.1 Knowledge core (must-have pra Fase 1)

| `/laudousg/` (source, read-only) | `packages/knowledge/` (destino) | Transformação |
|---|---|---|
| `lib/categoryDefaults.ts` (4835 linhas, TS strings) | `templates/{categoria}/system-prompt.md` (27 arquivos) | **Quebra**: cada categoria vira um `.md` com frontmatter YAML (categoria, version, source_path, source_commit). Conteúdo da string TS vira corpo markdown. |
| `lib/fewShots.ts` + `docs/few-shots-por-categoria.md` (20 exemplos / 10 categorias) | `snippets/{categoria}/few-shots/{slug}.md` | Cada exemplo vira 1 `.md` com frontmatter (input, output, validated_by, source). |
| `lib/globalRules.ts` + `docs/global-rules.md` (50 linhas, 20+ regras) | `prompts/global-rules.md` | Copy direto + frontmatter (version, last_reviewed) |
| `lib/negativePrompting.ts` | `prompts/negative/{categoria}.md` | Quebra por categoria. Frontmatter. |
| `lib/subspecialty.ts` | `prompts/subspecialty/{categoria}.md` + `triggers/{categoria}.yaml` | Conteúdo das regras → markdown. Keywords/triggers → YAML. |
| `lib/sanityCheck/` (35 rule files .ts) | `validators/{categoria}/{rule}.ts` | **Copy direto** (TS continua TS — sanity check fica em código, não markdown). Reagrupado por categoria. |

### 3.2 Style layers (mover na Fase 2)

| Source | Destino | Notas |
|---|---|---|
| `lib/stylePreferencesBuilder.ts` | `prompts/style/preferences-builder.ts` | Copy. Lógica permanece em TS. |
| `lib/styleTransform.ts` | `prompts/style/transform.ts` | Copy. |
| `lib/writingStyleOverlay.ts` | `prompts/style/writing-overlay.md` | Conteúdo do overlay vira MD. Lógica de aplicação fica em TS no Composer. |

### 3.3 Tabelas/dados do Supabase (reusar, não migrar)

| Tabela existente em prod | Reuso na nova arquitetura |
|---|---|
| `user_profiles` | Reusa — quotas + plano + identificação |
| `user_settings` | Reusa — `global_rules_text`, `style_preferences`, `writing_style` |
| `category_settings` | Reusa — `rules_text`, `custom_phrases` por categoria |
| `templates` | Reusa — templates customizados por usuário |
| `reports` | Reusa — laudos gerados |
| `report_embeddings` (Insights) | NÃO reusa — escopo diferente. Cria nova `rag_blocks` se/quando RAG entrar |

### 3.4 NÃO copiar (lógica de orquestração específica do Next.js)

- `lib/promptBuilder.ts` → vai ser **reescrito** como `Composer` na nova arquitetura. Mas referência valiosa pra entender ordem hierárquica.
- `app/api/generate/route.ts` (290 linhas) → vai ser **reescrito** como pipeline modular. Estrutura básica preservada.
- `app/api/generate/multi-detect/route.ts` (140 linhas) → reescrito como step do Parser.
- `app/api/generate-rules/route.ts` (120 linhas) → reescrito ou removido (avaliar).
- `lib/llm/client.ts` → reusa lógica de fallback Groq/OpenAI, mas adapta pra novo wrapper.

### 3.5 Docs Markdown a copiar como referência

| Source | Destino |
|---|---|
| `docs/few-shots-por-categoria.md` | `packages/knowledge/docs/few-shots-source-of-truth.md` (read-only reference) |
| `docs/global-rules.md` | `packages/knowledge/docs/global-rules-history.md` |
| `docs/current-architecture-summary.md` | `packages/knowledge/docs/legacy-architecture.md` |
| `docs/few-shots-por-categoria.md` | manter referência cruzada |

---

## 4. Estrutura final proposta de `packages/knowledge/`

```
packages/knowledge/
├── README.md
├── normalizer/                                    # Etapa 0 do pipeline (ADR-0001 §1.5.2)
│   ├── rules.yaml                                 # substituições literais
│   ├── unit-patterns.yaml                         # regex de unidades
│   └── punctuation-rules.yaml                     # pontuação contextual
│
├── templates/                                     # System prompts por categoria
│   ├── OBSTETRICA/
│   │   ├── system-prompt.md                       # estrutura + regras + template
│   │   ├── sections.yaml                          # seções fixas (FUNÇÃO|REGRAS|TEMPLATES)
│   │   └── vocab.yaml                             # terminologia correta
│   ├── DOPPLER_OBSTETRICO/...
│   ├── ABDOMEN_TOTAL/...
│   └── ... (27 ativas)
│
├── snippets/                                      # Frases padronizadas + few-shots
│   ├── OBSTETRICA/
│   │   ├── few-shots/
│   │   │   ├── normal-com-dum-e-ila-reduzido.md
│   │   │   └── ...
│   │   ├── frases/
│   │   │   ├── liquido-amniotico-normal.md
│   │   │   ├── placenta-anterior-3o-tri.md
│   │   │   └── ...
│   │   └── README.md                              # índice da categoria
│   └── ... (uma pasta por categoria)
│
├── ranges/                                        # Medidas normais/patológicas
│   ├── OBSTETRICA.yaml                            # biometria, ILA, etc.
│   ├── DOPPLER_OBSTETRICO.yaml                    # IR/IP, percentis
│   ├── MAMARIA.yaml                               # BI-RADS, medidas
│   └── ...
│
├── prompts/                                       # Global + camadas
│   ├── global-rules.md                            # invariáveis (de globalRules.ts)
│   ├── negative/                                  # proibições por categoria
│   │   ├── OBSTETRICA.md
│   │   └── ...
│   ├── subspecialty/                              # overlays por categoria
│   │   ├── MUSCULOESQUELETICO.md
│   │   ├── triggers/
│   │   │   └── MUSCULOESQUELETICO.yaml            # keywords ativadoras
│   │   └── ...
│   ├── style/
│   │   ├── preferences-builder.ts                 # TS reutilizado
│   │   ├── transform.ts
│   │   └── writing-overlay.md                     # conteúdo MD
│   └── cot/
│       └── instruction.md                         # Chain-of-Thought
│
├── validators/                                    # Sanity checks (continua TS)
│   ├── OBSTETRICA/
│   │   ├── biometria-faixa-ig.ts
│   │   ├── ila-range.ts
│   │   └── ...
│   ├── DOPPLER_OBSTETRICO/...
│   └── ... (de lib/sanityCheck/ atual, reagrupado)
│
├── schemas/                                       # JSON Schema
│   ├── generate-request.json                      # contrato de entrada
│   ├── generate-response.json                     # contrato de saída
│   └── sse-events/                                # cada evento SSE
│       ├── structured.json
│       ├── token.json
│       └── ...
│
└── docs/                                          # Referências
    ├── few-shots-source-of-truth.md               # cópia de /laudousg/docs/
    ├── global-rules-history.md
    ├── legacy-architecture.md
    └── migration-log.md                           # log de o que foi migrado quando
```

---

## 5. Frontmatter padrão por tipo de arquivo

### 5.1 Template (system prompt)

```markdown
---
id: obstetrica-system-prompt
category: OBSTETRICA
version: 1.0.0
status: published   # draft | published | deprecated
source_path: /laudousg/lib/categoryDefaults.ts
source_extracted_at: 2026-05-20
source_commit: a1b2c3d
validated_by: luizp02121@gmail.com
last_review: 2026-05-20
---

# OBSTETRICA — System Prompt

## FUNÇÃO
(...)

## REGRAS
(...)

## TEMPLATES
(...)
```

### 5.2 Snippet (frase padronizada)

```markdown
---
id: liquido-amniotico-normal
category: OBSTETRICA
tags: [liquido-amniotico, normal, ila]
trigger_conditions:
  - ila_between: [8, 24]
  - protocol: ILA
version: 1.0.0
status: published
source_extracted_at: 2026-05-20
---

"Líquido amniótico em quantidade normal (ILA: {valor} cm)."
```

### 5.3 Few-shot

```markdown
---
id: obstetrica-normal-com-dum-e-ila-reduzido
category: OBSTETRICA
type: few-shot
version: 1.0.0
status: published
source: /laudousg/docs/few-shots-por-categoria.md
validated_by: luizp02121@gmail.com
---

## INPUT
DUM 12/12/2025. Feto único. ILA 6. Placenta anterior corporal grau 0.

## OUTPUT
Idade gestacional pela DUM: 22 semanas...
(...)
```

### 5.4 Range (YAML)

```yaml
# packages/knowledge/ranges/OBSTETRICA.yaml
category: OBSTETRICA
version: 1.0.0
last_review: 2026-05-20

ila:
  unit: cm
  normal: { min: 8, max: 24 }
  reduced_threshold: 8
  increased_threshold: 24

mbv:
  unit: cm
  normal: { min: 2, max: 8 }

biometria_por_ig:
  '20-24sem':
    dbp: { min: 4.5, max: 6.5 }
    cf: { min: 3.0, max: 4.5 }
  # ...
```

---

## 6. Plano de extração (Fase 1, ~3-4 semanas)

### Semana 1: Setup + extração da categoria piloto

1. Criar estrutura de pastas `packages/knowledge/` no monorepo `laudousgmobile-def/`
2. Extrair OBSTETRICA pra `templates/OBSTETRICA/`:
   - Ler conteúdo da string em `categoryDefaults.ts` linha por linha
   - Identificar seções (FUNÇÃO/REGRAS/TEMPLATES) → quebrar em arquivos
   - Frontmatter com source_path + source_commit
3. Extrair few-shots OBSTETRICA pra `snippets/OBSTETRICA/few-shots/`
4. Extrair ranges OBSTETRICA pra `ranges/OBSTETRICA.yaml`
5. Documentar mapeamento em `docs/migration-log.md`

### Semana 2: Composer + validators OBSTETRICA

1. Implementar Composer (TS) que carrega knowledge e monta system prompt na ordem hierárquica
2. Migrar validators de `lib/sanityCheck/OBSTETRICA/` pra `validators/OBSTETRICA/`
3. Endpoint `POST /api/v2/generate` paralelo ao atual (feature flag por categoria)
4. Apenas OBSTETRICA usa pipeline v2 (rest continua v1)

### Semana 3: Golden cases + Testbench MVP

1. Selecionar 20 laudos OBSTETRICA reais (de `reports` em prod) + validá-los como golden cases
2. Tabela `golden_cases` no Supabase
3. CI step que roda golden cases contra v2
4. Testbench MVP no painel admin (`/laudousg/lab/`): input → run → output + source map

### Semana 4: Avaliação + decisão

1. Comparar A/B: v1 vs v2 em 50 laudos OBSTETRICA reais (Luiz avalia)
2. Critério: ≥70% v2 subjetivamente melhor que v1
3. Se pass: planejar Fase 2 (expansão + painel completo + 5-7 categorias)
4. Se fail: ajustar e iterar

---

## 7. Open questions adicionais (descobertas na sondagem)

1. **Schema.sql desatualizado** — `/laudousg/supabase/schema.sql` é referência mas defasado desde 2026-04-25. **Decisão:** usar `pg_dump --schema-only` da prod como fonte de verdade quando precisarmos.

2. **Templates customizados de usuário** (tabela `templates`) — Como integram com a nova arquitetura? **Recomendação:** o Composer carrega user templates do DB e injeta na ordem hierárquica entre `globalRules` (do usuário) e `stylePreferences`. Sem mudança no comportamento atual.

3. **Custom phrases por categoria** (`category_settings.custom_phrases` JSONB) — Como migram? **Recomendação:** o Composer carrega e injeta junto com `categoryRules` (do usuário).

4. **Subspecialty triggers** — atualmente são keywords hardcoded em `lib/subspecialty.ts`. Migrar pra YAML editável via painel?**Recomendação:** sim, vira `prompts/subspecialty/triggers/{categoria}.yaml` editável.

5. **CoT instruction** — 40 linhas de raciocínio interno em `lib/promptBuilder.ts`. Migrar pra `prompts/cot/instruction.md` como prompt versionado? **Recomendação:** sim.

6. **Quota system** — `checkLaudoAllowed` antes + `incrementLaudoUsed` depois. Manter ou repensar? **Recomendação:** manter como está. Sem ganho em refatorar agora.

7. **As 7 categorias históricas/legado** — quais exatamente e devem ser preservadas? **Pergunta pendente pro Luiz.**

8. **Multi-detect** (`app/api/generate/multi-detect/route.ts`) — detecta categoria automaticamente? Manter funcionalidade na nova arquitetura? **Pergunta pendente.**

---

## 8. Decisão

**Aprovada a estrutura `packages/knowledge/` proposta acima** com frontmatter padrão definido. Implementação começa na Semana 1 da Fase 1 do ADR-0001 (após Fase 0 de submit + Fase 0.5 de observabilidade).

A sondagem produziu mapping detalhado o suficiente pra começar extração de OBSTETRICA sem mais research. Updates ao ADR-0001 já aplicados nas correções factuais (34 categorias, RAG novo).

---

## 9. Referências

- ADR-0001 — este ADR estende e refina decisões lá tomadas
- Sondagem read-only do `/laudousg/` por Explore agent (2026-05-20)
- `/laudousg/lib/categoryDefaults.ts` (4835 linhas)
- `/laudousg/lib/promptBuilder.ts` (ordem hierárquica)
- `/laudousg/docs/few-shots-por-categoria.md`
- `/laudousg/docs/global-rules.md`
- `/laudousg/docs/current-architecture-summary.md`
