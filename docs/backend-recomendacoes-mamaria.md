# Recomendações pro backend (geração de laudo) — categoria MAMÁRIA

> Reportado a partir de laudo real (IMG_4538, 2026-05-24). Os 4 bugs do parser
> iOS foram corrigidos em `BreastFindingsParser.swift` (S19.8). Os bugs abaixo
> são do **backend** (`laudousgmobile.vercel.app/api/generate`) e demandam
> ajustes no prompt e/ou pós-processamento determinístico.

---

## Bug A — Alucinações de transcrição não corrigidas

**Sintoma:**
```
CONCLUSÃO:
Cisto simples de mão na direita categoria de radios 2
```

Deveria ser:
```
CONCLUSÃO:
1) Cisto simples de mama direita (categoria BI-RADS 2)
2) Linfonodos axilares de aspecto habitual
```

Problemas:
- "mão" deveria ser **mama**
- "categoria de radios 2" deveria ser **(categoria BI-RADS 2)** — sem "de", BI-RADS em caixa correta, entre parênteses
- Falta numeração
- Falta o item 2 (linfonodos axilares — mencionado em "OS SEGUINTES ASPECTOS" mas omitido na conclusão)

**Fix proposto — duas camadas:**

### Camada 1: pós-processamento determinístico (regex no output do LLM)

Adicionar em `apps/api/src/server/postProcess/mamaria.ts`:

```ts
const TYPO_FIXES: Array<[RegExp, string]> = [
  // "mão" no contexto de mama
  [/\bmão\s+(direita|esquerda)\b/gi, 'mama $1'],
  [/\bmãos\b/gi, 'mamas'],

  // BI-RADS variantes do Whisper
  [/\b(?:categoria\s+(?:de\s+)?)?radios\s*(\d|\d\s*[ABC])\b/gi, '(categoria BI-RADS $1)'],
  [/\bbirádios?\b/gi, 'BI-RADS'],
  [/\bbirads\b/gi, 'BI-RADS'],
  [/\bbi[-\s]?rads\b/gi, 'BI-RADS'],

  // Outros típicos
  [/\banecóica?\s+ou\s+anecoico?\b/gi, 'anecoica'],
]

export function postProcessMammaryReport(text: string): string {
  let out = text
  for (const [re, repl] of TYPO_FIXES) {
    out = out.replace(re, repl)
  }
  return out
}
```

### Camada 2: glossário no system prompt

Adicionar no prompt do `/api/generate` quando `category=MAMARIA`:

```
GLOSSÁRIO OBRIGATÓRIO (corrija o transcrito antes de gerar):
- "mão direita/esquerda" → mama direita/esquerda
- "radios" / "birádios" / "bi rads" → BI-RADS
- Categoria BI-RADS sempre entre parênteses: "(categoria BI-RADS X)"
```

---

## Bug B — Conclusão sem numeração + achados omitidos

**Regra:** Quando houver 2+ achados/conclusões, numerar como `1)`, `2)`, etc.
Toda menção em "OS SEGUINTES ASPECTOS FORAM OBSERVADOS" que represente um
achado distinto deve ter linha correspondente na conclusão (mesmo se for
"de aspecto habitual" — não pode sumir).

**Fix proposto — system prompt:**

```
ESTRUTURA OBRIGATÓRIA DA CONCLUSÃO:
- Numere TODOS os achados como "1)", "2)", "3)" etc., um por linha.
- Cada achado/estrutura descrita acima deve ter linha correspondente na conclusão:
  - Cistos / nódulos / calcificações → linha específica com BI-RADS
  - Linfonodos axilares → "Linfonodos axilares de aspecto habitual" (BI-RADS 2)
    quando descritos como benignos
  - Ecotextura da mama → mencionar só se atípica
- BI-RADS sempre ao final da linha do achado, entre parênteses.

EXEMPLO BOM:
CONCLUSÃO:
1) Cisto simples de mama direita (categoria BI-RADS 2)
2) Linfonodos axilares de aspecto habitual (categoria BI-RADS 2)
```

---

## Bug C — Inteligência clínica implícita (CRÍTICO)

O médico fala minimamente ou usa termos parciais. O LLM precisa **inferir** o
restante a partir de regras anatômicas/ecográficas conhecidas.

### Regras de inferência (anatomia das mamas)

#### Eco-padrão → tipo da lesão

| Descrição mínima | Tipo inferido | Margens default | BI-RADS típico |
|---|---|---|---|
| anecoica | cisto simples | circunscritas | 2 |
| anecoica c/ septação fina | cisto complicado | circunscritas | 2-3 |
| hipoecoica circunscrita | nódulo sólido provavelmente benigno | circunscritas | 3 |
| hipoecoica indistinta/espiculada | nódulo sólido suspeito | indistintas/espiculadas | 4 |
| isoecoica | nódulo sólido | a especificar | 3-4 |
| hiperecoica | provável lipoma/cisto oleoso | circunscritas | 2 |
| oval c/ centro hiperecoico c/ periferia hipoecoica | linfonodo (hilo gorduroso) | n/a | 2 |
| microcalcificações | calcificação | n/a | 3-5 conforme padrão |

#### Hora → quadrante (relógio anatômico)

A descrição mamária usa relógio em sentido horário (12h sempre no topo),
**mas a interpretação anatômica do quadrante depende do lado**:

| Hora | Mama DIREITA (quadrante) | Mama ESQUERDA (quadrante) |
|---|---|---|
| 12h | união dos quadrantes superiores | união dos quadrantes superiores |
| 1-2h | QSM (superomedial) | QSL (superolateral) |
| 3h | união dos quadrantes mediais | união dos quadrantes laterais |
| 4-5h | QIM (inferomedial) | QIL (inferolateral) |
| 6h | união dos quadrantes inferiores | união dos quadrantes inferiores |
| 7-8h | QIL (inferolateral) | QIM (inferomedial) |
| 9h | união dos quadrantes laterais | união dos quadrantes mediais |
| 10-11h | QSL (superolateral) | QSM (superomedial) |

**Princípio:** mama direita e mama esquerda são **espelhadas** em relação ao
relógio. 3h sempre é o lado interno do tórax (medial na direita, lateral na
esquerda); 9h sempre é o externo. 12h e 6h são neutros.

#### Medidas

- **cm** em mama é típico de **cisto/sólido** (≥10mm)
- **mm** é típico de pequeno nódulo, linfonodo, microcalcificação
- Sempre que vier `X x Y x Z` em **cm**, manter em cm no laudo (não converter pra mm no texto)

### Implementação proposta — prompt enrichment

Adicionar como "knowledge block" no `RAG snippets` para MAMARIA:

```yaml
# packages/knowledge/snippets/MAMARIA/regra/inteligencia-eco-implicita.md
---
id: mamaria-inteligencia-eco-implicita
category: MAMARIA
priority: 90  # universal — sempre incluir
tags: [mama, ecografia, inferencia, hora, quadrante]
---

INFERÊNCIAS OBRIGATÓRIAS quando o médico ditar de forma resumida:

1. **Eco-padrão → tipo (mesmo sem dizer "cisto" ou "nódulo")**:
   - "anecoica" sozinha → cisto simples; assumir margens circunscritas e BI-RADS 2
   - "hipoecoica/isoecoica" → nódulo sólido
   - "imagem oval com centro hiperecoico e periferia hipoecoica" + "axila" → linfonodo (hilo)
   - "microcalcificações" → calcificações

2. **Hora → quadrante (descrição completa esperada no laudo)**:
   Use a tabela: mama direita e esquerda são ESPELHADAS.
   - 12h → "junção dos quadrantes superiores"
   - 3h MD → "junção dos quadrantes mediais"; ME → "junção dos quadrantes laterais"
   - 6h → "junção dos quadrantes inferiores"
   - 9h MD → "junção dos quadrantes laterais"; ME → "junção dos quadrantes mediais"
   - 1-2h MD → QSM; ME → QSL
   - 4-5h MD → QIM; ME → QIL
   - 7-8h MD → QIL; ME → QIM
   - 10-11h MD → QSL; ME → QSM

3. **NUNCA omita o quadrante** quando o médico der só a hora.
   Sempre escreva "às Xh, no quadrante Y" ou "às Xh, na junção dos quadrantes Y".

4. **Medidas em cm**: manter em cm. Em mm: manter em mm. Não converter.

EXEMPLO DE TRANSFORMAÇÃO MÍNIMO → LAUDO COMPLETO:

Input ditado: "anecoica 2cm às 10h na direita 3cm do mamilo"
Output esperado:
"Imagem anecoica em mama direita, com margens circunscritas, medindo 2,0 cm,
situada no quadrante superolateral, às 10 horas, distando 3,0 cm do mamilo —
compatível com cisto simples."
```

---

## Bug D — Sanity check determinístico no app iOS

Independente das correções acima, o `SanityChecker.swift` poderia ter regras
específicas pra mamária que flagam:

- Output contém "mão" + "direita|esquerda" → "Provável erro de transcrição: revisar 'mão' → 'mama'"
- Output contém "radios" sem ser "BI-RADS" → "Provável erro: 'radios' → 'BI-RADS'"
- Múltiplos achados em "OS SEGUINTES ASPECTOS" mas conclusão sem numeração → "Recomenda-se numerar a conclusão"
- Linfonodo axilar mencionado em "ASPECTOS" mas ausente da conclusão → flagged

Isso é trabalho separado, mas pode salvar o usuário quando o backend falhar.

---

## Prioridade sugerida

1. **Bug A (alucinações)** — high. Pós-processamento determinístico é fácil e elimina o problema imediato.
2. **Bug B (numeração + completude)** — high. Prompt-only fix.
3. **Bug C (inteligência clínica)** — medium-high. RAG snippet novo + prompt enriquecido. Demanda mais teste.
4. **Bug D (sanity client-side)** — medium. Defesa em profundidade.
