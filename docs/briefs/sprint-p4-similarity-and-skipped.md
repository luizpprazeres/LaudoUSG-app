# Sprint P4 — similarity_score + rag_blocks_skipped (pré-req do Painel Dissecador)

> **Brief preparado por:** c1 (orquestrador)
> **Destinatário:** dex1 (Codex GPT-5.5 high) ou Claude Code (Supabase MCP) — pequeno o suficiente pra qualquer um
> **Status:** rascunhado em 2026-05-21, pronto pra disparar depois ou em paralelo com P3
> **Pré-requisitos:** P1 ✅ + entendimento do retriever/audit atual ✅
> **Duração estimada:** 1-2h
> **Ref:** ADR-0001 §6.11

---

## 1. Contexto

### ⚠️ ALERTA CRÍTICO — NÃO é cache semântico

**Em produto anterior**, tentou-se cache semântico que buscava laudos anteriores pra gerar novos (economizar tokens). **Foi encerrado** porque acabava repetindo info específica de laudos antigos em detrimento dos atuais — quebrava a fidelidade ao input do médico.

**Este P4 NÃO é cache semântico.** É APENAS observabilidade forense:

| ❌ NÃO é | ✅ É |
|---|---|
| Buscar laudos anteriores pra reusar texto | Persistir score de cada bloco RAG já puxado no audit |
| Injetar conteúdo de outros laudos no atual | Apenas metadata pra debugar "por que esse bloco entrou" |
| Mudar lógica de retrieval | Zero impacto no pipeline atual — só audit log |
| Otimização de tokens | Otimização de DEBUG (futuro Dissecador) |

A similarity é calculada **APENAS entre o input atual e cada bloco do RAG curado** (templates, regras, frases já validados em `packages/knowledge/`). NÃO existe interação com laudos passados de outros médicos/pacientes. Cada laudo gerado é independente.

### Objetivo real

ADR-0001 §6.11 propõe 2 enhancements no audit pra destravar o **Painel Dissecador (Fase 3)**:

1. **similarity_score** dentro de `rag_blocks_retrieved` — cosine de cada bloco puxado. Permite ranqueamento visual + debug "esse bloco entrou só por priority, não pela semântica".

2. **`rag_blocks_skipped`** jsonb (NEW) — blocos que match na similarity mas foram cortados por quota. Permite UI "quase entrou, mas saiu por quota". Crítico pra debugar regras mal calibradas (caso RCIU descoberto no P1, onde peso-fetal-percentil ficou em 6º lugar quando quota era 5).

## 2. Achado importante

A RPC `match_knowledge_blocks` (em `packages/db/src/sql/0002_retriever_rpc.sql`) **JÁ RETORNA** `similarity float` no resultado. Só não está sendo propagado pelo retriever pro audit. **Trabalho real é pequeno** — não precisa recalcular nada.

## 3. Mudanças propostas (em ordem)

### M1 — Tipo `RagBlockForPrompt` ganha `similarity`

**Arquivo:** `packages/shared/src/schemas/ragBlock.ts`

```typescript
export const RagBlockForPromptSchema = z.object({
  id: z.string().uuid(),
  kind: RagBlockKindSchema,
  title: z.string(),
  content: z.string(),
  priority: z.number().int(),
  // NEW: cosine similarity ao query embedding. Nullish porque sources
  // futuros (ex: blocos seed sem embedding) podem não ter.
  similarity: z.number().nullish(),
});
```

### M2 — Retriever propaga similarity

**Arquivo:** `apps/api/src/server/pipeline/retriever.ts`

Onde o retriever monta cada `RagBlockForPrompt` a partir das rows da RPC:

```typescript
// ANTES
{
  id: r.id,
  kind: r.kind,
  title: r.title,
  content: r.content,
  priority: r.priority,
}

// DEPOIS
{
  id: r.id,
  kind: r.kind,
  title: r.title,
  content: r.content,
  priority: r.priority,
  similarity: r.similarity ?? null, // ← NEW
}
```

### M3 — Retriever também retorna `skipped`

**Arquivo:** `apps/api/src/server/pipeline/retriever.ts`

Atualmente, blocks que estouram quota são descartados silenciosamente:

```typescript
// ATUAL
for (const r of rows) {
  const list = grouped.get(r.kind) ?? [];
  if (list.length < (quotas[r.kind] ?? 0)) {
    list.push({...});
    grouped.set(r.kind, list);
  }
  // ← blocks que estouram quota são perdidos
}
```

**Mudança:** capturar overflow em array `skipped`:

```typescript
// PROPOSTO
const skipped: RagBlockForPrompt[] = [];
for (const r of rows) {
  const list = grouped.get(r.kind) ?? [];
  if (list.length < (quotas[r.kind] ?? 0)) {
    list.push({ ...r, similarity: r.similarity ?? null });
    grouped.set(r.kind, list);
  } else {
    // Match semanticamente válido mas cortado por quota
    skipped.push({ ...r, similarity: r.similarity ?? null });
  }
}
```

E atualizar o retorno:

```typescript
return {
  blocks,
  skipped, // ← NEW
  queryText,
  warning,
};
```

### M4 — Schema Drizzle adiciona `ragBlocksSkipped`

**Arquivo:** `packages/db/src/schema/generationAudit.ts`

Adicionar logo após `ragBlocksRetrieved`:

```typescript
ragBlocksRetrieved: jsonb("rag_blocks_retrieved"),
ragBlocksSkipped: jsonb("rag_blocks_skipped"), // ← NEW
```

### M5 — SQL migration

**Arquivo NEW:** `packages/db/src/sql/0004_rag_blocks_skipped.sql`

```sql
-- =============================================================================
-- 0004_rag_blocks_skipped.sql
--
-- Adiciona generation_audit.rag_blocks_skipped pra suportar o Painel
-- Dissecador (Fase 3 do ADR-0001).
--
-- Ref: ADR-0001 §6.11 — trilha forense de RAG
--
-- Idempotente. Aplicar via:
--   supabase db push  OU  mcp__plugin_supabase_supabase__apply_migration
-- =============================================================================

alter table public.generation_audit
  add column if not exists rag_blocks_skipped jsonb default '[]'::jsonb;

comment on column public.generation_audit.rag_blocks_skipped is
  'Blocos RAG que match na busca semântica mas foram cortados por quota_por_kind. Permite UI dissecadora mostrar "quase entrou, mas saiu por quota". Cada item segue o mesmo shape de rag_blocks_retrieved (id, kind, title, content, priority, similarity).';
```

### M6 — route.ts popula ragBlocksSkipped

**Arquivo:** `apps/api/src/app/api/generate/route.ts`

Onde hoje tem:

```typescript
auditState.ragBlocksRetrieved = blocks;
```

Adicionar (logo abaixo):

```typescript
auditState.ragBlocksRetrieved = blocks;
auditState.ragBlocksSkipped = skipped; // ← NEW
```

Onde recebe o retorno do retriever:

```typescript
const { blocks, skipped, queryText, warning } = await runRetriever({...});
```

E adicionar `ragBlocksSkipped: unknown | null` ao `GenerationAuditState` no início do arquivo.

### M7 — auditRepo persiste o novo campo

**Arquivo:** `apps/api/src/server/db/auditRepo.ts`

Adicionar `ragBlocksSkipped: unknown | null` ao tipo do estado e incluir no insert:

```typescript
.from("generation_audit").insert({
  // ... outros campos
  rag_blocks_retrieved: state.ragBlocksRetrieved,
  rag_blocks_skipped: state.ragBlocksSkipped, // ← NEW
  // ...
})
```

## 4. Validação

### Divisão de responsabilidades

| Quem | O que faz |
|---|---|
| **dex1** (ou c1 manual) | M1-M7 (mudanças em TypeScript: schemas, retriever, route, auditRepo) |
| **dex1** (ou c1 manual) | Criar o arquivo SQL `0004_rag_blocks_skipped.sql` em `packages/db/src/sql/` |
| **Claude Code** (Supabase MCP) | **APLICAR a migration na produção** (`apply_migration`) — NUNCA aplicar via psql/script local; sempre via MCP |
| **Claude Code** (Supabase MCP) | Rodar queries de validação E2E (SELECT pra verificar campos populados) |
| **dex1** | typecheck local |

**Regra de ouro:** qualquer escrita no banco (CREATE, ALTER, INSERT, UPDATE, DELETE) é EXCLUSIVAMENTE via Claude Code com Supabase MCP. dex1 e c1 só lêem (read-only) ou criam arquivos SQL pra depois Claude Code aplicar.

### typecheck
```bash
pnpm --filter @laudousg/shared --filter @laudousg/db --filter @laudousg/api typecheck
```
Esperado: PASS em todos os 3 packages.

### Aplicar migration
**Via Claude Code com Supabase MCP** (dispatch o claude code com o conteúdo do .sql):
```sql
-- Confere antes
SELECT column_name FROM information_schema.columns
WHERE table_name='generation_audit' AND column_name='rag_blocks_skipped';
-- Vazio = não existe. Aplica migration.

-- Aplica via apply_migration (passa o conteúdo do 0004_rag_blocks_skipped.sql)

-- Confirma após
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name='generation_audit' AND column_name IN ('rag_blocks_retrieved', 'rag_blocks_skipped');
```

### Teste E2E
1. Gerar 1 laudo OBSTETRICA pelo app (com cenário simples — espera-se ~6 universais + 2 contextuais "extras")
2. Query SQL pra confirmar que tem dados:
```sql
SELECT
  id,
  jsonb_array_length(rag_blocks_retrieved) as n_retrieved,
  jsonb_array_length(rag_blocks_skipped) as n_skipped,
  rag_blocks_retrieved->0->'similarity' as primeiro_similarity
FROM generation_audit
WHERE category = 'OBSTETRICA'
ORDER BY created_at DESC
LIMIT 1;
```
Esperado:
- `n_retrieved` > 0 (esperado ~10-15 com quotas atuais)
- `n_skipped` ≥ 0 (depende — cenário com poucas regras pode não ter skipped)
- `primeiro_similarity` > 0 (número entre 0-1, validando que o score persistiu)

## 5. Risk + rollback

**Risk baixo:** mudanças são puramente aditivas (novo campo jsonb default '[]', novo campo opcional em type). Não quebra fluxo atual.

**Rollback se algo der errado:**
```sql
ALTER TABLE public.generation_audit DROP COLUMN IF EXISTS rag_blocks_skipped;
```

Schema TS volta sem o campo — sem impacto em código existente porque é opcional.

## 6. Estimativa de tempo

- M1+M2+M3 (TS no monorepo): 30 min
- M4 (Drizzle schema): 5 min
- M5+migration apply: 15 min
- M6+M7 (route.ts + auditRepo): 15 min
- typecheck + teste E2E + validação SQL: 30 min

**Total: ~1.5-2h**

## 7. Quando disparar

**Não bloqueante.** Pode rodar em paralelo com P3 (extração das 5 categorias). São arquivos diferentes:
- P3: `packages/knowledge/snippets/{CATEGORIA}/*.md`
- P4: `packages/shared/src/schemas/ragBlock.ts`, `apps/api/src/server/pipeline/retriever.ts`, `packages/db/src/schema/generationAudit.ts`, `packages/db/src/sql/0004_*.sql`, `apps/api/src/app/api/generate/route.ts`, `apps/api/src/server/db/auditRepo.ts`

Sem conflitos de merge esperados.

## 8. Pós-implementação

Quando P4 estiver em produção, dados de `similarity_score` + `rag_blocks_skipped` vão começar a acumular automaticamente. Em ~50-100 laudos, já dá pra:
- Identificar regras com baixa similarity (top similarity < 0.3 → keywords no header podem ajudar)
- Identificar quotas mal calibradas (skipped consistentemente cheio em mesmo kind → aumentar quota)
- Validar empiricamente o padrão universal vs contextual (universais sempre entram independente de similarity?)

Esses insights alimentam P7 (Painel Testbench) com dados reais.

---

## Quando dex1/Claude Code terminar

Reportar pra c1:
1. Diff dos 6 arquivos modificados/criados
2. Output do typecheck (esperado: PASS)
3. Output da query SQL pós-migration
4. Output da query E2E (laudo gerado com novos campos populados)
5. Surpresas/decisões
