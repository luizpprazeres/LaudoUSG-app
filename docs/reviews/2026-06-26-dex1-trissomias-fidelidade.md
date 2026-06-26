DEX1 — FIDELIDADE / CORREÇÃO DO PORT

D1.1 Estratégia de port TS→Swift

Recomendação: transcrever 1:1 o núcleo matemático do TypeScript para Swift, mantendo a mesma decomposição mental do web: helper de clamp/PDF normal, CRL→GA, prior, LR de TN, LR bioquímica/FCF, LR ducto venoso, LR tricúspide, LR osso nasal, correção de MoM e posterior Bayesiano. Evitaria “portar fórmula-a-fórmula” reinterpretando o paper, porque o risco real aqui não é entender a medicina; é mudar sem querer detalhes pequenos que mudam o número final.

O maior risco de divergência mora nos detalhes numéricos do web:

- `log10`, não `ln`: prior usa `Math.log10(ga / 7)` em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:97`; TN usa `Math.log10(nt)` em `:121`; bioquímica usa `Math.log10` após clamp em `:192` e `:203`; osso nasal usa `Math.log10(pappaMoM ?? 1)` e `Math.log10(fbhcgMoM ?? 1)` em `:317-318`.
- Arredondamento de CRL para 0,1 mm antes dos mapas de truncamento: `const crlR = Math.round(crl * 10) / 10` em `:122` e `:261`, depois `tlKey = Math.round(crlR * 10)` em `:141` e `:272`. Se Swift usar outro arredondamento ou Double cru como chave, muda LR.
- Truncations/clamps: TN troca a likelihood quando `nt < truncLimit` em `:147-152`; bioquímica clampa MoM em `:192` e `:203`; FCF clampa delta em `:214`; ducto usa `Math.max(dvpi, trunc)` em `:276`; LR bioquímica é clampado em `[1e-4, 1e4]` em `:249-252` com constantes em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomyParams.ts:126-128`.
- Operador de potência e matriz normal multivariada: o web implementa `dmvnorm` manual para 1D/2D/3D em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:31-70`, com determinante e inversa explícitos. Esse trecho deve ser copiado conceitualmente, não substituído por biblioteca sem golden test.
- Um detalhe especialmente perigoso: `meanCoeffFn` usa `m.b0 + m.b1 * gaDiff + m.b2 * gaDiff * 2` em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:186-188`, e o spec do repo repete que é “×2 not ×(ga-77)²” em `/Users/luizprazeres/laudousg/fmf-research/FMF-ALGORITHM-SPEC.md:220-222`. Parece estranho, mas para fidelidade ao web deve ser preservado até validação externa provar o contrário.

Também precisa ficar claro que o app Swift atual não tem essa calculadora. O padrão de calculadoras é `Result` com `insertBloco`; por exemplo PE retorna `insertBloco` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Services/PreEclampsiaCalculator.swift:43-48` e insere no laudo em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Components/Sheets/PreEclampsiaCalculatorSheet.swift:108-112`. A tela principal atual ainda só lista IG/Doppler em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Components/Sheets/CalculatorsSheet.swift:17-49`, então trissomias entraria como nova calculadora, não ajuste de uma existente.

D1.2 CSVs + constantes

Para reduzir drift web↔Swift, eu usaria os dados extraídos como recursos versionados em formato estruturado no bundle, preferencialmente JSON gerado a partir dos CSVs/R extraídos, e não “reescrever tudo à mão” como structs Swift permanentes.

Motivo: o web hoje já tem constantes hardcoded em TS, como `NT_MIX` em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomyParams.ts:5-25`, `DVPI_MIX` em `:27-35`, gaussianas em `:65-109` e mapas enormes de truncamento em `:130-137`. Ao duplicar isso em Swift como structs manuais, o risco é uma vírgula errada ou atualização futura em um lado só.

O melhor desenho de manutenção seria: manter uma fonte canônica em `fmf-research/r-models` ou uma pasta `shared/fmf-models`, gerar JSON normalizado, e gerar/validar tanto TS quanto Swift a partir desse pacote. No Swift, carregar do bundle evita recompilar código para mudança de tabela e facilita comparar hash/versão do modelo. Se performance ou simplicidade exigir structs Swift, que sejam geradas automaticamente por script a partir da mesma fonte, nunca digitadas manualmente.

O bundle JSON/CSV tem uma desvantagem: parsing e validação no runtime. Isso se resolve carregando uma vez, com schema rígido, falha explícita se faltar chave, e golden tests. Para uma calculadora médica, prefiro um erro visível ao risco de um array Swift hardcoded divergente silenciosamente.

D1.3 Golden tests

Faz total sentido. Eu trataria o TypeScript atual como fonte de verdade inicial do port, com ressalva de que depois ele também precisa ser comparado contra FMF oficial. O golden test deve cobrir não só inputs “bonitos”, mas combinações que exercitam cada LR opcional: só idade+TN, com bioquímica, com FCF, com ducto, com tricúspide presente/ausente, com osso nasal presente/ausente, etnias, tabagismo, IVF, nuliparidade, antecedentes e bordas de CRL/TN.

Tolerância: eu usaria algo como erro relativo < 0,1% para `probability` e igualdade exata para categorias/markers/ranges, mas também testaria `ratio` com tolerância de arredondamento de 1 unidade quando o denominador estiver perto de uma fronteira. O web arredonda `ratio` com `Math.round(1 / safeProp)` em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:396-402`, então comparação rígida do `1/N` pode falhar por diferença minúscula de Double sem relevância clínica.

Onde colocar o harness: no web, um script Node/TS em `/Users/luizprazeres/laudousg` que gere `fixtures/fmf-trisomy-golden.json` a partir de `calcularTrissomias`; no Swift, testes unitários do target do app lendo esse JSON como fixture. No futuro Android RN, o mesmo JSON vira contrato de paridade. O app Swift ainda não tem esse núcleo, mas já usa serviços puros em `Services/*Calculator.swift`, então a calculadora deve nascer como serviço puro testável antes de UI/PDF.

D1.4 Fidelidade do laudousg web à FMF oficial

Pelo repo, eu classificaria o web como reimplementação baseada em extração do app/calculadora FMF, não como chamada oficial nem prova final de paridade.

Evidência a favor: o spec diz que o algoritmo foi extraído de `fmf.refractionx.com` via R/WebR e validado contra papers em `/Users/luizprazeres/laudousg/fmf-research/FMF-ALGORITHM-SPEC.md:1-5`; o diretório tem requests reais para `fetalmedicine.org/research/assess/trisomies` e embed `fmf.refractionx.com/calculators?...id=trisomies` em `/Users/luizprazeres/laudousg/fmf-research/relevant-requests.json:4-84`; há R extraído para prior/curvas/modelos, por exemplo Robinson-Fleming em `/Users/luizprazeres/laudousg/fmf-research/r-models/robinson_fleming_GA.R:1-12` e modelos/gráficos em `fmf-research/r-models`.

Evidência contra uma afirmação forte de “paridade oficial”: não encontrei teste automatizado específico de `calcularTrissomias` no repo; a busca por `calcularTrissomias`, `fmf-trisomy-risk`, `golden` e `expect(` só mostrou o endpoint/UI e golden dataset de laudos, não golden vetores FMF. A UI web chama o endpoint em `/Users/luizprazeres/laudousg/components/FmfTrisomyCalculatorPanel.tsx:216-220`, e o endpoint valida ranges básicos em `/Users/luizprazeres/laudousg/app/api/fmf-trisomy-risk/route.ts:31-59`, mas isso não prova que os outputs batem com fetalmedicine.org.

Como confirmar de verdade: gerar 30-100 casos no web, preencher os mesmos casos na calculadora FMF oficial/RefractionX quando acessível, salvar resposta visual/numérica e comparar T21/T18/T13. Se a calculadora oficial não expõe API estável, usar Playwright/browser automation com snapshots e registrar os resultados como fixture. Sem isso, a frase correta é: “port fiel ao web atual, que é uma reimplementação derivada de material FMF/R extraído”.

D1.5 Gráficos CCC×IG, TN×CCC e curva de risco

Existem bases reais no repo para não inventar as curvas principais, mas elas precisam ser isoladas e validadas antes de virar PDF.

CCC×IG: existe `crl_plot.R`, que usa `robinson.fleming` e plota CRL por GA, incluindo linhas deslocadas e faixa 45-84 mm em `/Users/luizprazeres/laudousg/fmf-research/r-models/crl_plot.R:1-31`. A fórmula base está em `/Users/luizprazeres/laudousg/fmf-research/r-models/robinson_fleming_GA.R:1-12` e já é igual à função web `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:21-24`.

TN×CCC: existe `nt_plot.R` com mediana/modelo FMF: coeficientes `b0/b1/b2` em `/Users/luizprazeres/laudousg/fmf-research/r-models/nt_plot.R:42-48`, truncamento por CRL em `:55-58`, linha central `10^(b0 + b1*crl + b2*crl^2)` em `:103-108`, faixa interquartil a partir de `nt.q` em `:117-123`, e função percentil `nt.perc4` em `:136-170`.

Curva de risco T21: existe `risk_profile_plot.R`, que usa `maternal_age_lookup.csv` e plota `log10(lu$risk)` por idade materna em `/Users/luizprazeres/laudousg/fmf-research/r-models/risk_profile_plot.R:1-14`, marca idade/posterior em `:18-60`, e lê `maternal_age_lookup.csv` em `:95-98`. O CSV contém riscos por idade para T21/T18/T13 em `/Users/luizprazeres/laudousg/fmf-research/r-models/maternal_age_lookup.csv:1-20`.

Então eu não diria “gráfico é impossível na v1”. Eu diria: gráfico é aceitável na v1 só se for portado dessas funções/tabelas e coberto por teste visual/numerico simples. O risco é inventar percentil/curva por estética. Para PDF clínico, curva sem fonte validada é pior do que não ter curva.

Sequência de fases recomendada

P0 mínimo confiável: portar o núcleo de trissomias para Swift como serviço puro, 1:1 com o TypeScript; carregar parâmetros de fonte canônica versionada; criar golden tests TS→Swift antes de UI; reproduzir o bloco de texto PT do web (`formatarBlocoTrissomias`) como primeiro output, porque hoje o contrato das calculadoras Swift é inserir texto no laudo. Só depois registrar a sheet no app.

P0.5 de fidelidade clínica: comparar o web atual contra a calculadora FMF oficial/RefractionX em um conjunto pequeno, mas representativo. Se houver divergência, corrigir primeiro o web/canônico, não o Swift isoladamente. Também documentar claramente que o cálculo retorna rastreio, não diagnóstico.

P1 PDF tabular: gerar relatório completo em PDF sem gráficos primeiro, com dados da paciente, características maternas, marcadores, risco basal e corrigido T21/T18/T13, e seção separada para PE/RCF marcada conforme qualidade do modelo disponível. Para PDF, o Swift já tem padrão viável com `ImageRenderer` + `UIGraphicsPDFRenderer` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Miomas/MyomaSchemaExporter.swift:69-107`.

P1 gráficos validados: adicionar CCC×IG, TN×CCC e risco T21 usando somente `crl_plot.R`, `nt_plot.R`, `risk_profile_plot.R` e CSVs equivalentes como fonte. Não encontrei uso atual de Swift Charts (`import Charts`, `Chart`, `LineMark`) no app Swift, então há duas opções seguras: desenhar com SwiftUI/CoreGraphics dentro do PDF ou introduzir Swift Charts com testes visuais. Para fidelidade clínica, eu escolheria primeiro geração determinística própria para PDF, com pontos/linhas simples.

P2 PE + RCF completos: não misturar o PE simplificado atual como se fosse risco FMF completo. O próprio Swift diz que a versão completa requer PAPP-A e PlGF em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Services/PreEclampsiaCalculator.swift:3-8` e reforça que é categórica/simplificada em `:63-65` e no texto de observação em `:125-128`. PE/RCF devem entrar no relatório completo só quando houver modelo validado, fonte e golden tests próprios.

Risco adicional não listado: o campo `isMoMCorrected` existe no tipo web em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomyTypes.ts:19`, e há função `correctMoM` em `/Users/luizprazeres/laudousg/lib/calculators/fmfTrisomy.ts:344-380`, mas o cálculo principal usa diretamente `input.freeBetaHcgMoM` e `input.pappaMoM` em `:430-432`. Se o produto prometer “MoM corrigido automaticamente” no Swift/PDF, isso precisa ser resolvido como decisão explícita, porque o web atual parece tratar os MoMs como já corrigidos apesar de ter a função de correção disponível.
