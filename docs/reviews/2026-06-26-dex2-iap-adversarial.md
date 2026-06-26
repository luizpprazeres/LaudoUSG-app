# DEX2 — parecer adversarial IAP / App Review

## I2.1 — Se mantiver gating por `plan` do backend e só adicionar IAP, a Apple aceita?

Só aceita se o caminho IAP ficar óbvio e funcional para uma conta sem plano. Do jeito que o app está hoje, o reviewer pode rejeitar de novo mesmo com StoreKit adicionado, porque o `Consultor IA` fica oculto quando `app.profile?.hasPro != true`: em `GenerateView`, o botão só é passado para `PlusSheet` se `hasPro` for verdadeiro (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Generate/GenerateView.swift:120-126`). Em `PlusSheet`, a seção de IA só aparece se `onOpenConsultor` existir (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Components/Sheets/PlusSheet.swift:393-437`). Ou seja: para uma conta gratuita, o reviewer pode nem ver que existe recurso pago, nem ver paywall, nem ver compra.

Isso é o ponto onde a Apple rejeita de novo: “o app acessa conteúdo pago externo” ou “não encontramos os IAPs no app”. A própria guideline 2.1(b) pede IAP completo, visível e funcional para review; se itens configurados não puderem ser encontrados, precisa explicar nas notas. Fonte: `https://developer.apple.com/app-store/review/guidelines/`, linhas 263-267.

O P0 precisa mudar a experiência de review: demo account sem plano, `Consultor IA` visível para todos, toque em recurso pago abre paywall StoreKit com produtos reais e preço em BRL. A conta de review não deve vir com `plan=pro`, porque isso esconde o fluxo de compra. Pode manter `plan` para usuários web existentes, mas o entitlement efetivo no app precisa ser “backend plan OU StoreKit ativo”, e o paywall precisa aparecer quando nenhum dos dois existir.

O `PaywallSheet` atual não compra nada. Ele só mostra “Acesso restrito” e botão “Já tenho acesso — atualizar” (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Paywall/PaywallSheet.swift:39-83`). Isso era uma estratégia para não vender no app; agora é exatamente o tipo de tela que não resolve 3.1.1. Guideline 3.1.1 diz que para desbloquear funcionalidade no app por assinatura/premium, precisa usar IAP, e não mecanismo próprio. Fonte: `https://developer.apple.com/app-store/review/guidelines/`, linhas 341-345.

## I2.2 — 5.1.1(v): por que a Apple não viu exclusão de conta e como blindar

A exclusão existe no código, mas está escondida o suficiente para reviewer perder. O caminho real é Menu → Preferências → Zona de risco → Excluir minha conta. O menu chama `Preferências` (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Components/Sheets/MenuSheet.swift:13-19`), e em Settings o link aparece só no fim da tela, dentro de “Zona de risco” (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Settings/SettingsView.swift:122-137`). A tela de exclusão tem confirmação em duas etapas (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Settings/DeleteAccountView.swift:35-90`) e chama `AuthService.shared.deleteAccount()` (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Settings/DeleteAccountView.swift:178-194`), que bate em `DELETE /api/me/delete-account` (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Services/AuthService.swift:379-381`).

Então o risco não é ausência de feature; é discoverability e conta de review. A Apple pede que a exclusão seja fácil de encontrar e normalmente em account settings. Fonte: `https://developer.apple.com/support/offering-account-deletion-in-your-app/`, linhas 164-170. Se o reviewer está numa conta sem perfil válido, backend instável, ou não recebeu passo-a-passo, ele marca como ausente.

Blindagem P0: nas Review Notes, escrever literalmente o caminho: “Login com demo → botão menu no canto superior → Preferências → Zona de risco → Excluir minha conta → Continuar → digitar EXCLUIR”. Anexar screen recording. No app, eu deixaria um item “Conta” ou “Excluir conta” mais visível dentro da seção Conta, não só em “Zona de risco” no fim da página. Não precisa remover a confirmação; Apple permite confirmação para evitar exclusão acidental, desde que não dificulte de forma desnecessária. Fonte: `https://developer.apple.com/support/offering-account-deletion-in-your-app/`, linhas 177-178.

## I2.3 — Paid Apps Agreement / banking / tax / conta Individual

Isso pode bloquear tudo antes do código. Para oferecer IAP, o Account Holder precisa aceitar o Paid Apps Agreement e preencher banking/tax; a Apple também diz que o agreement precisa estar Active para testar IAP no sandbox. Fonte: `https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/`.

Conta Individual não é, por si só, bloqueio para IAP. O requisito que aparece na documentação é Account Holder + Paid Apps Agreement + banking/tax + produtos configurados. Organização só vira assunto se houver necessidade de fluxo corporativo, dados legais, ou features específicas; para auto-renewable subscription comum, o bloqueador prático é contrato/pagamento/tax, não ser Individual.

Se o acordo estiver pendente, os produtos podem não carregar, sandbox pode falhar e o reviewer vai cair em tela vazia. Isso vira rejeição 2.1(b) ou 3.1.1 mesmo com StoreKit no app. Antes de subir build, precisa provar em device/TestFlight que `Product.products(for:)` retorna os produtos e que uma compra sandbox completa gera entitlement.

## I2.4 — Edge cases que geram rejeição ou bug

Restore é obrigatório na prática. Guideline 3.1.1 fala em restore mechanism para IAP restorable, e assinatura é restorable. Fonte: `https://developer.apple.com/app-store/review/guidelines/`, linhas 341-345. P0 precisa ter botão “Restaurar compras” chamando `AppStore.sync()` e depois relendo entitlements. Não esconder restore só em Settings.

Produto não encontrado é rejeição provável. Se o app estiver só no Brasil, produtos precisam estar disponíveis no storefront usado no review/sandbox. Se o reviewer estiver fora do Brasil e os produtos não aparecem, ele rejeita por IAP não funcional. Se a estratégia é “só Brasil”, as Review Notes precisam explicar disponibilidade e o app precisa lidar com produtos indisponíveis sem parecer quebrado; mas para destravar review, eu tentaria evitar dependência frágil de storefront.

Upgrade/downgrade precisa ser um grupo de assinatura bem modelado. Apple exige experiência sem múltiplas assinaturas inadvertidas para variações da mesma coisa. Fonte: `https://developer.apple.com/app-store/review/guidelines/`, linhas 362-376. Se Essencial e Pro ficarem em grupos diferentes, usuário pode assinar os dois, e isso é rejeitável ou pelo menos bug de assinatura.

Links externos são alto risco no Brasil. Guideline 3.1.1(a) / 3.1.3 permite exceções específicas e menciona exceção do storefront dos EUA, mas fora disso apps e metadata não devem ter botões/links/CTA para compra externa. Fonte: `https://developer.apple.com/app-store/review/guidelines/`, linhas 353-360 e 377-380. No app atual, não vi CTA de compra web explícito no Paywall, mas existe `webBaseURL` em config (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Core/AppConfig.swift:4-6`) e links legais para `laudousg.com`. Isso não é problema sozinho; o problema seria texto tipo “assine no site”, “compre na web”, “fale conosco para liberar plano”, preço externo ou metadata apontando para web.

Reembolso, expiração e cancelamento precisam bloquear entitlement. Se P0 for só client-side, `Transaction.currentEntitlements` resolve boa parte no aparelho, mas backend `plan` pode continuar pro depois de reembolso/cancelamento web/IAP. Apple oferece App Store Server Notifications para refunds, subscription state e Family Sharing. Fonte: `https://developer.apple.com/in-app-purchase/`, linhas 304-307 e 393-399. Para destravar loja dá para aceitar P0 client-side, mas P1 server-side é necessário para não vazar acesso.

Family Sharing precisa decisão explícita no ASC. Se habilitar, o app precisa aceitar entitlement de family. Se não habilitar, não prometer compartilhamento. A Apple documenta Family Sharing para auto-renewable subscriptions. Fonte: `https://developer.apple.com/in-app-purchase/`, linhas 346-348.

Privacy nutrition labels provavelmente precisam revisão no App Store Connect, mesmo que o app não colete número de cartão. IAP em si é processado pela Apple, mas o app passará a processar estado de assinatura/transaction ID se enviar ao backend. O `PrivacyInfo.xcprivacy` local hoje lista email, áudio, conteúdo, user ID e outros dados, mas não declara nada específico de compra/pagamento (`/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/PrivacyInfo.xcprivacy`). Se P1 enviar transaction IDs para backend, atualizar a resposta de privacidade no ASC.

## I2.5 — Remover pagamento web ou manter ambos?

Para destravar agora, eu não removeria o web dos usuários existentes, mas removeria qualquer CTA dentro do iOS para pagar fora. O caminho mínimo compatível é: quem já tem assinatura web continua acessando por `plan`; quem entra pelo app precisa conseguir comprar no app via IAP. Isso é justamente o que 3.1.3(b) permite para serviço multiplataforma: pode acessar conteúdo/assinaturas adquiridos no web, desde que esses itens também estejam disponíveis como IAP dentro do app. Fonte: `https://developer.apple.com/app-store/review/guidelines/`, linhas 377-380.

O erro seria manter o app como “login numa conta paga por fora” e adicionar um IAP escondido ou inacessível. Isso não muda a percepção do reviewer. O app precisa parecer App Store first: paywall com produtos Apple, restore, gerenciar assinatura, sem “já tenho acesso” como ação primária. “Já tenho acesso” pode existir como restore/refresh discreto, mas não pode substituir “Assinar com Apple”.

Minha recomendação para destravar: manter web para usuários atuais e vendas fora do app por canais externos, mas no iOS não mencionar web checkout, não mostrar preço web, não mandar para site, e garantir que todos os recursos digitais pagos disponíveis no app tenham opção IAP equivalente.

## Sequência de fases

P0.1 é destravar App Store Connect antes de codar: Paid Apps Agreement ativo, banking/tax preenchidos, grupo “LaudoUSG Planos” com assinaturas mensais/anuais necessárias, localização pt-BR, preço BRL, screenshot/review info de cada IAP e status pronto para submissão. Sem isso, qualquer build StoreKit pode falhar no review.

P0.2 é tornar o fluxo revisável: conta demo sem plano, Consultor IA visível para conta gratuita, toque abre paywall StoreKit, produtos carregam, compra sandbox funciona, restore funciona, e Review Notes têm passo-a-passo com vídeo. O paywall atual deve deixar de ser “atualizar acesso” e virar compra real via Apple.

P0.3 é entitlement local robusto: no app, liberar recurso se `StoreKit active entitlement` OU `backend plan ativo`. O `plan` sozinho não pode ser a única verdade para o iOS. Depois da compra, atualizar UI imediatamente e, se possível, chamar backend para registrar origem IAP, mas não depender do backend para o reviewer ver unlock.

P0.4 é blindar 5.1.1(v): manter a tela atual de exclusão, mas tornar o acesso mais óbvio em Conta/Preferências, validar o demo account, garantir que `DELETE /api/me/delete-account` funcione no ambiente de review e anexar gravação. O fluxo atual existe, porém a Apple já provou que “existe” não bastou.

P0.5 é limpeza de texto/metadata: procurar e remover qualquer CTA de compra externa no app, screenshots, descrição, review notes comerciais, termos visíveis e telas de paywall. Links legais podem ficar; link de compra não.

P1 é backend de verdade: App Store Server Notifications v2, validação com App Store Server API, tabela de subscriptions/IAP, reconciliação de refund, cancelamento, expiração, upgrade/downgrade e family sharing. Isso reduz vazamento de acesso e suporte.

P1 também inclui tela “Gerenciar assinatura” abrindo a gestão da assinatura Apple, logging de estados StoreKit, tratamento de pending purchase, Ask to Buy, billing retry, grace period e mensagens de erro localizadas. Não é essencial para a primeira aprovação se o fluxo básico estiver sólido, mas vira essencial para operação.

## Riscos não listados

O maior risco de rejeição recorrente é conta demo errada. Se mandar uma conta já Pro, a Apple não vê IAP. Se mandar uma conta gratuita, mas o Consultor continuar oculto, a Apple também não vê IAP. A conta certa para review é gratuita, com onboarding/legal já resolvido se possível, e com instruções curtas para chegar no paywall.

Outro risco é produto em App Store Connect não anexado à versão. Produtos novos precisam estar submetidos/revisáveis junto com o app. Se estiverem só criados em draft ou faltando screenshot de review, o app compila mas review falha.

Por fim, “só Brasil” é comercialmente compreensível, mas operacionalmente perigoso para review. Se a disponibilidade do app ou dos IAPs não bater com o ambiente do reviewer, StoreKit retorna vazio. Para a próxima submissão, eu priorizaria aprovação: produto disponível para review, preço BRL/localização pt-BR, e notas explicando a operação no Brasil, sem criar um bloqueio de storefront que impeça o reviewer de testar.
