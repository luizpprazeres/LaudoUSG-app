# ADR-0001 — Camada de Geração de Laudos: Arquitetura, Observabilidade e Iteração

| Campo | Valor |
|---|---|
| **Status** | Proposed |
| **Data** | 2026-05-20 |
| **Autores** | Luiz Prazeres (decisão), c1 (orquestrador), dex1 (revisor técnico) |
| **Decisores** | Luiz (final), c1 + dex1 (recomendação) |
| **Implementação prevista** | Fase 0.5 começa após v1.0 aprovado pela Apple |
| **Documentos relacionados** | `CLAUDE.md`, `docs/ARCHITECTURE.md`, vault Obsidian `context-map.md`, `docs/legal/` |

---

## 1. Contexto

### 1.1 Estado atual

LaudoUSG é um produto vertical médico: app iOS Swift + frontend web (laudousg.com) + backend Next.js (laudousgmobile.vercel.app), todos consumindo o mesmo endpoint principal `POST /api/generate` (SSE) pra geração de laudos de ultrassonografia com IA.

- **App iOS Swift** (este repo `laudousg-swift/`): em vias de submit pra App Store v1.0 (em 2026-05-18 a 2026-05-20)
- **Backend** (`laudousgmobile-def/apps/api/`): Vercel, vivo, usa Claude (Anthropic SDK) + Supabase + RAG via pgvector. 13 categorias de laudos suportadas. Streaming SSE com eventos `structured`, `validator`, `rag`, `token`, `sanity`, `done`, etc.
- **Web em prod** (`laudousg/`): Next.js, fluxo similar ao iOS, mais maduro como UX médica
- **Sanity check**: client-side, 100% determinístico, zero IA — decisão trancada (ver `CLAUDE.md` e `docs/ARCHITECTURE.md §9`)

A arquitetura geral está correta: lógica de geração 100% no backend, app consome via SSE → mudanças no prompt/RAG são aplicadas em minutos, sem Apple Review.

### 1.2 Problema

Apesar da arquitetura correta, a **qualidade dos laudos gerados ainda não é boa o suficiente** segundo critério do produto (avaliação subjetiva do Luiz como médico ultrassonografista). Sintomas observados:

1. **Alucinações de medidas**: LLM "inventa" valores plausíveis quando médico não informa
2. **Terminologia inconsistente**: mesmo achado descrito de formas diferentes entre laudos
3. **Estrutura do laudo varia**: LLM "esquece" seções entre chamadas
4. **Difícil auditar**: não dá pra saber se uma frase específica veio do prompt-system, do RAG, ou da inferência do modelo
5. **Iteração lenta sobre qualidade**: melhorar um prompt requer testes manuais sem regressão automática — não tem como saber se mudar Abdome quebra Mama
6. **Feedback médico é informal**: hoje é "eu corrijo o laudo no app" — não vira aprendizado sistemático pro produto

### 1.3 Drivers da decisão (do Luiz)

Proposta original do Luiz (2026-05-20):

> "Pensei em criarmos do zero, construindo cada categoria e testando, com RAG, tudo de fácil visualização na web, com objetivo de evitar sempre gerar os laudos de forma aleatória como a IA quer e sempre fornecer as informações ao máximo mastigadas para a IA gerar."

Drivers explícitos:
- **Mastigar info pra IA** — em vez de IA inventar, alimentar com dados estruturados (templates, ranges normais, vocabulário, frases padronizadas) e ela só monta
- **Atualização sem Apple Review** — manter lógica 100% backend (já é o caso, mas reforçar)
- **Visualização web fácil** — interface admin pra entender e iterar
- **Source mapping** — entender de onde veio cada peça do laudo (RAG vs prompt vs template vs LLM)
- **Pontuar melhorias diretamente** — interface pra feedback estruturado que vira melhoria sistêmica, não correção manual diária

### 1.4 Não-objetivos (escopo NÃO coberto por este ADR)

- Substituir o produto web `laudousg/` em produção (continua servindo médicos atuais)
- Mudar o sanity check client-side (decisão trancada — sync, zero IA)
- Trocar provider de LLM (continuamos com Claude/Anthropic SDK por enquanto)
- Multi-tenant ou organizações de clínicas (escopo futuro)
- Treinar modelo próprio (não justifica investimento neste momento)

---

## 2. Decisão

### 2.1 Princípios norteadores

| # | Princípio | Razão |
|---|---|---|
| P1 | **NÃO refazer do zero. Ship of Theseus: troca peça por peça.** | Refatoração total em produtos médicos é anti-padrão. 6+ meses sem entrega real. |
| P2 | **Observabilidade ANTES de mudar arquitetura.** | Sem dados reais, vai-se construir solução pra problema imaginado. |
| P3 | **Categoria piloto primeiro.** Prova de valor em 1 categoria antes de escalar. | Investimento mínimo pra validar a tese. |
| P4 | **Golden cases versionadas.** Suite de regressão de qualidade. | Evita melhoria em A quebrar B. |
| P5 | **Feedback loop = sugestão pra fila, merge MANUAL.** | Auto-merge de feedback médico é arriscado clinicamente. |
| P6 | **Templates em markdown + JSON Schema. Sem DSL própria.** | DSL custom é elegante mas cria linguagem interna cara de manter. |
| P7 | **Versionamento duplo: git pra contratos, DB pra knowledge dinâmico.** | Cada um tem seu trade-off (review vs velocidade). |
| P8 | **Painel admin em subpath, não subdomínio (a princípio).** | Reuso de infra de auth. Subdomínio quando virar produto admin real. |

### 2.2 Arquitetura proposta (high-level)

```
App iOS (Swift)                          Web Pública (laudousg.com)
        \                                       /
         \                                     /
          POST /api/generate (SSE)            /
                          \                  /
                           \                /
                ┌───────────▼──────────────▼────────────┐
                │  Backend Next.js (apps/api/)           │
                │                                         │
                │  /api/generate (refatorado)             │
                │   ├─ 1. Parser → extrai dados          │
                │   │              estruturados do input │
                │   ├─ 2. RAG Retriever → busca templates│
                │   │              + snippets relevantes │
                │   ├─ 3. Composer → monta contexto     │
                │   │              "mastigado"           │
                │   ├─ 4. LLM (papel restrito) →        │
                │   │              "use SÓ o que te dei" │
                │   ├─ 5. Validator → ranges físicos +  │
                │   │              regras determinísticas│
                │   ├─ 6. Audit Log → registra prompt_  │
                │   │              version + RAG blocks  │
                │   └─ Emite SSE com source tag em      │
                │                   cada chunk           │
                │                                         │
                │  /api/feedback (NEW)                    │
                │   └─ Recebe correções → fila          │
                │                                         │
                │  /api/admin/* (NEW, protegido)         │
                │   ├─ Testbench (run input → output)   │
                │   ├─ CRUD prompts/templates/snippets   │
                │   └─ Aprovação manual de sugestões    │
                └─────────────┬──────────────────────────┘
                              │
                ┌─────────────▼──────────────────────────┐
                │  Camada de Conhecimento (NEW)           │
                │                                         │
                │  packages/knowledge/                    │
                │   ├─ templates/{categoria}/             │
                │   │   ├─ structure.md (estrutura base) │
                │   │   ├─ sections.yaml (seções fixas) │
                │   │   └─ vocab.yaml (termos corretos) │
                │   ├─ snippets/{categoria}/{tag}.md     │
                │   │   (frases padronizadas com         │
                │   │    frontmatter: tags, severity,    │
                │   │    version)                        │
                │   ├─ ranges/{categoria}.yaml            │
                │   │   (medidas normais e patológicas)  │
                │   └─ prompts/{categoria}/              │
                │       └─ system.md (system prompt      │
                │                    versionado)         │
                │                                         │
                │  Supabase (knowledge dinâmico):         │
                │   ├─ rag_blocks (pgvector já existe)   │
                │   ├─ generation_audit (NEW)             │
                │   ├─ learning_suggestions (NEW)         │
                │   └─ golden_cases (NEW)                 │
                └─────────────┬──────────────────────────┘
                              │
                ┌─────────────▼──────────────────────────┐
                │  Painel Admin Web (NEW)                 │
                │  Path: /laudousg/lab/ (subpath)         │
                │  Auth: email whitelist (Luiz por agora) │
                │                                         │
                │   ├─ Testbench: input → run → output   │
                │   │   com source map visual            │
                │   ├─ Editor: markdown editor com diff  │
                │   │   (Codemirror ou Monaco)           │
                │   ├─ Reviewer: clica num pedaço do     │
                │   │   laudo gerado → vê fonte exata    │
                │   ├─ Feedback queue: lista de sugestões│
                │   │   pendentes, aprovação manual      │
                │   └─ Golden cases: editor + runner     │
                └─────────────────────────────────────────┘
```

### 2.3 Decisões técnicas concretas

| Componente | Decisão | Justificativa |
|---|---|---|
| **Templates** | Markdown com frontmatter YAML | Versionável no git, diffável, sem deps |
| **Snippets (RAG curado)** | Markdown + frontmatter YAML em `packages/knowledge/snippets/` | Git como source of truth pra blocos críticos |
| **RAG embedding** | Manter Supabase pgvector (já em produção) | Sem investimento adicional. Já integrado. |
| **Lookup híbrido** | Tags markdown (git) + similaridade vetorial (pgvector) | Markdown vence em determinismo; vetor pega cauda longa |
| **System prompts** | Markdown versionado no git, com semver (`v1.2.0`) | Cada geração grava `prompt_version` no `generation_audit` |
| **Contratos de I/O** | JSON Schema (em `packages/knowledge/schemas/`) | Validação de input/output sem DSL própria |
| **Painel admin** | Subpath `/laudousg/lab/` protegido por auth + whitelist email | Reusa infra do Next.js do laudousg.com |
| **Editor markdown** | Codemirror 6 ou Monaco | Engines maduros, mesmo do VSCode |
| **Source mapping** | Backend emite SSE com campo `source` em cada chunk (`template:abdome-fig.md`, `rag:figado-normal-v3`, `llm`) | Sem mágica, fácil de auditar |
| **Audit log** | Tabela `generation_audit` no Supabase: `id`, `created_at`, `user_id`, `category`, `prompt_version`, `contract_hash`, `rag_block_ids[]`, `input_raw`, `output_raw`, `medical_feedback` (nullable) | Rastreabilidade total. ~30 min de dev. |
| **Golden cases** | Tabela `golden_cases`: `id`, `category`, `input_fixture`, `expected_output_essentials`, `prompt_version_at_creation`, `validator_must_pass` | 20-50 fixtures iniciais validadas pelo Luiz |
| **Feedback loop** | Tabela `learning_suggestions`: `id`, `category`, `report_id`, `selected_excerpt`, `error_type` (enum), `severity`, `suggested_correction`, `status` (pending/approved/rejected/applied) | Sugestão estruturada, merge manual no painel |
| **Regressão de qualidade** | CI step que roda mudanças contra `golden_cases`, diff dos outputs, falha o build se essenciais quebrarem | Pré-merge em PR ou pré-deploy |
| **Versionamento dual** | Git pra contratos/templates globais + DB pra knowledge blocks dinâmicos | Cada um com seu trade-off |

### 2.4 Fluxo end-to-end (exemplo Abdome Total)

1. Médico dita: "fígado normal, vesícula com cálculo de 8mm, rins ok"
2. App envia `POST /api/generate` com input + categoria=`abdome-total` + estilo=`tradicional`
3. **Parser** extrai: achados=[fígado: normal, vesícula: cálculo 8mm, rins: ok]
4. **RAG retriever** (pgvector + tags markdown) busca:
   - Template estrutural: `templates/abdome-total/structure.md` (seções: técnica, achados, conclusão)
   - Snippets relevantes: `snippets/abdome-total/figado-normal.md`, `snippets/abdome-total/colelitiase-pequena.md`, `snippets/abdome-total/rins-normais.md`
   - Ranges: `ranges/abdome-total.yaml` (calculo biliar: <5mm=microlitíase, 5-10mm=pequeno, etc.)
5. **Composer** monta contexto:
   ```
   Use APENAS as frases abaixo. NÃO invente medidas. Se faltar info, escreva [INFORMAÇÃO NÃO FORNECIDA].
   
   ESTRUTURA: [template abdome-total]
   FRASES PADRÃO:
     - Fígado normal: "Fígado de dimensões e ecotextura normais..."
     - Colelitíase pequena (5-10mm): "Vesícula biliar com paredes finas..."
     - ...
   ```
6. **LLM** monta o laudo seguindo restrições
7. **Validator** confere: medidas dentro de ranges, terminologia conforme vocab, estrutura completa
8. **Audit log** grava: prompt_version=v1.2.0, rag_blocks=[fig-normal-v3, colelit-pequena-v1, rins-normais-v2], output, etc.
9. SSE stream emite cada chunk com `source` tag
10. App recebe, mostra laudo + permite médico clicar em qualquer parte e ver fonte
11. Se médico corrige um trecho → feedback estruturado → fila de aprovação manual

---

## 3. Consequências

### 3.1 Positivas

- ✅ **Qualidade subjetiva dos laudos melhora** (hipótese a validar com golden cases + observabilidade)
- ✅ **Iteração em minutos** (mudança de snippet → deploy → médicos veem na próxima geração)
- ✅ **Rastreabilidade total** (cada laudo gerado tem audit trail de quais prompts/blocks usou)
- ✅ **Feedback médico vira melhoria sistêmica** (não corrige mais "o laudo da Maria", corrige "todos os laudos de Abdome com cálculo pequeno")
- ✅ **Regressão de qualidade detectada antes do deploy** (golden cases falham CI)
- ✅ **Médico ganha confiança** (consegue ver de onde vem cada peça do laudo)
- ✅ **Onboarding de nova categoria mais simples** (estrutura conhecida, só preencher templates+snippets+ranges)

### 3.2 Negativas

- ⚠️ **Investimento significativo** (3-4 sprints pra prova de valor + 2-3 meses pra expansão)
- ⚠️ **Sobre-engineering possível** (painel admin pode virar projeto à parte)
- ⚠️ **Migração incremental tem janela de duplicidade** (categoria nova + categoria antiga coexistem)
- ⚠️ **Fricção do feedback loop com merge manual** (Luiz tem que aprovar sugestões — não é fire-and-forget)
- ⚠️ **Risco de templates engessarem geração** (LLM pode ficar "robotizada" se contexto for muito restritivo)

### 3.3 Riscos mitigados

| Risco | Mitigação |
|---|---|
| Refatoração mata produto vivo | Pipeline novo coexiste com antigo. Switch por categoria. Rollback trivial. |
| Investimento sem retorno | Fase 1 é piloto pequeno (1 categoria). Critério de saída: laudo materialmente melhor. Senão, ajusta. |
| Painel vira yak-shaving | MVP do painel = só Testbench. Editor e Reviewer vêm depois. |
| Feedback ruim vira regra ruim | Merge manual + tipos estruturados + Luiz revisa cada sugestão |
| Golden cases obsoletas | Versionadas por `prompt_version`. Quando schema muda, regrava com revisão. |

---

## 4. Alternativas consideradas

### 4.1 Alternativa A: "Refazer do zero" (proposta original do Luiz)

**Rejeitada.** Joel Spolsky (2000) e décadas de evidência de produtos reais mostram que rewrites quase nunca entregam. 6+ meses sem produto, time perde context, features acumulam débito, e o "novo" termina pior que o antigo. Em produto médico vivo, ainda pior: usuários reais dependem.

**O que mantemos do impulso original do Luiz**: mastigar info pra IA, painel web, source mapping, feedback loop. Tudo isso é evolutivo, não revolução.

### 4.2 Alternativa B: "Refinar prompts em produção, sem nova camada"

**Rejeitada.** É o que estamos fazendo hoje. Sem observabilidade, sem golden cases, sem source mapping. Continua na incerteza atual. Não atende os drivers do Luiz.

### 4.3 Alternativa C: "Fine-tuning de modelo próprio"

**Rejeitada (por enquanto).** Custo de dataset (precisaria 1000+ laudos validados), custo de treino, manutenção de model serving infra. Não justifica até termos volume e qualidade base estável. Reavaliar em 12+ meses.

### 4.4 Alternativa D: "RAG agressivo + prompt simples"

**Considerada, parcialmente adotada.** É essencialmente a tese do Luiz. A diferença com a Decisão final é que adicionamos: (1) observabilidade primeiro, (2) golden cases pra regressão, (3) source mapping, (4) feedback estruturado. Sem isso, RAG agressivo só vira "mais um prompt complexo" sem governance.

### 4.5 Alternativa E: "DSL própria pra templates"

**Rejeitada.** Templates em DSL custom vira manutenção eterna, curva de aprendizado pra contribuidores futuros, e geralmente reinventam markdown+frontmatter mal. Markdown + YAML é universal.

---

## 5. Roadmap por fase

| Fase | Objetivo | Duração estimada | Entregáveis | Critério de saída |
|---|---|---|---|---|
| **0** | Submit v1.0 + médicos usando em prod | Em curso (até ~2026-05-23) | App aprovado pela Apple, primeiros médicos usando | Versão 1.0 aprovada, ≥10 médicos cadastrados |
| **0.5** | Observabilidade real | 1 semana | Tabela `generation_audit`, dashboard simples, coleta de ≥30 falhas reais analisadas | 30-50 falhas catalogadas por categoria de erro |
| **1** | Categoria piloto (Abdome Total) | 3-4 semanas | Pipeline novo só pra Abdome, golden cases (20-50), comparação A/B em produção, painel Testbench MVP | Laudo da nova arquitetura subjetivamente melhor que baseline em ≥70% dos casos |
| **2** | Painel admin completo + expansão | 4-6 semanas | Editor + Reviewer + Feedback queue, 5-7 categorias na nova arquitetura | Luiz consegue iterar prompts/snippets sem precisar de dev |
| **3** | Cobertura total (13 categorias) | 2-3 meses | Todas categorias migradas, métricas em produção | Migração concluída, métricas mostram qualidade estável ou melhor que baseline |
| **4** | IA-assisted refinement (longo prazo) | Indefinido | Sistema que sugere automaticamente quais snippets melhorar baseado em feedback agregado | Não definido neste ADR |

---

## 6. Open questions (a resolver durante implementação)

1. **Onde mora `packages/knowledge/`?** No monorepo `laudousgmobile-def/` (consumido pelo `apps/api/`) ou repo separado (`laudousg-knowledge`)? Recomendação inicial: dentro do monorepo, ao lado de `apps/api/`.

2. **Como prompts são publicados?** PR + merge to main + deploy automático? Ou ferramenta admin escreve direto no git via API GitHub? Recomendação inicial: PR pra contratos críticos, painel admin pra snippets/blocks dinâmicos (DB).

3. **Auth do painel admin.** Whitelist hardcoded de emails? Tabela `admin_users` no Supabase com role? Recomendação: tabela com role, mas começa com 1 usuário (Luiz).

4. **Como funciona o A/B test em produção (Fase 1)?** Header tipo `X-Generation-Pipeline: legacy|new`? Feature flag por user? Por categoria? Recomendação: por categoria, hardcoded inicialmente.

5. **Quem aprova sugestões da feedback queue?** Apenas Luiz no início. Quando virar problema de escala (>50 sugestões/semana?), considerar role "Editor" delegado.

6. **Como `golden_cases` lidam com aleatoriedade da LLM?** Temperatura zero? Comparação semântica via embedding em vez de string-match? Recomendação: temperatura 0.2 + comparação semântica + lista de essenciais que devem aparecer (não string-match exato).

7. **Vai existir versão "draft" de snippet/prompt antes de publicar?** Recomendação: sim, status `draft|published|deprecated`.

---

## 7. Plano de revisão deste ADR

- **Decisão final pelo Luiz:** após submit v1.0 estar concluído + Apple Review submetida
- **Revisão em 30 dias após início da Fase 0.5:** dados reais coletados podem mudar premissas
- **Revisão por fase concluída:** lições aprendidas atualizam roadmap
- **Eventual ADR-002 ou superseder:** se Alternativa A (rewrite) virar inevitável após Fase 1 frustrante (improvável)

---

## 8. Referências

- Joel Spolsky, "Things You Should Never Do, Part I" (2000) — argumento contra rewrites
- Anthropic, "Building Effective Agents" (2025) — patterns pra LLM systems
- `CLAUDE.md` (este repo) — decisões trancadas do produto
- `docs/ARCHITECTURE.md` (este repo) — arquitetura atual do app iOS
- `docs/legal/` — Termos, Privacidade, Disclaimer Médico (não afetados por este ADR)
- Vault Obsidian `/Users/luizprazeres/laugousg-vault/LaudoUSG/docs-projeto/context-map.md` — contexto canônico do produto

---

## 9. Notas de discussão

### 9.1 Convergências c1 + dex1 (~90% alinhados)

Ambos os terminais convergem em:
- NÃO refazer do zero (Ship of Theseus incremental)
- Observabilidade ANTES de mudar arquitetura
- Categoria piloto primeiro
- Golden cases versionadas
- Feedback loop com merge manual
- Painel admin em subpath
- Markdown + JSON Schema (sem DSL custom)

### 9.2 Pequenas divergências resolvidas

| Ponto | c1 | dex1 | Resolução |
|---|---|---|---|
| RAG MVP | Markdown files em filesystem | Manter pgvector já em uso | Adotamos pgvector + markdown como source of truth dual |
| Feedback UX | Botão "isso é ruim" no laudo | Evento estruturado | Adotamos estruturado; UX no app pode ser simples por cima |
