# Sprint P3 — Expandir RAG pras 5 categorias com contracts

> **Brief preparado por:** c1 (orquestrador)
> **Destinatário:** dex1 (Codex GPT-5.5 high)
> **Status:** rascunhado em 2026-05-21, pronto pra disparar quando OBSTETRICA estiver totalmente sólido
> **Pré-requisitos:**
>   - P1 (RAG OBSTETRICA) ✅ — 78 rows validated, padrão de priorities consolidado
>   - P2 (DeterministicSanity por categoria) ✅ — 6 categorias com validators clínicos
>   - Re-teste OBSTETRICA cenários complexos validado pelo Luiz
> **Duração estimada:** 3-5 dias de dex1 (1 dia por categoria + 1 dia de polimento)

---

## 1. Contexto

OBSTETRICA agora está em estado sólido com 26 blocos, 5 regras universais (priority 92-100) + 5 contextuais (priority 70), quotas calibradas. Padrão de extração validado:

- ✅ Templates: `template-padrao.md`, `template-inicial.md` (formato `modelo`)
- ✅ Regras universais: ordem-secoes, preservar-terminologia, frases-normais-quando-omitido, dias-da-ig, etc.
- ✅ Regras contextuais: calculo-dsm, modelo-inicial, gestacao-gemelar, etc.
- ✅ Excecoes: titulo, marcadores liquido amniotico
- ✅ Frases padrão: biometria, placenta, apresentacao-e-vitalidade, etc.
- ✅ Conclusões: gestacao-padrao, gestacao-inicial, peso-fetal-percentil

Quotas atuais (commit `f245406`): modelo=1, regra=8, frase=8, conclusao=3, excecao=3.

## 2. Objetivo do P3

Aplicar o mesmo padrão pras 5 categorias que JÁ TÊM contracts no `apps/api/src/server/prompts/contracts/` (validadas pelo Luiz como prioritárias):

1. **DOPPLER_OBSTETRICO** (132 linhas no /laudousg/categoryDefaults)
2. **TIREOIDE** (~140 linhas)
3. **MAMARIA** (~160 linhas)
4. **ABDOMEN_TOTAL** (~310 linhas — a maior)
5. **PELVE_FEMININA** (~110 linhas)

Total estimado: ~850 linhas de prompts canônicos em `/laudousg/` virando ~80-120 blocos markdown.

## 3. Padrão consolidado a aplicar

Pra cada categoria:

### 3.1 Estrutura de arquivos
```
packages/knowledge/snippets/{CATEGORIA}/
├── modelo/
│   ├── template-padrao.md (ou nomes específicos da categoria)
│   └── (variações se houver, ex: template-com-doppler.md)
├── regra/
│   ├── ordem-secoes.md (universal, priority 99)
│   ├── preservar-terminologia.md (universal, priority 94)
│   ├── frases-normais-quando-omitido.md (universal, priority 93)
│   ├── (mais universais específicas da categoria, priority 90-95)
│   ├── (contextuais por sub-condição, priority 70)
├── frase/
│   ├── (frases padrão extraídas verbatim do /laudousg/)
├── conclusao/
│   ├── (conclusões padrão por contexto)
├── excecao/
│   ├── titulo.md (se categoria tem header fixo)
│   ├── (outras exceções específicas)
└── range/ (se aplicável, raro)
```

### 3.2 Padrão de priorities

**Universais (priority 90-100):** todo laudo da categoria precisa
- ordem-secoes (99) — estrutura inviolável
- preservar-terminologia (94)
- frases-normais-quando-omitido (93)
- 1-3 regras universais específicas da categoria

**Contextuais (priority 70):** só aplicam em casos específicos
- Marcar com `priority_tier: contextual` no frontmatter
- Adicionar header `GATILHOS DE APLICAÇÃO:` no início do bloco com keywords explícitas (aumenta similarity)

### 3.3 Frontmatter padrão

```yaml
---
id: {categoria-lowercase}-{kind}-{slug}
category: {CATEGORIA_UPPERCASE}
kind: modelo | regra | frase | conclusao | excecao
tags: [...]
priority: {92-100 se universal, 70 se contextual}
priority_tier: universal | contextual
version: 1.0.0
status: published
source_path: /Users/luizprazeres/laudousg/lib/categoryDefaults.ts
source_extracted_at: 2026-05-21
source_lines: {linhas no source}
---
```

## 4. Tarefas numeradas

### T1 — Setup
1. Ler /Users/luizprazeres/laudousg-swift/LaudoUSG/docs/adr/0001-camada-geracao-laudos.md §6.10 (priority logic consolidada)
2. Inspecionar 2-3 blocks recentes de OBSTETRICA pra calibrar style:
   - `/Users/luizprazeres/laudousgmobile-def/packages/knowledge/snippets/OBSTETRICA/regra/ordem-secoes.md`
   - `/Users/luizprazeres/laudousgmobile-def/packages/knowledge/snippets/OBSTETRICA/regra/frases-normais-quando-omitido.md`
   - `/Users/luizprazeres/laudousgmobile-def/packages/knowledge/snippets/OBSTETRICA/modelo/template-padrao.md`

### T2-T6 — Extração por categoria (uma por uma)

Pra cada categoria (em ordem):

#### T2: ABDOMEN_TOTAL (maior, ~310 linhas no source)
- Identificar string `ABDOMEN_TOTAL:` em `/Users/luizprazeres/laudousg/lib/categoryDefaults.ts`
- Quebrar em:
  - **modelo**: template padrão (com/sem patologias)
  - **regra universal**: ordem-seções (Indicação → Achados → Conclusão), preservar-terminologia, frases-normais-default
  - **regra contextual**: cálculo de volume hepático (se específico), litíase com diagnóstico contextual, esteatose graduação, etc.
  - **frase**: fígado normal, vesícula normal, vias biliares normais, pâncreas normal, baço normal, rins normais, aorta normal, retroperitônio normal
  - **conclusao**: padrão normal, com colelitíase pequena, com esteatose leve, etc.
- Criar arquivos em `packages/knowledge/snippets/ABDOMEN_TOTAL/`
- Ingest: `pnpm tsx apps/api/scripts/ingest-knowledge.ts --category ABDOMEN_TOTAL` (após confirmar com c1)

#### T3: MAMARIA
Mesmo processo. Atenção: BI-RADS é classificação reproduzida (médico decide número), nunca calculada pela IA.

#### T4: TIREOIDE
TI-RADS + classificação Domingos. Nódulos.

#### T5: DOPPLER_OBSTETRICO
IP umbilical, MCA, artérias uterinas. Percentis.

#### T6: PELVE_FEMININA
Endométrio (idade reprodutiva vs pós-menopausa), miomatose, cistos ovarianos, O-RADS.

### T7 — Validações
Pra CADA categoria após extração:
1. `pnpm --filter @laudousg/api typecheck` → PASS
2. Verificar visual dos blocks criados:
   - Frontmatter completo
   - Priority adequado (universal vs contextual)
   - Source tracking (linhas do source)
3. Reportar resumo pra c1 ANTES de ingest

### T8 — Não fazer
- NÃO modificar nada em `/laudousg/`
- NÃO adicionar deps novas (não deve ser necessário)
- NÃO commitar — c1 (orquestrador) faz
- NÃO rodar ingest em produção sem confirmação
- NÃO inventar regras (verbatim do source)

## 5. Padrões específicos

### Quando criar regra "frases-normais-quando-omitido" por categoria

A lógica de "se médico omitir descritor qualitativo, usar normal default" varia por categoria:

- **ABDOMEN_TOTAL**: "Fígado de aspecto normal", "Vesícula biliar de paredes finas, sem cálculos", etc.
- **MAMARIA**: "Mamas de constituição fibroglandular usual", "Sem nódulos ou cistos", etc.
- **TIREOIDE**: "Tireoide de dimensões e ecotextura normais", "Sem nódulos", etc.
- **DOPPLER_OBSTETRICO**: "Doppler arterial dentro da normalidade" se médico só passar achados gerais.
- **PELVE_FEMININA**: "Útero de dimensões e ecotextura normais", "Endométrio de espessura adequada", etc.

Cada categoria precisa de uma regra própria adaptada — extrair frases normais do template padrão e listar em `regra/frases-normais-quando-omitido.md`.

### Quando criar regra "preservar-terminologia"

Pra cada categoria, identificar termos clinicamente próximos que NÃO podem ser confundidos:

- **MAMARIA**: nódulo vs cisto vs lesão vs massa
- **TIREOIDE**: nódulo vs cisto vs lesão; classificação Domingos vs TI-RADS (preservar a que médico falou)
- **ABDOMEN_TOTAL**: cálculo vs concreção vs litíase
- **DOPPLER_OBSTETRICO**: ausente vs reverso vs ausente reverso (diástole)
- **PELVE_FEMININA**: cisto vs cisto funcional vs cisto endometriótico

## 6. Quando terminar (pra cada categoria)

Reporta pra c1 em PT-BR (~200-300 palavras por categoria):
1. Nome da categoria
2. Quantos blocos criados, breakdown por kind
3. Lista breve dos universais criados (com priority cada)
4. Lista breve dos contextuais criados (com keywords no header se aplicável)
5. Surpresas ou decisões durante a extração
6. Próxima categoria a atacar

Quando TODAS as 5 estiverem prontas:
- Sumário consolidado (1 página)
- Pergunte se c1 quer dispatch do ingest categoria-por-categoria ou tudo de uma vez

## 7. Estimativa de tempo

Por categoria:
- ABDOMEN_TOTAL: 1.5-2h (maior, ~310 linhas)
- MAMARIA: 1-1.5h
- TIREOIDE: 1-1.5h
- DOPPLER_OBSTETRICO: 1.5h (regras de IP/percentis específicas)
- PELVE_FEMININA: 1-1.5h

**Total estimado: 6-8h de dex1**, podendo dividir em 2-3 sessões.

## 8. Pré-requisito de disparo

Não disparar até:
- Luiz confirmar OBSTETRICA está sólido após re-teste com regra `frases-normais-quando-omitido`
- (Opcional) Luiz validar 1 cenário de cada uma das 5 categorias no app atual pra ter baseline antes de mudar
