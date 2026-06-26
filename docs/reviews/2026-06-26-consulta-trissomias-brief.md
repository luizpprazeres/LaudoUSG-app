# CONSULTA DE ARQUITETURA — Calculadora de Trissomias melhorada + Relatório (app Swift, depois Android)

> Vocês são consultores na FASE DE PLANEJAMENTO. Não implementem nada agora. Quero o parecer técnico de vocês
> sobre a MELHOR ABORDAGEM, antes de eu (Claude/orquestrador) escrever o plano final para o Dr. Luiz.
> Respondam **escrevendo num arquivo** (Dex1 → `/tmp/resposta-dex1-trissomias.md`, Dex2 → `/tmp/resposta-dex2-trissomias.md`).
> Sejam concretos, com file:line quando citar código. Podem ler os paths absolutos abaixo (mesma máquina).

## OBJETIVO
O Dr. Luiz quer uma versão MELHORADA da calculadora de trissomias (rastreio combinado do 1º trimestre, padrão
**Fetal Medicine Foundation** — referência máxima: https://fetalmedicine.org/website/#/calculators) primeiro no
**app iOS Swift**, depois no Android RN. Além do cálculo, quer um **output elegante e profissional em português**
no estilo do "Relatório do rastreio do primeiro trimestre" da FMF (relatório com dados da paciente, características
maternas, achados ecográficos, marcadores, riscos BASAL e CORRIGIDO de T21/T18/T13 + pré-eclâmpsia + restrição de
crescimento, e GRÁFICOS de CCC, TN e curva de risco).

## DECISÕES DE PRODUTO JÁ TRAVADAS (pelo Dr. Luiz)
1. **Output = AMBOS**: bloco de texto inserido no laudo (como as outras calculadoras) **+** opção de exportar o
   **relatório completo (PDF visual)** à parte.
2. **Escopo = relatório completo do 1º tri**: T21/T18/T13 + **pré-eclâmpsia** + **restrição de crescimento (RCF)**.
3. **Gráficos = SIM** na v1 (curvas de CCC, TN e curva de risco de T21 com o ponto da paciente plotado).

## O QUE JÁ EXISTE (mapeado)
### laudousg WEB (Next.js/TS) — `/Users/luizprazeres/laudousg`
Calculadora FMF de trissomias COMPLETA (algoritmo Bayesiano):
- `lib/calculators/fmfTrisomy.ts` — orquestrador: CRL→GA (Robinson), prior de Cuckle, LR de NT (mixture Wright 2008),
  bioquímica+FHR (gaussiano Kagan 2008), DV-PI, regurgitação tricúspide, osso nasal, correção de MoM (Kagan 2008c),
  posterior de Bayes, classificação de risco.
- `lib/calculators/fmfTrisomyParams.ts` — constantes (mixtures, gaussianas, truncation, correção MoM).
- `lib/calculators/fmfTrisomyTypes.ts`, `fmfTrisomyFormatter.ts` (gera bloco de texto PT).
- `app/api/fmf-trisomy-risk/route.ts` — endpoint.
- `components/FmfTrisomyCalculatorPanel.tsx` — UI web (612 linhas).
- `fmf-research/r-models/*.csv` (~47 arquivos) — parâmetros: gauss mean/sd/cor por trissomia, NT mixture + tlimits,
  DVPI mixture + tlimits, tricúspide, osso nasal, maternal_age_lookup.

### App Swift — `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG`
- NÃO tem calculadora de trissomias. Tem 14 calculadoras com padrão claro:
  `Services/<Nome>Calculator.swift` (enum com `struct Input: Sendable` + `struct Result` com `insertBloco: String` +
  `static func calculate()`), e `Components/Sheets/<Nome>CalculatorSheet.swift` (@MainActor View), registradas em
  `Components/Sheets/CalculatorsSheet.swift`.
- JÁ existe `Services/PreEclampsiaCalculator.swift` (triagem PE 1º tri FMF) — reaproveitar para o item PE do relatório.
- Output das calculadoras = texto plano no laudo. PDF rico só existe em `Features/Miomas/MyomaSchemaExporter.swift`
  (UIGraphicsPDFRenderer). Sem Swift Charts em uso até agora (confirmar).
- Auditoria recente: `docs/auditoria-calculadoras-2026-06-24.md` (achou cutoff PE IP uterinas fixo 2,35 etc.).

## PERGUNTAS PARA DEX1 (foco: FIDELIDADE / CORREÇÃO do port)
D1.1 Estratégia de port TS→Swift do algoritmo: portar fórmula-a-fórmula à mão vs. transcrever 1:1. Onde mora o maior
     risco de divergência numérica (ordem de operações, log10 vs ln, Math.pow, truncations)?
D1.2 Os ~47 CSVs + constantes: melhor embuti-los como structs Swift gerados, ou empacotar como resources (JSON/CSV) no
     bundle e carregar? Qual reduz risco de drift web↔Swift e facilita manutenção?
D1.3 Golden tests: proposta de gerar N vetores (inputs aleatórios cobrindo ranges) rodando o TS como fonte de verdade,
     e validar o Swift com tolerância (ex.: |Δrisco| relativo < 0.1%). Faz sentido? Onde colocar o harness.
D1.4 A implementação do laudousg web É fiel à FMF oficial, ou é reimplementação? Como confirmar paridade com
     fetalmedicine.org (há evidência no repo de validação? playwright/research?). Cite arquivos em `fmf-research/`.
D1.5 Os gráficos (CCC×IG, TN×CCC, curva de risco): precisamos das funções de mediana/percentil de referência. Elas
     existem no repo (params) ou teríamos que derivá-las? Risco de "inventar" curva.

## PERGUNTAS PARA DEX2 (foco: ADVERSARIAL / onde QUEBRA)
D2.1 Precisão de ponto flutuante TS(Number)→Swift(Double): além do óbvio, que armadilhas concretas (parsing de
     vírgula/ponto PT-BR, arredondamento de "1/N", clamping de LR em [1e-4,1e4]) podem gerar divergência visível?
D2.2 Edge cases clínicos que devem ser bloqueados/avisados: NT/CRL/idade fora de range, MoM extremo, IG fora de
     11–13+6, ducto/tricúspide ausentes. O que o web faz e o que pode escapar no Swift.
D2.3 Responsabilidade clínica/legal: exibir risco numérico (1/N) e um "Relatório do rastreio" assinável num app médico
     — implicações p/ Apple/Google (apps de saúde) e disclaimer obrigatório. Como blindar (igual fizemos no resto).
D2.4 Manutenção/drift: 47 CSVs duplicados entre web e Swift — qual o plano para não divergirem ao longo do tempo?
D2.5 Integração PE + RCF no relatório: o `PreEclampsiaCalculator.swift` usa o MESMO modelo FMF que o relatório espera,
     ou diverge (a auditoria citou cutoff fixo)? Para RCF, existe base no repo ou seria novo? Risco de inventar.
D2.6 Gráficos: gerar curvas sem os dados de referência corretos = risco de relatório clinicamente enganoso. Concorda
     que gráfico é P1 (depois do cálculo+texto+PDF tabular validados)? Justifique.

## ENTREGA
Cada um: parecer direto às suas perguntas + recomendação de SEQUÊNCIA DE FASES (o que é P0 mínimo confiável vs P1) +
qualquer risco que eu não listei. Escrevam no arquivo indicado. Obrigado.
