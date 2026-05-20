# Sprint P2 — DeterministicSanity por categoria

> **Brief preparado por:** c1 (orquestrador)
> **Destinatário:** dex1 (Codex GPT-5.5 high)
> **Status:** rascunhado em 2026-05-20, aguardando P1 (`bjaei7s6j`) terminar antes de disparar
> **Pré-requisito:** P1 (RAG OBSTETRICA) entregue, populado e validado
> **Duração estimada:** 1-2 dias de dex1

---

## Por que esse sprint existe (descoberta crítica)

Mapeei a arquitetura real do `laudousgmobile-def/apps/api/`:

- **`validator.ts`** (pré-LLM) — Stub de 50 linhas. Valida input estruturado vindo do `structurer`. **NÃO é o foco deste sprint.**
- **`deterministicSanity.ts`** (pós-LLM, 407 linhas) — Roda APÓS o writer gerar o laudo. Hoje é **genérico**: extrai medidas, datas, checa RADS, placeholders. Não tem regras por categoria.
- **`/laudousg/lib/sanityCheck/rules/*.ts`** (35 arquivos) — Regras **por categoria**. Validam o LAUDO GERADO (texto final). Cobertura: 34 categorias.

**Conclusão:** as 35 regras do `/laudousg/` se encaixam naturalmente em **deterministicSanity** (pós-LLM), não em validator (pré-LLM). P2 = portar essas regras pra deterministicSanity, mantendo a arquitetura mobile.

---

## Decisão de escopo

**Hoje o sanity check do backend mobile não pega coisas como:**
- "IG=20 semanas mas peso fetal estimado em 4kg" (impossível)
- "BI-RADS 6 mas conclusão diz 'achados benignos'" (contradição)
- "ILA reduzido mas valor numérico 12cm" (12cm é normal)
- "Tireoide com TI-RADS 4 mas sem descrever nódulo"

São esses tipos de regras que `/laudousg/lib/sanityCheck/rules/*.ts` cobrem por categoria. Portar pra mobile = ganho **+20-30% em catch de erros** (estimativa do Explore agent).

**Escopo P2 (1-2 dias):**

- **Fase A (cirúrgica)** — Portar apenas as 6 categorias que JÁ têm contracts no mobile:
  - OBSTETRICA, DOPPLER_OBSTETRICO, TIREOIDE, MAMARIA, ABDOMEN_TOTAL, PELVE_FEMININA
  - Adicionar enum/dispatch por categoria em `deterministicSanity.ts`
  - Validar cada uma contra golden cases (manual no início, automated depois)

- **Fase B (futura — Sprint P5 ou similar)** — Portar as outras 29 categorias quando seus contracts estiverem prontos (depende de P3).

---

## Brief para dex1 (a ser disparado quando P1 voltar)

### Contexto curto

Backend mobile `laudousgmobile-def/apps/api/` tem `deterministicSanity.ts` (pós-LLM, 407 linhas, genérico). `/Users/luizprazeres/laudousg/lib/sanityCheck/rules/*.ts` (35 arquivos) tem regras por categoria validando laudo gerado. Vamos portar 6 categorias prioritárias do `/laudousg/` pra `deterministicSanity.ts` mantendo arquitetura mobile.

### Arquivos existentes (paths absolutos)

**Fontes read-only (NÃO modificar):**
- `/Users/luizprazeres/laudousg/lib/sanityCheck/index.ts` — entrypoint canônico (entender dispatch por categoria)
- `/Users/luizprazeres/laudousg/lib/sanityCheck/extractor.ts` — extrai valores numéricos do texto (ig_weeks, ila_cm, birads, etc.)
- `/Users/luizprazeres/laudousg/lib/sanityCheck/types.ts` — `SanityFlag`, `ExtractedValues`
- `/Users/luizprazeres/laudousg/lib/sanityCheck/rules/obstetrica.ts`
- `/Users/luizprazeres/laudousg/lib/sanityCheck/rules/dopplerObstetrico.ts`
- `/Users/luizprazeres/laudousg/lib/sanityCheck/rules/tireoide.ts`
- `/Users/luizprazeres/laudousg/lib/sanityCheck/rules/mamaria.ts`
- `/Users/luizprazeres/laudousg/lib/sanityCheck/rules/abdomenTotal.ts`
- `/Users/luizprazeres/laudousg/lib/sanityCheck/rules/pelveFeminina.ts`

**Destino (modificar/expandir):**
- `/Users/luizprazeres/laudousgmobile-def/apps/api/src/server/pipeline/deterministicSanity.ts` (407 linhas atuais)
- `/Users/luizprazeres/laudousgmobile-def/apps/api/src/server/pipeline/__tests__/deterministicSanity.manual.ts` (validar)

### Tarefas numeradas

#### T1 — Entender shape atual de deterministicSanity.ts
Ler todo o arquivo. Identificar:
- `DeterministicSanityResult` (tipo retornado)
- `DeterministicIssue` (formato dos issues)
- Funções existentes: `checkMeasurements`, `checkLaterality`, `checkDates`, `checkCommands`, `checkRadsClassifications`, `checkPlaceholders`
- Como `runDeterministicSanity()` chama essas funções

#### T2 — Entender shape dos rules em /laudousg/sanityCheck
Ler `rules/obstetrica.ts` por completo + `extractor.ts` + `types.ts`. Identificar:
- Assinatura de `checkObstetrica(text, extracted)` (provavelmente assim)
- `ExtractedValues` (campos numéricos disponíveis)
- `SanityFlag` (saída: severity='warning', code, message, suggestion?)

#### T3 — Adaptar shape pra mobile
`DeterministicIssue` e `SanityFlag` provavelmente têm campos diferentes. Criar adapter:
- `sanityFlagToDeterministicIssue(flag: SanityFlag): DeterministicIssue` — converte formato
- Manter compatibilidade com `DeterministicSanityResult` existente

#### T4 — Portar `extractor.ts` pra mobile
O extrator de `/laudousg/` é a base de tudo. Portar pra `deterministicSanity.ts` como função interna (ou arquivo separado `extractor.ts` ao lado). Manter TODOS os campos de `ExtractedValues` (mesmo os de categorias futuras — não recortar).

#### T5 — Portar 6 regras por categoria
Pra cada uma das 6 (OBSTETRICA, DOPPLER_OBSTETRICO, TIREOIDE, MAMARIA, ABDOMEN_TOTAL, PELVE_FEMININA):
- Copiar lógica de `rules/{categoria}.ts` verbatim (mesma assinatura, mesmo nome de função se possível)
- Adicionar a `deterministicSanity.ts` ou em arquivos separados `rules/{categoria}.ts` ao lado (decisão tua, mantendo idiomático com codebase atual)
- Cada função retorna `DeterministicIssue[]` (ou `SanityFlag[]` adaptado)

#### T6 — Atualizar `runDeterministicSanity()` pra rotear
```typescript
// Antes:
runDeterministicSanity({ text, ... })
  → checkMeasurements + checkRads + checkPlaceholders + ...

// Depois:
runDeterministicSanity({ text, category, ... })
  → genericos (acima) + categorySpecific[category](text, extracted)
```

Dispatch por `category` (StructuredFindings.categoria_detectada). Se categoria não suportada (não está nas 6), só roda genéricos.

#### T7 — Testes em `deterministicSanity.manual.ts`
Adicionar casos de teste pras 6 categorias. Cada caso:
- Input: texto de um laudo conhecido (pode usar exemplos das few-shots do /laudousg/docs/few-shots-por-categoria.md)
- Expected: lista de issues esperadas
- Asserts diretos no manual test (não framework de teste agora — manter consistência com o que já existe)

#### T8 — Validar typecheck
`cd /Users/luizprazeres/laudousgmobile-def && pnpm --filter @laudousg/api typecheck` (ou nome equivalente). Se erro, corrigir. Resultado final: 0 erros.

### Padrões
- Verbatim de `/laudousg/` — NÃO refatorar, melhorar ou parafrasear lógica
- Adapter pattern entre `SanityFlag` (source) e `DeterministicIssue` (destino) — não muda formato existente do mobile
- NÃO modificar nada em `/laudousg/`
- NÃO commitar (orquestrador faz)
- NÃO adicionar deps novas sem confirmar
- TypeScript estrito

### Quando terminar
Reportar em PT-BR (~400-600 palavras):
1. Quantas regras portadas por categoria (deve ser 6 funções principais + helpers)
2. Paths dos arquivos novos/modificados
3. Trecho do adapter `sanityFlagToDeterministicIssue` (~10 linhas)
4. Trecho do dispatch novo em `runDeterministicSanity` (~10 linhas)
5. Output do typecheck
6. Casos de teste adicionados (lista breve)
7. Surpresas/decisões tomadas durante porting
8. Próximas categorias prioritárias pra Sprint futuro (das 29 restantes)

---

## Quando disparar este brief

Após P1 (`bjaei7s6j`) terminar e eu validar:
1. ✅ OBSTETRICA tem ~15-30 markdown files em `packages/knowledge/snippets/OBSTETRICA/`
2. ✅ Script `ingest-knowledge.ts` criado
3. ✅ `pnpm typecheck` PASS no P1

Aí disparo P2 com este brief.

---

## Riscos e mitigações

| Risco | Mitigação |
|---|---|
| dex1 inventa lógica em vez de copiar verbatim | Brief enfatiza "verbatim" + revisão manual antes de merge |
| Conflito entre adapter `SanityFlag` ↔ `DeterministicIssue` | T3 separado pra isolar a tradução de tipo |
| `extractor.ts` ter dependências de outros arquivos do `/laudousg/` | Investigar imports antes — se houver, replicar localmente |
| Casos de teste sem golden source | Usar few-shots do `/laudousg/docs/few-shots-por-categoria.md` como golden inputs |

---

## Atualização do roadmap

Após P2 concluído:
- **+20-30% catch de erros estruturais** (estimativa)
- Próximo: **P3 — 21 contracts restantes** (3-5 dias)
- Em paralelo (quando alguém disponível): **P4 — Painel admin Testbench** (Fase 2 do ADR-0001)

---

**Fim do brief.** Quando for a hora, releio + disparo.
