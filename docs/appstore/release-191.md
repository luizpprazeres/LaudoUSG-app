# Preparação TestFlight — 1.0 (191)

Preparação autorizada por Luiz em 29/09/2026. **Sem upload ou distribuição neste registro inicial.** Build191 é provisório até confirmar no App Store Connect o último número usado; documentação local registra190 como enviado, mas não substitui consulta atual.

Fonte do aplicativo: main `c83f6169e0f2ed65755dca8d60089188a1eb662e`. Working change de ImageAnalysisServiceTests feito pelo root ajusta testes ao contrato de IR/IP estabelecido no baseline dc10b70, sem mudar código do app. O release leva revisão médica vinculada a versão/texto, ação explícita na geração/detalhe e instruções do domínio brasileiro da Sala.

Signing automático, bundle `com.laudousg.LaudoUSG`, team `W772N4FGJ6`; identidade Apple Development válida observada no Keychain, sem leitura de material privado. Nenhuma identidade Apple Distribution local foi listada antes da preparação. Credenciais oficiais existentes do Xcode são o único caminho permitido para export; não copiar caches/tokens.

Archive tentou compilar com destino generic iOS, configuração Release, DerivedData isolado `/tmp/laudousg-testflight-191-derived`, destino `/tmp/LaudoUSG-191.xcarchive` e override `CURRENT_PROJECT_VERSION=191`. O número no projeto permanece190 durante essa preparação. `-allowProvisioningUpdates` autoriza o fluxo padrão de assinatura; não realiza upload por si só.

Suíte completa em execução no simulador dedicado `FFC26EBF-DE61-41E2-A0EE-19930281CA7A` (LaudoUSG-TestFlight-FullQA-20260929), iOS26.5, sem usar o simulador de E2E. Resultado esperado em `/tmp/laudousg-testflight-fullqa-20260929.xcresult`, log `/tmp/laudousg-testflight-fullqa.log`. Os seis testes específicos de revisão/consentimento já haviam passado; resultado da suíte atual deve ser registrado quando terminar.

Gates ainda pendentes neste ponto: archive/export concluídos e inspecionados, suíte completa, confirmação do número ASC, E2E iOS autenticado com edição invalidando aprovação e nova revisão, autorização final do root antes de upload. Não submeter versão à App Store nem mudar distribuição externa/grupos automaticamente.

## Resultado inicial do archive

Compilação Release concluída, mas o archive encerrou com exit 65 na etapa CodeSign: `errSecInternalComponent`. A identidade Apple Development foi encontrada, porém a assinatura não pôde ser concluída. Não foi produzido archive distribuível e nenhum export/upload foi executado. Log: `/tmp/laudousg-testflight-191-archive.log`. É necessário resolver pelo fluxo normal do Keychain/Xcode antes de repetir incrementalmente; nenhum certificado ou chave foi exportado e nenhuma configuração de segurança foi alterada.

## Gate completo de testes

Rodada inicial interrompida porque CoreSimulator não iniciou o host de testes. Somente o simulador dedicado foi reiniciado; nenhum serviço global ou simulador de E2E foi alterado. Retry incremental terminou com exit 0 e `TEST SUCCEEDED`: 97 testes, 94 passaram, 3 ignorados e zero falhas, confirmados por `xcresulttool get test-results summary`. Resultado: `/tmp/laudousg-testflight-fullqa-retry-20260929.xcresult`; log: `/tmp/laudousg-testflight-fullqa-retry.log`. As duas expectativas obsoletas de IR foram alinhadas ao contrato de produção já existente no baseline dc10b70. Nenhum código de produção mudou neste ajuste.

CodeRabbit NÃO EXECUTADO. E2E autenticado está sob validação independente do root; este registro não substitui seu aceite.

## Publicação final — build 209

O App Store Connect confirmou que o build 208 já havia sido produzido pelo Xcode Cloud a partir do commit `c4dac67` (ajuste das expectativas de Doppler). Para manter esta publicação rastreável e evitar ambiguidade com o processo paralelo, o root gerou o build 209 a partir da mesma `main`, sem mudar o código do aplicativo.

Archive Release assinado com sucesso em `/tmp/LaudoUSG-209.xcarchive`, versão `1.0 (209)`, bundle `com.laudousg.LaudoUSG`, team `W772N4FGJ6`, arm64. Exportação local para `/tmp/LaudoUSG-209-export` passou. O upload oficial via Xcode terminou com `Upload succeeded` em 29/09/2026 às 13:05 (horário local), e o App Store Connect mostrou `1.0 (209)` em processamento.

O processamento terminou no App Store Connect. O build 209 está associado ao grupo interno `Beta Médicos`, com um tester, e a tela do build permite expirá-lo, confirmando que ele está disponível no TestFlight interno. As notas de teste foram salvas com o roteiro sintético de criação, revisão explícita, envio para a Sala e invalidação da revisão após edição. Nenhuma distribuição externa nem submissão à revisão pública da App Store foi realizada.

Antes do upload, o E2E sintético iOS → Sala canônica comprovou: chegada pendente, revisão médica explícita, invalidação após edição, nova revisão, nome local excluído da cópia, acréscimo da auxiliar separado, seleção preservada entre dois laudos e redirecionamento autenticado do domínio antigo. Nenhum dado de paciente foi usado. A suíte completa permaneceu em 94 testes aprovados, 3 ignorados e zero falhas.
