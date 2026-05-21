# ADR-0001 — Camada de Geração de Laudos: Arquitetura, Observabilidade e Iteração

| Campo | Valor |
|---|---|
| **Status** | **Accepted** |
| **Data proposto** | 2026-05-20 |
| **Data aceito** | 2026-05-20 |
| **Autores** | Luiz Prazeres (decisão), c1 (orquestrador), dex1 (revisor técnico) |
| **Decisores** | Luiz (final), c1 + dex1 (recomendação) |
| **Implementação prevista** | Fase 0.5 começa após v1.0 aprovado pela Apple |
| **Documentos relacionados** | `CLAUDE.md`, `docs/ARCHITECTURE.md`, vault Obsidian `context-map.md`, `docs/legal/` |

---

## 1. Contexto

### 1.1 Estado atual

LaudoUSG é um produto vertical médico: app iOS Swift + frontend web (laudousg.com) + backend Next.js (laudousgmobile.vercel.app), todos consumindo o mesmo endpoint principal `POST /api/generate` (SSE) pra geração de laudos de ultrassonografia com IA.

- **App iOS Swift** (este repo `laudousg-swift/`): em vias de submit pra App Store v1.0 (em 2026-05-18 a 2026-05-20)
- **Backend** (`laudousgmobile-def/apps/api/`): Vercel, vivo, usa Claude (Anthropic SDK) + Supabase. Streaming SSE com eventos `structured`, `validator`, `rag`, `token`, `sanity`, `done`, etc.
- **Web em prod** (`laudousg/`): Next.js. Pipeline real de geração de laudos vive aqui hoje, com **34 categorias conhecidas** (27 ativas + 7 históricas/legado — não 13 como descrito originalmente neste ADR). Lista detalhada em ADR-0002.
- **RAG status atual**: **NÃO existe RAG em produção pra geração de laudos**. pgvector está rodando, mas APENAS para o feed de Insights (`lib/insights/v2-runner.ts`). Geração usa few-shots **fixos** (apenas 20 exemplos validados manualmente em 10 categorias) + prompts nativos (`lib/categoryDefaults.ts` ~4835 linhas) + regras globais + sanity check síncrono.
- **Sofisticação não óbvia do pipeline atual**: Chain-of-Thought interno, subspecialty overlay (ativado por keywords), style transform em camadas (classic/direct), negative prompting, custom phrases por usuário, regras globais customizáveis por usuário, regras por categoria customizáveis por usuário.
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

### 1.5 Constraints adicionais (informados pelo Luiz na aprovação)

#### 1.5.1 `/laudousg` em produção é INVIOLÁVEL — usar apenas como fonte de consulta

O repo `/Users/luizprazeres/laudousg/` contém prompts individuais por categoria, em uso em produção (laudousg.com). Esses prompts são a **base de conhecimento de partida** pra Fase 1 (categoria piloto) e fases seguintes.

**Regra:** durante a migração, o app web `/laudousg/` deve continuar funcionando exatamente como hoje. Os prompts de lá são **consultados** (lidos) pra extrair templates e snippets pra `packages/knowledge/`, mas **nunca modificados**. Quando a nova arquitetura tomar o lugar do backend antigo pra uma categoria, o web em prod continuará apontando pro pipeline antigo até decisão explícita de migração.

**Implicação prática:**
- Fase 0.5 (observabilidade) loga laudos do backend atual sem alterar nada
- Fase 1 (piloto) cria pipeline novo em paralelo. App iOS pode escolher pipeline por header/feature flag. Web continua no antigo.
- Migração do web é tarefa **separada** e fora do escopo deste ADR — entrará em ADR-002 ou superseder.

#### 1.5.2 Transcrição mais "burra" (Apple Speech.framework on-device)

O app iOS hoje usa Whisper batch via `/api/transcribe` (escolhido no Sprint 2 porque `SFSpeechRecognizer` pt-BR falhava no Simulator iOS 26). Em iPhone físico real, `Speech.framework` (sistema nativo Apple, on-device, gratuito) é a escolha técnica preferida — zero custo de API, sem latência de upload, privacidade total.

**Trade-off:** `Speech.framework` é mais "burra" que Whisper. Sintomas esperados:
- Terminologia médica grafada errado ("eco textura" em vez de "ecotextura", "abdomê" em vez de "abdome")
- Pontuação ausente ou colocada em lugares estranhos
- Números falados ("oito milímetros") vs notação ("8mm") inconsistente
- Palavras grudadas ou separadas erroneamente
- Confusão entre termos similares ("hepatite" vs "hipertensão" em fluxo rápido)

**Implicação na arquitetura:** o pipeline novo precisa de uma **etapa de normalização ANTES do Parser** — `Pre-processor / Normalizer` que aplica regras determinísticas pra corrigir erros típicos da Speech.framework antes de mandar pra IA. Detalhes em §2.4 (fluxo atualizado) e §2.3 (decisões técnicas).

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
                │   ├─ 0. Normalizer → limpa erros típicos│
                │   │              de Apple Speech       │
                │   │              (terminologia, pont.) │
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
| **Normalizer (etapa 0)** | YAML com regras determinísticas em `packages/knowledge/normalizer/`: mapeamento de termos (`eco textura` → `ecotextura`), unidades (`oito milímetros` → `8mm`), correções de pontuação contextuais. Edição via painel admin. Aplicado ANTES do Parser. | Apple Speech.framework é "burra" comparada ao Whisper — precisa limpeza determinística pra não poluir contexto da LLM |
| **Fonte de partida** | Prompts individuais de `/laudousg/` (read-only) → extraídos manualmente pra `packages/knowledge/templates/` + `snippets/` durante Fase 1 | Reusar conhecimento já validado em produção. NÃO modificar `/laudousg/` (continua servindo web em prod). |
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

1. Médico dita: "fígado normal vesícula com calculo de oito milímetros rins ok" (notar pontuação ausente e número falado — output típico Apple Speech)
2. App envia `POST /api/generate` com input + categoria=`abdome-total` + estilo=`tradicional`
3. **Normalizer** (etapa 0, nova) limpa: "fígado normal. vesícula com cálculo de 8mm. rins ok." (correção de acento + pontuação + unidade). Loga transformações pra audit.
4. **Parser** extrai: achados=[fígado: normal, vesícula: cálculo 8mm, rins: ok]
5. **RAG retriever** (pgvector + tags markdown) busca:
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
7. **LLM** monta o laudo seguindo restrições
8. **Validator** confere: medidas dentro de ranges, terminologia conforme vocab, estrutura completa
9. **Audit log** grava: prompt_version=v1.2.0, rag_blocks=[fig-normal-v3, colelit-pequena-v1, rins-normais-v2], normalizer_diffs=[eco textura→ecotextura, oito milímetros→8mm], output, etc.
10. SSE stream emite cada chunk com `source` tag
11. App recebe, mostra laudo + permite médico clicar em qualquer parte e ver fonte
12. Se médico corrige um trecho → feedback estruturado → fila de aprovação manual

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
| **1** | Categoria piloto (Abdome Total) + extração de prompts do `/laudousg` + Normalizer inicial | 3-4 semanas | Pipeline novo só pra Abdome, golden cases (20-50), comparação A/B em produção, painel Testbench MVP, regras YAML iniciais do Normalizer, templates/snippets extraídos do `/laudousg/` (read-only) | Laudo da nova arquitetura subjetivamente melhor que baseline em ≥70% dos casos |
| **2** | Painel admin completo + expansão | 4-6 semanas | Editor + Reviewer + Feedback queue, 5-7 categorias na nova arquitetura | Luiz consegue iterar prompts/snippets sem precisar de dev |
| **3** | Cobertura total (27 categorias ativas) | 3-4 meses | Todas categorias ativas migradas, métricas em produção | Migração concluída, métricas mostram qualidade estável ou melhor que baseline |
| **4** | IA-assisted refinement (longo prazo) | Indefinido | Sistema que sugere automaticamente quais snippets melhorar baseado em feedback agregado | Não definido neste ADR |

---

## 6. Open questions (a resolver durante implementação)

0. **Como extrair prompts do `/laudousg/` em produção sem afetá-lo?** Recomendação: ler arquivos por path (`/Users/luizprazeres/laudousg/app/api/.../prompt-*.ts` ou wherever), copiar conteúdo manualmente pra `packages/knowledge/templates|snippets|prompts/{categoria}/`, anotar versão de origem no frontmatter. Nunca modificar o source. Documentar mapeamento numa migration log.

1. **Onde mora `packages/knowledge/`?** No monorepo `laudousgmobile-def/` (consumido pelo `apps/api/`) ou repo separado (`laudousg-knowledge`)? Recomendação inicial: dentro do monorepo, ao lado de `apps/api/`.

2. **Como prompts são publicados?** PR + merge to main + deploy automático? Ou ferramenta admin escreve direto no git via API GitHub? Recomendação inicial: PR pra contratos críticos, painel admin pra snippets/blocks dinâmicos (DB).

3. **Auth do painel admin.** Whitelist hardcoded de emails? Tabela `admin_users` no Supabase com role? Recomendação: tabela com role, mas começa com 1 usuário (Luiz).

4. **Como funciona o A/B test em produção (Fase 1)?** Header tipo `X-Generation-Pipeline: legacy|new`? Feature flag por user? Por categoria? Recomendação: por categoria, hardcoded inicialmente.

5. **Quem aprova sugestões da feedback queue?** Apenas Luiz no início. Quando virar problema de escala (>50 sugestões/semana?), considerar role "Editor" delegado.

6. **Como `golden_cases` lidam com aleatoriedade da LLM?** Temperatura zero? Comparação semântica via embedding em vez de string-match? Recomendação: temperatura 0.2 + comparação semântica + lista de essenciais que devem aparecer (não string-match exato).

7. **Vai existir versão "draft" de snippet/prompt antes de publicar?** Recomendação: sim, status `draft|published|deprecated`.

8. **Como o Normalizer evolui?** Recomendação: regras YAML versionadas no git em `packages/knowledge/normalizer/`. Editáveis via painel admin (Fase 2). Tipos de regras iniciais: (a) substituição literal (`eco textura` → `ecotextura`), (b) regex de unidades (`(\d+)\s*milímetros?` → `\1mm`), (c) pontuação contextual (após termos médicos comuns). Cada geração loga `normalizer_diffs` no audit pra debug.

9. **Como Apple Speech vs Whisper batch coexistem?** Apple Speech.framework é preferido (zero custo, on-device, privacidade). Mas em Simulator iOS 26 ele quebra (`Failed to initialize recognizer`). Recomendação: Speech.framework em iPhone físico (release builds), Whisper batch como fallback no Simulator (debug builds). Documentar em `docs/ARCHITECTURE.md` quando implementar.

10. **Priority logic dos RAG blocks: universal vs contextual.** Descoberta empírica do Sprint P1 testes (2026-05-20/21): blocos `regra` precisam de 2 níveis de priority pra retriever escolher bem dentro da quota:
    - **Universais (priority 90-100):** regras que TODO laudo da categoria precisa. Em OBSTETRICA hoje (commit `ca20f9a`): selecao-automatica-modelo=100, ordem-secoes=99, preservar-terminologia=94, frases-normais-quando-omitido=93, dias-da-ig=92 (5 universais kind=regra)
    - **Contextuais (priority ~70):** regras que só aplicam em casos específicos. Em OBSTETRICA: calculo-dsm, modelo-inicial, gestacao-gemelar, peso-fetal-percentil, placenta-morfologicos (5 contextuais kind=regra)
    - **Quotas atuais do retriever** (commit `afe4d91`, 2026-05-21): modelo=**2** (era 1), regra=**10** (era 8), frase=8, conclusao=**3** (era 2), excecao=3, comentario_tecnico=3, exemplo=2. Total máx por geração = 31 blocks (era ~19).
    - **Cobertura com quota=8 pra regra OBSTETRICA:** TODAS as 5 universais sempre entram + top 3 das 5 contextuais por similarity. Permite caso RCIU (peso-fetal-percentil entra) + caso gemelar (gestacao-gemelar entra) + caso DSM (calculo-dsm entra) sem competição interna.
    - **Reforço extra (header GATILHOS DE APLICAÇÃO):** em blocos contextuais críticos, adicionar header inicial com keywords explícitas. Aumenta similarity quando input do médico tem essas keywords.
    - **⚠️ Descoberta empírica (commit `afe4d91`, validada E2E em 4 laudos PELVE):** o header `GATILHOS DE APLICAÇÃO` no BODY do bloco **não move o embedding o suficiente** pra superar regras concorrentes com vocabulário genérico (ex: pólipo-endometrial, endometrioma, calcificação). Mesmo com texto explicativo "Aplica quando o input mencionar X", o ranking de similarity mantém perdedoras.
    - **Padrão consolidado (3 níveis de priority pra regra):**
      - Universal (90-100): sempre entra
      - **Contextual com vocabulário difícil (75)** + header GATILHOS: entra MAS o LLM (gpt-4.1-mini) lê o header e filtra aplicação no output final. **Validado: ZERO falsos positivos em PELVE com regra-miomas e regra-SOP sempre entrando, LLM respeita header.**
      - Contextual com vocabulário forte (70): só entra quando similarity match
    **Aplicar:** mesma lógica nas próximas categorias (P3+). Marcar no frontmatter `priority_tier: universal|contextual` + considerar bump pra 75 quando vocabulário do bloco é genérico e ele está perdendo slots pra blocos mais "específicos linguisticamente".

11. **Trilha forense de RAG (pra Painel Dissecador da Fase 3).** Hoje `generation_audit.rag_blocks_retrieved` jsonb guarda quais blocos foram puxados. Pro dissecador funcionar (clica no laudo → entende o porquê), precisamos saber também:
    - **`rag_blocks_skipped`** jsonb (NEW) — blocos que match na similarity mas foram cortados por quota. Permite UI "quase entrou, mas saiu por quota". Crítico pra debugar regras mal calibradas (caso RCIU descoberto no Sprint P1).
    - **`similarity_scores`** dentro de `rag_blocks_retrieved` (enhance) — score cosine de cada bloco puxado. Permite ranqueamento visual + debug "esse bloco entrou só por priority, não pela semântica".
    - **Implementação:** adicionar campos no schema Drizzle `generationAudit.ts` + popular no retriever step. Coordenar com Fase 3 quando começar.

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
