# Preparacao da versao 1.0, build 189

Status: build 189 enviado a Apple; ainda NAO submetido a revisao e NAO aprovado.
Substituido na preparacao pelo build 190; estado atual em release-190.md.
O App Store Connect ja tem builds 186 e 188 internos; o novo upload deve usar 189.

## Pendencias verificadas

Em 13/09 apos desbloqueio, criado certificado Apple Distribution na equipe
W772N4FGJ6, sem revogar certificados existentes. Archive 189 concluiu. Exportacao
CLI falhou (No Accounts/perfil antigo), mas o Organizer do Xcode assinou,
validou com sucesso e confirmou "LaudoUSG 1.0 (189) uploaded". Metodo escolhido:
App Store Connect, nao TestFlight Internal Only. Processamento concluido:
TestFlight mostra 189 como "Pronta para envio", sem a restricao Internos.
Associacao do build a versao ainda precisa de confirmacao do salvamento.

Envio antigo 520d72d9-9bd2-4550-bd9d-b81e08d7301f cancelado para liberar a edicao.
Descricao pt-BR e notas atualizadas na loja e relidas apos salvar (botao Salvar
desabilitado). Removida a associacao antiga 147 e selecionado 189; interface
ainda processando a confirmacao. Nao clicar Adicionar para revisao antes dos
gates pendentes, associacao dos quatro produtos e verificacao final.

Login da conta de demonstracao funcionou no simulador com build 189. Exibiu
Termos 2.0, Privacidade 2.1 e Disclaimer 2.0. Aceite nao efetuado: solicitada
autorizacao de Luiz no momento da acao. Nao alterar o aceite pelo banco nem
apagar a conta existente. Simulador proprio desligado enquanto aguarda.

Suite XCTest executada no simulador: 76 passaram, zero falharam e 3 ignorados
por curadoria pendente da tabela WHO (testSmallWHO/testNormalWHO/testLargeWHO).
Resultado: /tmp/laudousg-tests-189-unlocked. Nao e teste de compra sandbox real.

A API corrigida esta publicada e a tabela de assinaturas foi criada com RLS.
Os 105 testes sinteticos de IAP passaram; compra, restauracao e renovacao reais
em sandbox ainda precisam ser validadas. URLs de producao e sandbox foram salvas
e relidas no App Store Connect: https://laudousgmobile.vercel.app/api/iap/notifications.
A interface atual nao exibiu seletor de versao; confirmar o formato V2 com uma
notificacao Apple real antes de considerar a integracao validada ponta a ponta.

Politica nativa atualizada localmente para 2.1: dados de assinatura Apple,
vinculacao por appAccountToken, permissao IA separada e caminho de exclusao.
LegalVersions solicita novo aceite dessa versao. Tutorial de geracao agora
exige permissao IA concedida, em vez de aparecer tambem depois de uma recusa.
Validar isso no aplicativo e conferir todos os caminhos abaixo no build assinado.

Nova compilacao de simulador (arm64 e x86_64) passou apos essas alteracoes,
com CFBundleVersion 189; a politica embutida foi comparada ao arquivo fonte.
Teste isolado do AIConsentPolicy real, com autenticacao simulada, passou em
permissao explicita, isolamento por conta, revogacao e rotas sem IA. Isso nao
substitui a suite XCTest nem validacao da interface no dispositivo.

Pagina publica atualizada para 2.1 e verificada por HTTP em www.laudousg.com/privacy.
Deployment dpl_5G9c9jdhVyGjrw8xqmsP8zWfDiiF, feito de worktree isolada
/tmp/laudousg-privacy-189 a partir do commit de producao 770e44ab196e61c528ff6c8d1db3e0517ed5bbdd.
Somente app/privacy/page.tsx mudou: dados Apple, imagens, Deepgram, permissao IA,
exclusao e remocao de notas internas visiveis; Groq identificado como fluxo web
legado, nao iOS. Lint e typecheck passaram; build remoto passou; verificacoes
Playwright do conteudo e overflow em 390/1440 passaram. npm test nao existe
neste repo. As declaracoes de privacidade da loja ainda precisam ser atualizadas.
Nao houve alteracao para download pago.

## Descricao pt-BR proposta

O LaudoUSG auxilia médicos na elaboração e revisão de laudos de ultrassonografia. Dite ou digite os achados, confira a minuta gerada por inteligência artificial e ajuste o conteúdo antes de finalizar o laudo.

LAUDOS E MEDIDAS

Categorias específicas de ultrassonografia, modelos de laudo, frases personalizadas e edição do resultado. Imagens selecionadas podem ser enviadas para extração de medidas, sempre sujeitas à conferência do médico.

OBSTETRÍCIA E DOPPLER

Exames obstétricos e morfológicos, calculadoras e esquemas. Na categoria Doppler obstétrico, escolha o exame combinado com obstetrícia ou ative Somente Doppler.

SALA DO AUXILIAR

Compartilhe uma sessão com sua auxiliar para acompanhar o atendimento pelo navegador em sala.laudousg.com. Consulte o histórico e exporte seus laudos.

UMA CONTA, DIFERENTES DISPOSITIVOS

A mesma conta LaudoUSG permite acessar os serviços disponíveis no iPhone, no Android e no computador. No iPhone, as assinaturas são adquiridas pelo sistema de compras da Apple e vinculadas à conta LaudoUSG usada na compra.

ASSINATURAS

Essencial: até 800 laudos por mês, categorias de ultrassonografia, calculadoras e esquemas.
Profissional: laudos ilimitados e Consultor IA.

Opções mensais e anuais, com preços e condições exibidos antes da confirmação. Ofertas introdutórias dependem da elegibilidade da conta Apple. As assinaturas renovam automaticamente até o cancelamento, gerenciado nos ajustes de assinaturas da Apple. O app oferece restauração de compras.

PRIVACIDADE E REVISÃO MÉDICA

O processamento por IA depende de permissão explícita. Achados, laudos e imagens selecionadas podem ser enviados à OpenAI; áudio pode ser enviado à Deepgram ou à OpenAI para transcrição. A permissão pode ser retirada em Preferências > Privacidade e IA. Evite identificadores de pacientes no conteúdo enviado à IA.

O LaudoUSG não substitui o exame, a avaliação clínica nem o julgamento do médico. Confira dados, medidas, cálculos e texto antes de usar qualquer resultado. A responsabilidade pela validação do laudo é do profissional habilitado.

Termos de uso: https://laudousg.com/terms
Política de privacidade: https://laudousg.com/privacy
Suporte: contato@laudousg.com

## Notas para revisao propostas

Credentials are provided in the App Review sign-in fields. Do not delete the existing review account when recording a demonstration; use a separate disposable account.

IN-APP PURCHASE: Sign in, open Menu > Preferencias > Assinatura > Assinar (or Ver planos). Four auto-renewable subscriptions are offered in the LaudoUSG Planos group: Essencial monthly/yearly and Profissional monthly/yearly. Prices and introductory-offer eligibility are loaded from StoreKit. Essencial includes up to 800 reports/month. The AI Consultant belongs to Profissional, not Essencial. Restore Purchases is available in the same section and on the paywall.

The service supports a shared account across iOS, Android and web. Purchases initiated in the iOS app use Apple In-App Purchase; an Apple purchase is linked to the signed-in LaudoUSG account. Existing subscriptions from the website remain usable. There is no external checkout in the iOS purchase flow.

ACCOUNT DELETION: Menu > Preferencias > Conta > Excluir minha conta > Continuar com exclusao > type EXCLUIR > Excluir minha conta. Deletion is immediate and does not require contacting support. The app warns that deleting an account does not cancel Apple billing and provides Manage Apple Subscription without blocking deletion.

AI DATA PERMISSION: The app separately requests permission to send selected content to OpenAI and audio to Deepgram/OpenAI. Declining prevents AI requests; account management, history and local calculators remain available. Permission can be changed under Preferencias > Privacidade e IA.

Before submission: verify these paths on the signed build, attach current evidence, associate all four products with the app version, and replace the old build 147.
