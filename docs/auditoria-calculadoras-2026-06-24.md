# Auditoria Clínica das Calculadoras — App iOS (2026-06-24)

> ⚠️ **Distinção importante:** marquei cada achado como **[CÓDIGO]** (posso corrigir sozinho com segurança) ou **[CLÍNICO]** (decisão médica — só o Dr. Luiz valida antes de eu mexer). NÃO vou alterar fórmula/cutoff clínico sem o seu aval.
>
> ✅ **Verificado e OK:** Hadlock 4 (fórmula/constantes), fator elipsoide 0,523, mediana MCA-PSV (Mari), GA-por-fêmur (Hadlock), pontuação/cutoffs TI-RADS e BI-RADS, ILA 4Q (Phelan).

## 🔴 CRÍTICOS — precisam de você

### #2 [CLÍNICO] Doppler pode mascarar centralização (RCP/ACM patológico com UA normal)
`Services/DopplerCalculator.swift:159-176` (`aplicarCorrecoesClinicas`) — quando a a. umbilical está normal mas ACM/RCP saem patológicos, o código **sobrescreve para percentil 5 e `pathological:false`**. Risco: uma **centralização real** (RCP baixo = marcador precoce de hipóxia) ser reportada como normal. O agente classificou como "clinicamente invertida". **⚠️ Preciso que você confirme se essa regra está mesmo errada antes de eu tocar — é decisão sua.**

### #1 [CÓDIGO] `parseDateBR` aceita datas impossíveis / timezone / sem faixa
`Services/GestationalAgeCalculator.swift:78-95` — aceita DUM como `01/01/1900` (IG de milhares de semanas), ramo ISO sem timezone fixo desloca ±1 dia (UTC-3), sem limite superior de IG. **Posso corrigir** (validar faixa plausível, fixar timezone, rejeitar IG>45sem).

## 🟠 ALTA

### #6 [CÓDIGO] `normalizeCm` pode corromper CA/CC digitado em cm
`Services/HadlockCalculator.swift:81-86` — regra "valor>20 → /10" trata um CA de 35 **cm** (legítimo) como 3,5 cm, arruinando o peso fetal. Ambígua entre cm/mm para circunferências grandes. **Posso corrigir** (limiar por medida ou exigir unidade).

### #5 [CLÍNICO/MÉTODO] Percentil por gaussiana em curvas assimétricas
`PercentileTable+Intergrowth.swift:68-72` — deriva percentis extremos (p<3,>97) assumindo normalidade a partir de p10/p90; curvas de peso são skewed → erra SGA/LGA nos extremos. **Sugiro interpolar entre percentis tabelados** — confirmar abordagem.

### #4 [CLÍNICO] Cutoff anemia MCA-PSV: 1,55 vs 1,50 MoM (Mari)
`Services/AnemiaMCAPSVCalculator.swift:18-29` — faixa 1,50-1,55 "moderada a severa" sem disparar recomendação de transfusão; cutoff consagrado é **≥1,50 MoM**. Risco de subtratar. **Decisão sua.**

## 🟡 MÉDIA (resumo)
- #3 [CÓDIGO] `IGCalculatorSheet:87` Stepper aceita 0 semanas na 1ª USG (piso clínico ~5-6).
- #7 [CLÍNICO] `DuctoVenosoCalculator:61-66` mediana por regressão linear própria, não Hecher real → "percentil" com falsa precisão.
- #8 [CÓDIGO] `TIRADSCalculator:144-159` comparação `>=` com parsing vírgula: 1,5→1.4999 perde cutoff. Arredondar 1 casa.
- #9 [CÓDIGO] `MyomaFindingsParser:101-123` regex pode pegar medida de outra estrutura na mesma sentença.
- #10 [CÓDIGO] `SanityChecker:96-108` valida só dia>31/mês>12 — aceita 31/04, 29/02 não-bissexto.
- #11 [CLÍNICO] `PreEclampsiaCalculator:77` cutoff IP uterinas 2,35 fixo (varia com IG); IG até 24 sem extrapola FMF 1º tri.
- #12 [CÓDIGO] Volumes (tireoide/útero/residual) sem guard de unidade: medida em mm → volume 1000× errado.

## Plano
- **Eu corrijo (CÓDIGO, baixo risco):** #1, #6, #3, #8, #9, #10, #12 — com validação por compilação.
- **Aguardam seu aval (CLÍNICO):** #2, #4, #5, #7, #11.
