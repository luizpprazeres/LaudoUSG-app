# iOS: modo Doppler e dados de imagem

Status: Ready for Review - gate XCTest dirigido APROVADO em iPhone fisico (19/19), em 14/09/2026. Story preparada no papel SM antes da implementacao. Nao implica publicacao ou aprovacao dos demais gates.

## Escopo autorizado

ImageAnalysisService, ImageAnalysisSheet, GenerateViewModel (category/reset), testes dirigidos. Preservar dirty, build 190, IAP, legal, Apple e submissao. Sem alterar Android/backend ou agentes.

## Criterios e tarefas

- [x] Troca efetiva de categoria restaura combinado sem apagar texto, laudo ou dados pendentes. Reset explicito restaura combinado.
- [x] Pedido de imagem combinado usa OBSTETRICA + modules DOPPLER_OBSTETRICO; isolado usa DOPPLER_OBSTETRICO sem extra; obstetrica simples sem extra.
- [x] Dados filtrados antes de texto/companion: isolado so os dez campos IR/IP; obstetrica simples sem esses campos; combinado preserva ambos. Morfologico respeita includeDoppler, como Android.
- [x] Testes de serializacao do builder usado pelo transporte, selecao de dados, formatacao e estado do ViewModel compilados e executados em iPhone fisico.
- [x] Rebuild/testes reais dirigidos em simulador isolado tentados, com bloqueio detalhado abaixo.
- [x] Revisar diff e atualizar file list/resultados.
- [x] Obter execucao aprovada das 19 funcoes de teste selecionadas: 19 passed, 0 failed, 0 skipped.

## Fontes

AGENTS.md, CLAUDE.md, docs/ARCHITECTURE.md, docs/DESIGN_SYSTEM.md. Contrato Android verificado em laudousgmobile-def/apps/mobile/src/features/imaging/imageAnalysis.ts (imagingRequestFields/selectImagingData). Pedido explicito do usuario nesta tarefa. SwiftUI usa ViewModel @MainActor; servico de imagem retorna BiometricData consumido pela tela e companion.

## File List

LaudoUSG/Services/ImageAnalysisService.swift
LaudoUSG/Components/Sheets/ImageAnalysisSheet.swift
LaudoUSG/Features/Generate/GenerateViewModel.swift
LaudoUSGTests/ImageAnalysisServiceTests.swift
LaudoUSGTests/DopplerModeIsolationTests.swift
docs/stories/2026-09-14-ios-doppler-mode-images.md

## Fechamento coordenador - 14/09/2026

Implementado sobre dirty, sem revert: troca efetiva de categoria reseta somente o toggle; dados ja inseridos no rascunho nao sao reescritos. Resposta de imagem filtrada no servico antes de onExtract/companion e na formatacao. Contratos Android preservados. Sete testes novos + doze existentes selecionados, sem remover assercoes.

**Compilacao atual PASSOU (exit 0)**, incluindo pacote XCTest; nao e resultado antigo:

`xcodebuild build-for-testing -project LaudoUSG.xcodeproj -scheme LaudoUSG -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/laudousg-doppler-fix-20260914 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES -quiet`

**Execucao XCTest BLOQUEADA**. Tentativa real com codigo atual, apenas tres suites:

`xcodebuild test -project LaudoUSG.xcodeproj -scheme LaudoUSG -destination 'platform=iOS Simulator,id=1F5932BB-B524-4B98-83CA-BA9FB194F579' -derivedDataPath /tmp/laudousg-doppler-fix-20260914 -resultBundlePath /tmp/laudousg-doppler-fix-20260914.xcresult -only-testing:LaudoUSGTests/DopplerModeIsolationTests -only-testing:LaudoUSGTests/ImageAnalysisServiceTests -only-testing:LaudoUSGTests/ObstetricGenerationContractTests -parallel-testing-enabled NO -quiet`

Simulador exclusivo iPhone 17 Pro Max/iOS 26.4. Interrompido apos aproximadamente cinco minutos totais, sem abertura do app. Diagnosticos: `waiting for workers to materialize`, NSMachErrorDomain -308 `server died`, SimError 405 `Invalid device state`. TEST INTERRUPTED, exit 73; xcresult parcial/invalido (action log nao finalizou). ZERO testes confirmados como executados. Nao declarar gate iOS verde.

Processos desta tarefa encerrados; consulta final confirmou nenhum xcodebuild com este DerivedData pendente. Simulador exclusivo removido. Nenhum processo/dispositivo de outro agente encerrado; sem restart global. Retomada: simulador saudavel, mesmas tres suites, novo resultBundlePath, reutilizando a compilacao atual.

`git diff --check` passou. Build 190, IAP, legal e submissao preservados; sem archive/upload ou servico clinico remoto. Gates API/Android/web simulados aprovados conforme coordenador, nao reexecutados aqui e nao substituem XCTest iOS.

## Retomada limitada - 14/09/2026, 09:06 America/Maceio

Status continua BLOQUEADO, zero XCTest executado nesta retomada. Sem nova compilacao nem mudanca de codigo. Binarios atuais conferidos por mtime posterior aos fontes/testes alterados; disco com 128 GiB livres. Nenhum xcodebuild pendente na entrada.

Alternativa fundamentada: separar boot do XCTest em simulador exclusivo novo (B1E18378-87EB-4705-98CE-5CB855F5263A), com `perl -e 'alarm 60; exec @ARGV' xcrun simctl bootstatus <id> -b`. Boot parou em `Status=1 / Waiting on BackBoard` e atingiu o timeout real (exit 142). Nao repetido o ciclo de cinco minutos de xcodebuild: o bloqueio antecede instalacao/launch do app. Causa interna do BackBoard nao confirmada; sem restart global ou interferencia em outros agentes.

Alternativa fisica verificada por devicectl com timeout: iPhone 15 Pro Max disponivel/pareado via rede, iOS 26.6.1, modo desenvolvedor ativo e DDI disponivel. LockState retornou `passcodeRequired: true`. Nenhuma instalacao/launch no aparelho: preservar app 190 instalado. Para usar XCTest nesse alvo sera necessario desbloqueio e definir instalacao de teste que nao substitua o app 190; nao basta estar pareado.

Limpeza concluida: shutdown e delete do simulador exclusivo com exit 0; consulta final sem xcodebuild/simctl proprios pendentes. Nenhum processo de outro agente encerrado. `git diff --check` passou.

Pendencia: simulador com boot concluido ou alternativa fisica desbloqueada e isolada, seguida das mesmas tres suites. Nenhum resultado antigo foi apresentado como nova execucao.

## Tentativa autorizada - 14/09/2026, 10:09 America/Maceio

Gate continua BLOQUEADO. Simulador exclusivo criado: `930036EA-8A4F-4BED-B499-9C378C37DB39` (LaudoUSG Doppler Gate Exclusive, iPhone 17 Pro Max/iOS 26.4). `perl -e 'alarm 60; exec @ARGV' xcrun simctl bootstatus <id> -b` ficou em `Status=1 / Waiting on BackBoard` e encerrou por timeout de 60 s, exit 142. XCTest NAO iniciado, zero funcoes executadas; as 19 continuam pendentes. Arquivo xctestrun compilado confirmado disponivel, sem recompilacao.

Shutdown e delete apenas desse simulador: ambos exit 0. Consulta final sem processos proprios pendentes. Intervalo de tentativa/limpeza 13:09:06-13:10:31 UTC, abaixo do limite total de cinco minutos. Little Lighthouse Store, iPhone e processos alheios intocados. Nenhuma alteracao de codigo, build190, App Store ou FMF/imagens; somente esta story atualizada.

## Gate fisico APROVADO - 14/09/2026, 10:43 America/Maceio

Execucao real em iPhone 15 Pro Max, iOS 26.6.1, arm64e. Resultado novo: `/tmp/laudousg-doppler-device-gate/device-tests.xcresult`. `xcresulttool get test-results summary` confirmou Passed, totalTestCount=19, passedTests=19, failedTests=0, skippedTests=0. Arvore de testes conferida individualmente: DopplerModeIsolationTests 7/7; ImageAnalysisServiceTests 6/6; ObstetricGenerationContractTests 6/6. Runner em cerca de 11 s, comando exit 0. Nao e build-only nem resultado antigo.

Isolamento verificado ANTES de instalar: app `com.laudousg.dopplergate.LaudoUSG`, pacote `com.laudousg.dopplergate.LaudoUSGTests`; xctestrun aponta somente para esse host. Assinatura de desenvolvimento valida, perfil wildcard local existente inclui o aparelho. Entitlements do app: application-identifier proprio, team e get-task-allow; sem App Groups ou keychain-access-groups compartilhados. Info.plist temporario sem CFBundleURLTypes para nao registrar `laudousg://`. `codesign --verify --deep --strict` passou. Nenhum acesso/migracao de dados do app original; app190 nao substituido/aberto. LockState revalidado false antes da execucao.

Overrides somente de processo: `PRODUCT_BUNDLE_IDENTIFIER=com.laudousg.dopplergate.$(PRODUCT_NAME:rfc1034identifier)`, `INFOPLIST_FILE=/tmp/laudousg-doppler-device-gate/Isolated-Info.plist`, display name de testes, `CODE_SIGN_STYLE=Automatic`, `CODE_SIGN_IDENTITY=Apple Development`, `PROVISIONING_PROFILE_SPECIFIER=`. Sem allowProvisioningUpdates, cadastro Apple, alteracao de projeto ou signing persistente. Tentativa manual anterior foi recusada por perfil gerenciado pelo Xcode; automatico local resolveu. Build isolado seguido de build-for-testing concluiu com exit 0; limites de 180/120 s com encerramento apenas do grupo de processos proprio.

Comando de execucao, limitado a 120 s (+20 s de limpeza em caso de timeout):

`xcodebuild test-without-building -xctestrun /tmp/laudousg-doppler-device-gate/DerivedData/Build/Products/LaudoUSG_iphoneos26.4-arm64.xctestrun -destination 'platform=iOS,id=00008130-0006156A3C3A001C' -destination-timeout 15 -resultBundlePath /tmp/laudousg-doppler-device-gate/device-tests.xcresult -only-testing:LaudoUSGTests/DopplerModeIsolationTests -only-testing:LaudoUSGTests/ImageAnalysisServiceTests -only-testing:LaudoUSGTests/ObstetricGenerationContractTests -parallel-testing-enabled NO -quiet`

Limpeza: `devicectl device uninstall app ... com.laudousg.dopplergate.LaudoUSG --timeout 20` confirmou App uninstalled (exit 0). Nenhum xcodebuild/wrapper proprio pendente. Nenhum simulador usado nesta rodada. Somente esta story alterada no repositorio; codigo dirty, build190, IAP, legal, App Store e processos/apps alheios preservados. Este gate valida contratos/dados/estado nos testes selecionados, nao a extracao LLM remota ou publicacao.
