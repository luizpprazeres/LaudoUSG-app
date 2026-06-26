# Plano — Calculadora de Trissomias (FMF 1º trimestre) + Relatório elegante

> **Status:** 🟡 PLANEJADO (2026-06-26). Primeiro no **app Swift** (`laudousg-swift/LaudoUSG`), depois Android RN.
> Base: rastreio combinado do 1º trimestre padrão **Fetal Medicine Foundation**. Planejamento validado por
> consulta aos terminais **Dex1 (fidelidade)** e **Dex2 (adversarial)** — pareceres em `/tmp/resposta-dex1-trissomias.md`
> e `/tmp/resposta-dex2-trissomias.md` (copiar para `docs/reviews/` ao iniciar a implementação).

## Objetivo
Versão melhorada da calculadora de trissomias, com:
1. **Cálculo** de risco T21/T18/T13 (Bayesiano FMF) — risco **basal** e **corrigido**.
2. **Bloco de texto** inserível no laudo (padrão das demais calculadoras).
3. **Relatório PDF elegante** em português, estilo "Relatório do rastreio do primeiro trimestre" da FMF
   (dados da paciente, características maternas, achados ecográficos, marcadores usados/ausentes, tabela de riscos
   basal×corrigido, e **gráficos** de CCC, TN e curva de risco).

## Decisões de produto (Dr. Luiz, 2026-06-26)
- **Output:** bloco de texto no laudo **+** export do relatório PDF completo.
- **Escopo v1:** **só trissomias** (T21/T18/T13). **PE + RCF entram na fase 2** (ver abaixo).
- **Gráficos:** sim (entram após o cálculo validado — fase 4).
- **Marcadores obrigatórios x opcionais (input clínico do Dr. Luiz):**
  - **Núcleo usado no Brasil:** idade materna + CCN + **TN** + marcadores **ecográficos** (osso nasal, ducto venoso,
    regurgitação tricúspide, FCF). A calculadora deve **funcionar só com isso**.
  - **Bioquímica (β-hCG livre, PAPP-A) = OPCIONAL** e pouco usada aqui ("exame de sangue, a gente nem usa"). Manter
    no algoritmo (entram no cálculo se informados), mas na UI ficam atrás de uma seção **"Avançado (opcional)"**.
  - **MoM / correção de MoM = NÃO entra na v1.** Como a bioquímica é opcional e rara, **não** implementar a
    `correctMoM` (peso/etnia/tabagismo/IVF/paridade) na v1. Se o usuário informar β-hCG/PAPP-A, assume-se **MoM já
    corrigido pelo laboratório** (declarar isso no relatório). Resolve a dúvida da Fase 0.
  - ⚠️ **Artéria oftálmica:** o Dr. Luiz citou que a FMF passou a recomendar a artéria oftálmica e que vão usar
    (opcional). **Correção clínica importante:** a artéria oftálmica (PSV ratio) é marcador de **pré-eclâmpsia**, não
    de aneuploidia — ela **não** entra no cálculo de trissomias. Entra no **módulo de PE (Fase 5)** como marcador
    opcional. Anotado para confirmar com o Dr. Luiz.

## Fonte de verdade (descoberta no planejamento)
- O algoritmo **não** será inventado. Existe a especificação completa em
  `/Users/luizprazeres/laudousg/fmf-research/FMF-ALGORITHM-SPEC.md` (extraída do R oficial da FMF via WebR +
  validada contra papers: Kagan 2008/2008c, Wright 2008, Snijders 1994/1999, Santorum 2017).
- Reimplementação TS de referência: `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts` (+ `fmfTrisomyParams.ts`,
  `fmfTrisomyTypes.ts`, `fmfTrisomyFormatter.ts`). **É o guia de estrutura para o port.**
- Parâmetros: `/Users/luizprazeres/laudousg/fmf-research/r-models/*.csv` e os `.R` oficiais
  (`karyo_prior.R`, `nt_mix_lr.R`, `gauss_mom_lr.R`, `du_mix_lr.R`, `tricuspid_lr.R`, `nb_logistic_lr.R`).
- ⚠️ **Caveat de fidelidade (Dex1):** o web é reimplementação derivada — **não há prova automatizada de paridade
  com fetalmedicine.org**. Por isso há a fase de validação externa (1.5). Até lá, comunicar como
  "baseado em modelo FMF/publicações FMF", **não** como endosso/certificação da FMF.

## Arquitetura (padrão do app Swift)
Seguir o padrão existente das 14 calculadoras:
- **Service** `Services/TrissomiaFMFCalculator.swift` — `enum` com `struct Input: Sendable`, `struct Result` (com
  `insertBloco: String` **e** campos de risco basal/corrigido por trissomia), `static func calculate(...) -> Result?`.
  Núcleo **puro e testável** — nasce antes de qualquer UI.
- **Parâmetros** `Services/TrissomiaFMFParams.swift` (ou JSON no bundle) — **gerado por script** a partir da fonte
  canônica em `fmf-research/r-models`, nunca digitado à mão. Gravar `modelVersion`/hash.
- **Sheet** `Components/Sheets/TrissomiaFMFCalculatorSheet.swift` — `@MainActor View`, `@State` inputs, computed
  `result`, botão "Inserir no laudo" (`onInsert(result.insertBloco)`).
- **Registro** em `Components/Sheets/CalculatorsSheet.swift` (novo `case` no enum de destino + link no menu).
- **Relatório PDF** — reaproveitar o padrão técnico de `Features/Miomas/MyomaSchemaExporter.swift`
  (`ImageRenderer`/`UIGraphicsPDFRenderer`). Sem Swift Charts em uso hoje → gráficos desenhados em SwiftUI/CoreGraphics.

## Sequência de fases

### Fase 0 — Contrato clínico (antes de qualquer código)
Fechar por escrito: inputs aceitos + ranges (idade 15–50; CCN 45–84mm; TN 0,5–10mm; FCF 80–220bpm; MoM trunc
β-hCG 0,1–10 / PAPP-A 0,1–2); marcadores opcionais (DV-PI, tricúspide, osso nasal); **mensagens de aviso**
(TN/CCN fora de range, **MoM truncado**, CCN×DUM discordante, **marcador ausente**); decisão sobre `isMoMCorrected`
(o app corrige MoM por peso/etnia/tabagismo/IVF/paridade, ou assume já corrigido? — declarar no relatório);
texto legal/disclaimer; **expor risco basal e corrigido separadamente**; formato exato do bloco de laudo.
**Critério:** documento revisado pelo Dr. Luiz.

### Fase 1 — Núcleo Swift (serviço puro) + golden tests  ← P0 mínimo confiável
- Portar 1:1 do TS: `clamp`, `dnorm`, `dmvnorm` (1/2/3D), `crlToGaDays` (Robinson-Fleming), prior (Cuckle),
  LR de TN (mixture Wright), LR bioquímica+FCF (gaussiano), LR ducto, LR tricúspide, LR osso nasal, correção MoM,
  posterior Bayes, classificação.
- **Pontos de fidelidade obrigatórios** (Dex1+Dex2): `log10` (não ln); arredondar CRL p/ 0,1mm antes dos mapas de
  truncamento (`round(crl*10)/10`, chave `round(crlR*10)`); preservar `m.b2 * gaDiff * 2` (intencional, ver spec §12);
  **clamping de LR só onde o TS aplica** (bioquímica e DV em [1e-4,1e4]; **não** em TN/tricúspide/osso nasal);
  parse PT-BR com vírgula→ponto (cuidado: o web tem bug `parseFloat("1,8")=1` — o **golden deve usar números já
  normalizados**, não strings PT-BR, senão Swift "diverge" do bug do web).
- **Golden harness:** script Node em `laudousg/` gera `fixtures/fmf-trisomy-golden.json` cobrindo: só idade+TN; +bioquímica;
  +FCF; +ducto; +tricúspide (presente/ausente); +osso nasal (presente/ausente); etnias; tabagismo/IVF/nuliparidade;
  antecedentes; bordas de CCN/TN. Teste Swift (`LaudoUSGTests`) lê o JSON.
- **Critério de aceite:** erro relativo < 0,1% em `probability`; igualdade exata em categoria/markersUsed; `ratio`
  com tolerância de 1 unidade. **Qualquer divergência perto de cutoff bloqueia.**

### Fase 1.5 — Validação externa (FMF oficial)  ← P0.5
Gerar 30–100 casos, rodar na calculadora FMF oficial (Playwright em `fetalmedicine.org` / RefractionX), comparar
T21/T18/T13. Se divergir, **corrigir a fonte canônica/web primeiro**, depois propagar ao Swift. Registrar resultados
como fixture. Sem isso, não usar linguagem de "padrão/certificação FMF".

### Fase 2 — UI + bloco de texto no laudo
Sheet de input no padrão do app; resultado em tempo real; "Inserir no laudo". Reproduzir o bloco de texto PT
(equivalente a `formatarBlocoTrissomias`, **acrescido** de risco basal, marcadores ausentes e avisos de truncamento).
Registrar no `CalculatorsSheet`.

### Fase 3 — Relatório PDF tabular (sem gráficos)
"Relatório do rastreio do 1º trimestre": cabeçalho, dados da paciente, características maternas, achados ecográficos,
**tabela marcadores usados/ausentes**, **tabela risco basal × corrigido** (T21/18/13), disclaimers, **versão do
algoritmo/parâmetros**, data/hora, operador, avisos de truncamento. Padrão técnico do `MyomaSchemaExporter`.

### Fase 4 — Gráficos validados
CCC×IG (`crl_plot.R`/`robinson_fleming_GA.R`), TN×CCC (`nt_plot.R`), curva de risco T21 (`risk_profile_plot.R` +
`maternal_age_lookup.csv`). Portar as funções/tabelas reais; validar pontos/eixos/escala-log contra fixtures antes de
inserir no PDF. **Não inventar curvas.**

### Fase 5 (V2) — PE + RCF (competing-risks)  ← pesquisa adicional
Modelo FMF de pré-eclâmpsia/RCF/parto prematuro (risco 1/N) exige PlGF/PAPP-A/MAP/uterinas e **não está no repo**.
Pesquisar (Playwright na FMF, como nas trissomias) + portar + golden + validar, e só então integrar ao relatório.
Não misturar o `PreEclampsiaCalculator` categórico atual como se fosse o FMF completo.
- **Artéria oftálmica (PSV ratio):** marcador de PE recentemente incorporado pela FMF (Dr. Luiz vai usar) — entra
  **aqui**, como input **opcional** do modelo de PE, não nas trissomias. Pesquisar coeficientes na FMF junto com o
  resto do modelo de PE.

### Fase 6 (V3) — Android RN
Portar o **mesmo núcleo** consumindo os **mesmos golden vectors** (contrato de paridade). Não fazer 2º port manual
independente: gerar parâmetros e golden de fonte única para web, Swift e RN.

## Riscos & mitigações (consolidado dos Dex)
| Risco | Mitigação |
|------|-----------|
| Divergência numérica no port | Golden tests TS→Swift com tolerância; preservar detalhes (log10, arred. CRL, clamps por marcador) |
| Drift dos parâmetros web↔Swift↔RN | Fonte única + geração por script + `modelVersion`/hash no relatório |
| Paridade FMF não provada | Fase 1.5 (validação Playwright); linguagem "baseado em modelo FMF", sem endosso |
| Truncamento silencioso de MoM | Aviso explícito no relatório/UI |
| Basal vs corrigido | `Result` expõe os dois; relatório mostra ambos |
| Legal/lojas (app médico) | Disclaimer "não diagnóstico"; versão do modelo; marcadores usados/ausentes; (Apple/Google health policies) |
| PE/RCF inventado | Fase 5 separada, só com modelo validado |
| Gráfico clinicamente enganoso | Fase 4, fonte real + validação de pontos/eixos |

## Processo de review (por fase)
Implementar → review **Dex1 (fidelidade vs spec/R + golden)** + verificação adversarial **Dex2 (edge cases,
truncamentos, legal)** → ajustes → próxima fase. Push via @devops.
