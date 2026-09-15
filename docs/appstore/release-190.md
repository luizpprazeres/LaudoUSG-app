# Preparacao da versao 1.0, build 190

Status atual: submissao COMPLETA de seis itens confirmada em Aguardando revisao.
Build 190, quatro assinaturas e grupo. Lancamento manual confirmado; ainda NAO
aprovado nem publicado. Compra/restauracao real pelo TestFlight pendente.

Continua release-189.md. O build 189 foi enviado e processado como Pronta para
envio, mas ainda nao foi associado de forma persistida a versao. Uma nova aba
da versao ainda mostrou 147. Nao confundir a selecao local do modal com save.

## Diferenca em relacao ao 189

Somente o manifesto de privacidade e numero da compilacao: inclui Name, Health,
Sensitive Info, Photos or Videos e Purchase History, todos vinculados a conta,
App Functionality, sem tracking. Os cinco tipos anteriores e quatro motivos
de API foram preservados. Nenhum prompt, regra clinica ou fluxo de compra mudou.
Mapa docs/appstore/privacy-nutrition-labels.md corrigido para refletir a coleta.

plutil e diff --check passaram. Checagem estruturada passou para dez tipos
distintos, vinculo, finalidade e ausencia de tracking. Archive concluido em
/tmp/LaudoUSG-190.xcarchive: arm64, bundle/team corretos, 1.0 (190), manifesto
identico ao fonte por cmp. Organizer confirmou "LaudoUSG 1.0 (190) uploaded",
usando App Store Connect, nao Internal Only. TestFlight confirmou 190 como Pronta
para envio, sem restricao Internos (ID 6ab67095-da77-4a1e-9453-a025bdb7ecba).
Associacao a versao confirmada: removido 147, salvo estado sem build, selecionado
190 e salvo. Versao 1.0 mostra link 190 e botao Salvar desabilitado. O primeiro
fluxo falhou ao tentar remover/substituir sem salvar o estado intermediario.
Os 76 XCTest aprovados, zero falhas e tres skips WHO referem-se ao build 189.

## Pendencias da revisao

Luiz autorizou explicitamente os aceites em 13/09. Termos 2.0, Privacidade 2.1 e
Disclaimer 2.0 aceitos pela interface na conta de demonstracao. Gate avancou
para permissao IA separada; escolhido Agora nao. App abriu sem onboarding IA,
menu e preferencias acessiveis. Simulador instalado e build 189, cujo codigo
funcional e identico ao 190 (este mudou apenas manifesto e numero de build).
Compra/restauracao sandbox, notificacoes V2 reais e evidencia em aparelho
fisico continuam pendentes. Nao apagar a conta existente de revisao.

Paywall abriu por Menu > Preferencias > Assinatura > Assinar, mas produtos
retornaram vazios, inclusive apos retry. Log storekitd confirma consulta aos
quatro IDs corretos em /v1/catalog/us/in-app-purchasables, conta sandbox nil/
local, erro de headers Anisette e resposta vazia. Hipotese: regiao US do
simulador versus produtos BR; nao declarar causa unica confirmada sem teste BR.
Restaurar compras abriu autenticacao Apple; cancelada por ausencia de conta
sandbox identificada. App exibiu falha, nao falsa restauracao.

devicectl mostrou iPhone 15 Pro Max indisponivel; solicitado cabo/desbloqueio
a Luiz. Exclusao conferida ate segunda etapa, botao final desabilitado com
campo vazio. Voltou/cancelou, nenhuma exclusao executada. Advertencia de
cobranca Apple e Gerenciar assinatura presentes. Caminho das notas deve dizer
Menu, nao top-right menu. Captura fisica e teste de exclusao descartavel pendentes.

Atualizacao: iPhone conectou por cabo, Developer Mode ja habilitado. Build 185
anterior identificado; instalado o archive development-signed 190 sem desinstalar
o app, e launch confirmado pelo devicectl. Nao e o pacote baixado de TestFlight,
embora apps development-signed possam usar sandbox. A compra continua sem teste.
Espelhamento do iPhone existente tentou conectar, mas exibiu Microfone do iPhone
em Uso. Solicitado a Luiz encerrar gravacao/chamada quando puder, sem interferir
automaticamente no microfone. Paired Devices nao listou aparelho. Simulador
proprio desligado apos testes; demais aparelhos/simuladores preservados.
Depois o espelhamento expirou por dispositivo em uso e pediu Bloqueie o iPhone
para conecta-lo. Proxima acao: Luiz encerrar uso do microfone e bloquear o iPhone;
entao acionar Conectar no Espelhamento. Nao confundir desbloqueio necessario a
instalacao com bloqueio necessario ao espelhamento.

Notas de caminho Menu corrigidas no documento local. Tentativa de alterar a
nota Profissional Anual na loja nao persistiu: campo relido ainda top-right.
Corrigir notas da versao e dos quatro produtos quando a interacao funcionar.
Adicionar para revisao (dropdown) nao abriu por AX/teclado; coordenadas retornaram
noWindowsAvailable. Produtos ainda NAO incluidos no rascunho; nao clicar Enviar
para revisao sem os quatro produtos e restantes gates.

Metadados da versao ja salvos conforme release-189.md. Produtos ainda Preparar
para envio. Profissional Anual tem captura de revisao cadastrada, localizacao
pt-BR correta e preco atual Brasil R$ 1.629,90. Nota de caminho da compra,
beneficios e storefront Brasil salva; preco e disponibilidade nao alterados.
Os quatro produtos possuem captura de revisao cadastrada; ainda nao conferida
visualmente contra o build atual. Notas especificas salvas em cada produto.
Precos brasileiros conferidos e inalterados: Profissional mensal R$ 159,90;
Profissional anual R$ 1.629,90; Essencial mensal R$ 99,90; anual R$ 1.019,90.

Descricao da versao, notas dos quatro produtos e precos conferidos. Rascunho
de envio criado, contem iOS App 1.0 (190), com botao Enviar para revisao ainda
NAO acionado. Os quatro produtos ainda precisam entrar nesse mesmo rascunho.
Concluir privacidade, testes sandbox e evidencias antes da submissao final.

## Questionario de privacidade na loja

Selecionados dez tipos, removendo Other User Contact Info e adicionando Health,
Sensitive Info, Photos or Videos e Purchase History. A loja avisou que os quatro
adicionados NAO entram na pagina do produto enquanto suas finalidades nao forem
concluidas. Nao considerar a ficha publicada/alinhada. Controles Configurar saude
etc. ficaram pendentes: AX retorna o texto, mas acionamento/rolagem nao abriu
o editor; interacao por coordenadas retornou noWindowsAvailable. Mac consultado
como IOConsoleLocked=No. Zoom temporario restaurado a 100%. Aba mantida aberta
no rascunho, outra aba aberta para acompanhar processamento do build.

## Retomada com iPhone conectado

devicectl confirmou iPhone 15 Pro Max connected. Espelhamento abriu login do
LaudoUSG; controle por coordenadas inicialmente falhou, depois funcionou. Login
com conta de demonstracao concluido, sem salvar senha. Os mesmos tres documentos
2.0/2.1/2.0 reapareceram no aparelho; aplicados os aceites ja autorizados por Luiz.
Permissao IA recusada separadamente; menu e preferencias funcionaram.

Menu > Preferencias > Assinatura > Assinar abriu paywall, carregou e terminou
com Nao foi possivel carregar os planos, sem produtos e sem compra habilitada.
Restaurar compras abriu login Conta Apple. Cancelado sem fornecer credenciais;
app exibiu Nao foi possivel restaurar as compras. Nenhuma compra ou exclusao.
Assim, indisponibilidade do catalogo reproduzida no aparelho, nao apenas no
simulador. Regiao da conta Apple no aparelho ainda nao verificada. Luiz informou
nao ter ou nao saber se possui conta Sandbox Brasil; verificar painel antes de
criar outra, com definicao de nova senha pelo proprio usuario.

Profissional Anual no Chrome exibiu erro E necessario adicionar um preco para
a assinatura, embora a tabela Preco atual para novos assinantes mostre Brasil
R$ 1.629,90 e primeira semana gratis. Nao alterar preco sem esclarecer a causa.
Nota com caminho Menu foi salva, botao Salvar ficou desabilitado. Dropdown
Adicionar para revisao abriu e mostrou o rascunho existente, mas a selecao nao
teve confirmacao verificavel. Nao considerar produto incluido. Chrome depois
retornou arvore antiga de menu e screenshot indisponivel apesar de Mac
desbloqueado; solicitado a Luiz trazer Chrome/App Store Connect para frente.
Submissao final, quatro produtos, finalidades de privacidade e testes reais
de compra/restauracao/notificacao continuam pendentes.

## Painel recuperado e tabelas de precos

Chrome nativo permaneceu com AX de menu antigo mesmo apos Luiz trazer a janela
para frente. Tentativa de encerrar por teclado nao confirmou encerramento.
Navegador integrado do Codex abriu App Store Connect ja autenticado e permitiu
seguir. Usar essa superficie na retomada, nao repetir o fluxo travado do Chrome.

Sandbox: lista vazia confirmada em Usuarios e acesso > Sandbox. Formulario
Novo tester aberto e entregue a Luiz para email, senha, confirmacao, regiao
Brasil e criacao. Nenhuma credencial nova foi criada pelo agente; nao pedir
senha no chat. Conta de demonstracao do LaudoUSG nao e Conta Apple Sandbox.

Privacidade CONCLUIDA: quatro tipos adicionados novamente na sessao integrada
e configurados individualmente. Health, Sensitive Info, Photos or Videos e
Purchase History: somente App Functionality, vinculados, sem tracking. Publicado
e recarregado; dez tipos persistidos, sem aviso de configuracao pendente.
Preview detalhado conferiu saude, confidenciais, imagens, compras e demais tipos.
Nao confundir este estado final com a tentativa incompleta descrita acima.

Precos: Profissional Anual e Profissional Mensal reproduziram E necessario
adicionar um preco para a assinatura, apesar de preco inicial brasileiro visivel.
Salvar novamente o anual com Manter os precos calculados manteve o erro.
Recalcular os precos para todos os paises ou regioes, usando Brasil e o MESMO
valor, gerou a tabela inicial de 175 regioes e desbloqueou o Profissional Mensal:
passou a Pronto para revisao e foi incluido no rascunho. Evidencia de reparo do
cadastro; nao afirmar defeito especifico da API Apple sem evidencia adicional.

Aplicado o mesmo fluxo aos quatro produtos: pro.monthly R$ 159,90; pro.yearly
R$ 1.629,90; essential.yearly R$ 1.019,90; essential.monthly R$ 99,90. Tabelas
iniciais de 175 regioes conferidas apos gravacao. Notas dos quatro produtos
agora dizem Menu, nao top-right. Nao houve reajuste no Brasil nem alteracao
explicita de disponibilidade; o dialogo do Pro Mensal confirmou somente Brasil,
e o Essencial Mensal manteve 1/175 locais de venda apos o reparo. As conversoes
para outras regioes sao precos cadastrados, nao liberacao de venda. Nao repetir
o recalculo nem criar outros produtos na retomada sem necessidade.

Envio parcial observado as 21:20: apos incluir grupo e abrir rascunho, painel
mostrou 3 itens enviados e Aguardando revisao (app 1.0/190, Pro Mensal, grupo).
Acionamento do envio nao foi intencional; causa exata nao confirmada. Cancelar
envio > Confirmar executado imediatamente, depois conferido Removido nos tres
itens. ID 508fbe0b-d70d-44c9-8d75-755b4bb606b1. Nao deixar esse evento descrito
como ausencia historica de submissao, nem como aprovacao ou envio final ativo.
Antes do envio completo, reunir app, quatro assinaturas e o grupo (seis itens),
conferir conta Sandbox, compra/restauracao/notificacoes e evidencias fisicas.

Retry no iPhone apos reparo do cadastro nao foi confirmado: controle de clique
voltou a noWindowsAvailable. Ultima tela vista ainda erro de carga anterior.
Apple documenta ate uma hora de propagacao de metadados no sandbox; nao inferir
funcionamento do catalogo no aparelho apenas pelo desbloqueio da validacao web.
Fonte: https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/

## Submissao completa em 13/09, aproximadamente 21:44

Luiz pediu seguir pelo TestFlight e priorizar publicacao sem prolongar o trabalho.
Build 190 ja associado ao grupo interno Beta Medicos (1 tester). Notas O que
testar salvas para compra, restauracao, liberacao do plano e fluxos clinicos.
Conta Sandbox foi criada com regiao Brasil, mas Luiz perdeu a senha. Optou-se
por teste via TestFlight com Conta Apple normal, que usa sandbox; nao e o mesmo
que testar o archive development-signed instalado anteriormente. Usuario avisado
para instalar/atualizar build 190 via TestFlight. Nao houve confirmacao desse
teste neste turno; espelhamento retornou noWindowsAvailable nos cliques.

Notas da versao corrigidas para Menu (sem top-right) e storefront Brasil.
Novo rascunho 21:41: build190, quatro produtos reparados e grupo adicionados,
seis itens conferidos, sem erro de validacao. Para nao atrasar a revisao, a
decisao de enviar antes de concluir teste TestFlight foi comunicada a Luiz,
mantendo lancamento manual e sem alegar testes de compra aprovados.

Enviar para revisao acionado explicitamente. Apple confirmou 6 itens enviados.
Detalhe de envio relido: TODOS em Aguardando revisao:
iOS App 1.0 (190), Profissional Anual, Profissional Mensal, Essencial Anual,
Essencial Mensal e LaudoUSG Planos. ID 2ba0be0d-64fb-40fd-8964-0190b9ce149c.
https://appstoreconnect.apple.com/apps/6770609540/distribution/reviewsubmissions/details/2ba0be0d-64fb-40fd-8964-0190b9ce149c
Versao recarregada confirmou Lancar esta versao manualmente marcado.
Nao cancelar esse envio completo por confundi-lo com o parcial anterior.
Gates ainda abertos: compra/restauracao/notificacoes reais, evidencia fisica
completa, aprovacao Apple e liberacao publica. Nao declarar objetivo atingido.
