# DEX2 — parecer adversarial sobre trissomias/FMF 1º trimestre

## D2.1 — Precisão TS(Number) → Swift(Double)

O risco principal não é `Number` versus `Double`; os dois são IEEE-754 double. Onde quebra é na borda de entrada, truncamento e apresentação.

No web, o prefill textual troca vírgula por ponto em `extrairDadosDoTexto` (`/Users/luizprazeres/laudousg/components/FmfTrisomyCalculatorPanel.tsx:56-62`), mas o envio manual para a API usa `parseFloat` direto (`/Users/luizprazeres/laudousg/components/FmfTrisomyCalculatorPanel.tsx:194-206`). Isso é perigoso em PT-BR: `parseFloat("1,8")` vira `1`, não `1.8`. Para TN, isso muda risco de forma visível e ainda pode passar pela API, porque `1` está dentro do range aceito de TN. Swift tende a usar `Double(s.replacingOccurrences(of: ",", with: "."))`, como já acontece na PE (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Components/Sheets/PreEclampsiaCalculatorSheet.swift:123-124`), então Swift e web podem divergir justamente quando o médico digitar o formato brasileiro correto.

Outro ponto: a API web só valida `typeof === "number"` para idade, CCN e TN (`/Users/luizprazeres/laudousg/app/api/fmf-trisomy-risk/route.ts:31-35`) e ranges básicos (`:37-55`). Não há `Number.isFinite`. Se o cliente mandar JSON inválido ou `null` para opcionais, parte dos marcadores some silenciosamente; se mandar número mal interpretado, o cálculo segue.

O rounding de `1/N` também pode gerar diferença de output mesmo com probabilidade quase idêntica. O web usa `Math.round(1 / safeProp)` (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:396-401`) e mostra `1/${ratio.toLocaleString('pt-BR')}` (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomyFormatter.ts:3-5`). Se Swift usar arredondamento bancário, floor/ceil, casas significativas ou formatador local diferente, o relatório pode mudar de `1/249` para `1/250` ou cruzar categoria perto de cutoff.

O clamping precisa ser idêntico e documentado por marcador. O web define `LR_MIN = 0.0001` e `LR_MAX = 10000` (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomyParams.ts:127-128`), aplica em bioquímica (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:249-252`) e DV (`:274-280`), mas não aplica explicitamente em NT, tricúspide e osso nasal (`:119-160`, `:291-305`, `:310-339`). Se no port Swift alguém “padronizar” clamp em todos os LRs, vai alterar risco. Se alguém esquecer clamp em bioquímica/DV, valores extremos também divergem.

## D2.2 — Edge cases clínicos que precisam bloquear ou avisar

O web bloqueia idade materna 15–50, CCN 45–84 mm, TN 0,5–10 mm e FCF 80–220 bpm na rota (`/Users/luizprazeres/laudousg/app/api/fmf-trisomy-risk/route.ts:37-55`). Ele não valida MoM extremo antes do cálculo; bioquímica é truncada internamente em 0,1–10 para free β-hCG e 0,1–2 para PAPP-A (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:190-204`). Isso é matematicamente estável, mas clinicamente perigoso sem aviso: o médico pode digitar PAPP-A `20` e o cálculo usar `2` sem o relatório deixar claro que houve truncamento.

Ducto venoso, tricúspide e osso nasal são opcionais no web. Se ausentes, simplesmente não entram no cálculo (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:441-473`) e só aparecem em `markersUsed`. Isso é aceitável como “cálculo com marcadores disponíveis”, mas não como relatório FMF completo sem deixar explícito “marcador não informado/não utilizado”. Para relatório assinável, ausência precisa aparecer em tabela, não ficar implícita.

IG fora de 11–13+6 deve ser bloqueada pelo CCN, não por IG manual, porque o web deriva IG por Robinson-Fleming a partir de CCN (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:21-24`, `:405-409`). Isso evita inconsistência, mas cria outra: se o relatório pedir DUM/IG manual e ela discordar do CCN, precisa aviso de discordância, não misturar dados.

No Swift, se seguir o padrão atual das calculadoras, campos inválidos apenas fazem `result` virar `nil` e a UI deixa de mostrar resultado. Para trissomias isso é fraco. O usuário precisa saber exatamente “TN fora de range”, “MoM truncado”, “CCN incompatível”, “marcador ausente”, porque o impacto é clínico.

## D2.3 — Responsabilidade clínica/legal e lojas

Aqui eu seria conservador. Um relatório com risco numérico `1/N`, aparência FMF e opção de PDF assinável aproxima o app de suporte à decisão clínica. A Apple diz nas App Review Guidelines que apps médicos usados para diagnosticar/tratar ou que possam fornecer dados imprecisos passam por escrutínio maior, e a Apple também tem fluxo de declaração de app/dispositivo médico regulado em App Store Connect. Fontes oficiais: `https://developer.apple.com/app-store/review/guidelines/` e `https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status/`.

No Google Play, a política de Health Content and Services exige disclaimer claro para apps médicos que não são dispositivo médico, incluindo que o app não diagnostica, trata, cura ou previne condição médica. Fonte oficial: `https://support.google.com/googleplay/android-developer/answer/16679511`.

Blindagem mínima: o relatório deve dizer que é cálculo de apoio/documentação, baseado nos dados inseridos pelo médico, que não substitui julgamento clínico, aconselhamento genético, teste diagnóstico ou protocolo institucional. Deve registrar versão do algoritmo, versão dos parâmetros, data/hora, marcadores usados e ausentes, truncamentos aplicados e responsável pelo exame. Eu evitaria texto “padrão FMF” se não houver paridade documentada com a calculadora oficial; melhor “baseado em modelo FMF/publicações FMF” até validação externa.

## D2.4 — Manutenção/drift dos 47 CSVs

Duplicar CSV entre web e Swift sem pipeline é receita para drift invisível. O repo web tem parâmetros e modelos extraídos em `fmf-research/r-models`, incluindo arquivos de risco, NT, DV, osso nasal, marcadores e gráficos (`/Users/luizprazeres/laudousg/fmf-research/r-models/maternal_age_lookup.csv`, `.../NT_parameters_trisomies_param_nt_mix.csv`, `.../DVPI_parameters_trisomies_param_dvpi_mix.csv`, `.../marker_lookups.csv`). O algoritmo TS consome constantes já convertidas em `fmfTrisomyParams.ts`, mas o Swift ainda não tem equivalente.

Plano seguro: tratar `fmf-research/r-models` ou um pacote canônico derivado dele como fonte única versionada; gerar simultaneamente `fmfTrisomyParams.ts` e `FmfTrisomyParams.swift` a partir dessa fonte; gravar um `modelVersion`/hash no app e no relatório. Se o Swift carregar CSV/JSON no bundle manualmente, ainda precisa teste que compare hash e golden vectors contra web. Se embutir structs Swift geradas, precisa o mesmo gerador. O que não pode é alguém editar Swift à mão seis meses depois.

## D2.5 — PE + RCF no relatório

PE não está pronta para “risco FMF completo” no Swift. O próprio arquivo diz que é triagem simplificada e que a versão completa requer PAPP-A e PlGF (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Services/PreEclampsiaCalculator.swift:3-8`). A função retorna categoria por pontuação, não `1/N` (`:43-48`, `:102-130`). A tela também apresenta isso como “FMF simplificado — sem PAPP-A/PlGF” (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Components/Sheets/PreEclampsiaCalculatorSheet.swift:29-33`). Portanto, não deve ser misturada no mesmo relatório como se fosse o relatório FMF completo.

A auditoria citava cutoff fixo antigo, mas o código atual já usa referência variável de IP médio das uterinas (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Services/PreEclampsiaCalculator.swift:50-61`, `:89-100`). Mesmo assim, continua sendo escore simplificado, sem PlGF/PAPP-A e sem risco numérico.

RCF também não é o mesmo problema. O web tem uma calculadora RCF/PIG, mas ela é estadiamento de crescimento fetal já alterado por percentil e Doppler (`/Users/luizprazeres/laudousg/lib/rcfCalculator.ts:1-10`, `:42-183`). Isso não equivale a risco preditivo de restrição de crescimento no relatório do 1º trimestre. Existe material FMF de crescimento nos modelos (`/Users/luizprazeres/laudousg/fmf-research/r-models/growth_charts_fmf.efw.zscore.R` e CSVs de crescimento), mas isso é curva/percentil/z-score, não necessariamente risco PE/RCF de 1º tri. Se o plano prometer RCF no relatório v1 sem modelo validado específico, vai inventar clínica.

## D2.6 — Gráficos

Concordo que gráficos devem ser P1, não P0, se P0 significar “mínimo confiável”. Um gráfico errado parece mais autoritativo que texto errado. O repo tem funções R de referência para curva de risco (`/Users/luizprazeres/laudousg/fmf-research/r-models/risk_profile_plot.R:1-14`, `:40-60`, `:95-98`), CCC (`/Users/luizprazeres/laudousg/fmf-research/r-models/crl_plot.R:1-30`) e TN (`/Users/luizprazeres/laudousg/fmf-research/r-models/nt_plot.R:20-23`, `:103-118`). Isso ajuda, mas não significa que já exista uma implementação Swift validada.

No app Swift, não encontrei uso de Swift Charts com `rg "import Charts|Swift Charts|Charts"`. O PDF rico existente é o exportador de miomas, que renderiza uma View em imagem e coloca no PDF via `UIGraphicsPDFRenderer` (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Miomas/MyomaSchemaExporter.swift:69-107`). Dá para reaproveitar o padrão técnico, mas os gráficos médicos precisam antes de testes de pixel/dados: pontos esperados, eixos, escala log no risco, ranges e legendas. Sem isso, o relatório fica bonito e clinicamente enganoso.

## Sequência de fases recomendada

Fase 0 deve ser um contrato clínico fechado, antes de UI: definir exatamente quais entradas são aceitas, quais marcadores são opcionais, ranges, truncamentos, mensagens de aviso, texto legal, versionamento do modelo e formato do bloco de laudo. Também precisa decidir se P0 é “trissomias combinadas” ou “relatório completo 1º tri”. Minha recomendação adversarial: P0 realista é trissomias T21/T18/T13 + bloco de texto + PDF tabular simples, sem PE/RCF como risco numérico e sem gráficos.

Fase 1 deve portar o algoritmo de trissomias para Swift com fonte única de parâmetros e golden vectors gerados do TS. O critério de aceite não é “compila”; é comparar risco basal, risco corrigido, `1/N`, categoria e marcadores usados em casos normais, extremos e inputs parciais. Qualquer diferença perto de cutoff deve bloquear release.

Fase 2 deve entregar PDF tabular assinado/compartilhável para trissomias, com disclaimers, versão do modelo, dados da paciente, entradas, marcadores usados/ausentes, avisos de truncamento e riscos basal/corrigido. Esse PDF pode usar o padrão técnico do exportador de miomas, mas sem gráficos até os dados estarem validados.

Fase 3 deve adicionar gráficos de CCC, TN e risco, somente depois de portar as funções R/CSV correspondentes e validar pontos/eixos contra fixtures. Se entrar antes, aumenta risco clínico sem aumentar confiabilidade do cálculo.

Fase 4 deve tratar PE e RCF como módulos separados. PE só entra como “FMF completo” se houver modelo com PlGF/PAPP-A, fatores maternos, MAP, uterinas e risco numérico validado. RCF só entra se ficar claro se é predição de 1º trimestre ou estadiamento de crescimento fetal; são produtos diferentes.

Fase 5 deve portar para Android RN apenas depois do Swift estar validado. Melhor ainda: gerar os parâmetros e golden vectors de uma fonte única para web, Swift e RN. Android não deve ser um segundo port manual independente.

## Riscos adicionais que eu bloquearia antes do plano final

O nome “FMF” no produto e no relatório pode sugerir certificação/endosso. Eu evitaria essa impressão se não houver autorização ou validação formal.

O relatório precisa diferenciar “risco basal” de “risco corrigido” com clareza. O web hoje calcula prior internamente e só formata os riscos finais no bloco (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomyFormatter.ts:35-38`); para o relatório completo, o resultado Swift precisa expor basal e corrigido separadamente, não só posterior.

A tela precisa impedir mistura de MoM “já corrigido” com correção manual. O web tem `isMoMCorrected` no tipo (`/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomyTypes.ts:19`) e campo na UI (`/Users/luizprazeres/laudousg/components/FmfTrisomyCalculatorPanel.tsx:200-214`), mas esse estado é fácil de entender errado. No relatório, precisa declarar “MoM informado como corrigido” ou “MoM corrigido pelo app com peso/etnia/tabagismo/IVF/paridade”.

Minha conclusão: não vender “relatório completo FMF com PE + RCF + gráficos” como v1 técnica. O P0 confiável deve ser menor, auditável e testável. Depois disso, expandir.
