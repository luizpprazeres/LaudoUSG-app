DEX1 — FIDELIDADE / CORREÇÃO DA ARQUITETURA IAP

I1.1 StoreKit 2: estrutura recomendada e onde plugar

Recomendação: criar uma camada única `StoreManager` observável, em `Services` ou `Core`, e injetar no topo do app junto com o `AppState`. Hoje o app cria `@State private var appState = AppState()` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/LaudoUSGApp.swift:12-14` e injeta `ContentView(app: appState)` em `:25-28`. Esse é o lugar certo para inicializar `StoreManager`, iniciar o listener de transações e disponibilizar o entitlement para as views.

A estrutura correta em StoreKit 2 é: carregar produtos com `Product.products(for:)`; calcular entitlement local lendo `Transaction.currentEntitlements`; manter um listener de `Transaction.updates` enquanto o app roda; chamar `purchase()` no produto selecionado; finalizar transações verificadas; oferecer restauração com `AppStore.sync()`. Isso bate com a documentação atual da Apple: `currentEntitlements` emite a transação mais recente para cada produto com entitlement ativo, `Transaction.updates` recebe transações novas enquanto o app está aberto, e `AppStore.sync()` força sincronização com a App Store, mas exibe UI de sistema, então deve ficar atrás de botão explícito “Restaurar compras”.

O `StoreManager` não deve substituir o `AppState`; ele deve alimentar uma camada de entitlement. O `AppState` hoje tem `profile.plan`, `planLabel`, `hasEssencialOrAbove` e `hasPro` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Core/AppState.swift:173-207`. Para reduzir mudança, eu adicionaria ao `AppState` um estado derivado, tipo `iapPlan: PlanTier?` ou `effectivePlan`, calculado como o melhor entre `profile.plan` e entitlement StoreKit. Assim as views continuam perguntando “tem Pro?” sem precisar saber se veio da web ou da Apple.

Ponto importante: hoje o Consultor IA está explicitamente escondido quando `app.profile?.hasPro != true`, em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Generate/GenerateView.swift:115-127`. Para passar na Apple, esse gating precisa enxergar o entitlement IAP também. Se continuar só `profile.plan`, a compra pelo app pode ocorrer e a feature seguir bloqueada até o backend atualizar, o que é erro funcional e risco de review.

I1.2 Fonte de verdade do entitlement

Para P0, a fonte de verdade prática deve ser StoreKit local + backend existente, conciliados no cliente. O `plan` do backend vem de `/api/me/profile` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Services/ProfileService.swift:28-31` e entra no `AppState` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Core/AppState.swift:83-95`. Isso deve continuar funcionando para quem já pagou na web.

O cálculo correto para o app é “maior entitlement ativo”: se `profile.plan` é `clinic` ou `pro`, libera Pro; se StoreKit tem produto Pro ativo, libera Pro; se StoreKit tem Essencial ativo, libera Essencial; se só backend tem Essencial, libera Essencial. Esse mapeamento precisa ser explícito: produto IAP → plan interno. Exemplo: produto Essencial mensal/anual vira `essential`; produto Pro/Clinic mensal/anual vira `clinic` ou `pro`, mas escolha uma palavra canônica só. Hoje `hasPro` aceita `clinic` e `pro` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Core/AppState.swift:202-207`, então eu usaria `clinic` como plano profissional atual se esse já é o plano comercial vivo, ou padronizaria `pro` se o produto se chama Pro. O importante é não deixar “pro”, “clinic” e “profissional” divergirem entre app, Supabase e App Store Connect.

Para P1, backend deve validar e persistir IAP. O ideal é usar App Store Server Notifications v2 e/ou App Store Server API, porque cancelamento, reembolso, billing retry e expiração precisam refletir no Supabase sem depender do usuário abrir o app. A própria Apple recomenda App Store Server API e notificações para mudanças em tempo real de status de assinatura. Mas isso não precisa bloquear a próxima submissão se o objetivo é destravar a guideline 3.1.1: P0 client-side com StoreKit 2 bem feito já cria o caminho de compra que a Apple pediu.

I1.3 Multiplataforma e compra web

Sim, o app pode continuar liberando quem comprou na web, desde que as mesmas assinaturas/funcionalidades estejam disponíveis como IAP dentro do app. A regra de multiplataforma 3.1.3(b) diz que apps multiplataforma podem permitir acesso a conteúdo, assinaturas ou features adquiridas no site, desde que esses itens também estejam disponíveis como in-app purchases dentro do app. Essa é exatamente a correção arquitetural para o caso atual.

O que não pode para Brasil, sem entitlement específico, é CTA ou link para comprar fora. A guideline 3.1.1 exige IAP para desbloquear features; a 3.1.3 também diz que os casos permitidos de outros métodos não podem encorajar compra fora do IAP dentro do app. O app tem `AppConfig.webBaseURL = https://web.laudousg.com` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Core/AppConfig.swift:3-5`, e esse tipo de link não deve aparecer em paywall, tela de plano ou copy de bloqueio se levar a compra externa.

O `PaywallSheet` precisa mudar de “já tenho acesso — atualizar” para uma tela real de assinatura nativa. Hoje ele só informa acesso restrito e chama `onSuccess()` para atualizar perfil em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Paywall/PaywallSheet.swift:66-88`. Para review, isso é insuficiente: o reviewer precisa ver produtos, preço em BRL vindo do StoreKit, botão de assinar via IAP, botão “Restaurar compras”, e talvez “Gerenciar assinatura” nas configurações depois da compra. A tela pode manter “Já tenho acesso” como “Atualizar acesso”, mas isso não pode ser o caminho principal do paywall.

I1.4 Mapeamento de produtos

Modelo recomendado: um único grupo de assinatura “LaudoUSG Planos”, porque o usuário deve ter uma assinatura ativa por vez. Isso segue a recomendação da Apple de usar um único grupo para evitar múltiplas assinaturas quando o app tem uma única assinatura ativa esperada. Dentro do grupo, níveis: nível 1 para Pro/Clinic, nível 2 para Essencial. A Apple orienta ordenar do plano que oferece mais para o que oferece menos.

Para períodos, eu faria mensal e anual para cada tier, total de 4 produtos. Se o objetivo imediato é aprovação rápida, dá para começar com 2 produtos mensais e adicionar anuais depois, mas comercialmente anual costuma ser esperado em assinatura SaaS. Como o Dr. Luiz decidiu “só Brasil, português, BRL”, configurar disponibilidade/price localization para Brasil e textos pt-BR.

Sugestão de Product IDs, mantendo bundle como prefixo e evitando acento:

`com.laudousg.LaudoUSG.essential.monthly`
`com.laudousg.LaudoUSG.essential.yearly`
`com.laudousg.LaudoUSG.pro.monthly`
`com.laudousg.LaudoUSG.pro.yearly`

Se o nome comercial real for Clinic em vez de Pro, use `clinic` nos IDs, mas não misture. Minha preferência para correção é alinhar o ID ao plano interno que destrava `hasPro`: se `clinic` é o plano profissional no Supabase, IDs `clinic.monthly/yearly`; se a comunicação pública será “Pro”, padronize backend para `pro` e mantenha compatibilidade com `clinic` só como legado.

I1.5 App Store Connect API: o que automatiza e o que exige web

Dá para automatizar boa parte via App Store Connect API: criar/listar subscriptions, criar localizações, configurar preços/price schedules e associar ao grupo. A documentação da API tem recursos para `subscriptions`, `subscriptionPrices` e `subscription localizations`. Isso é útil para evitar clique manual repetitivo e manter IDs/preços versionados.

Mas há bloqueios que normalmente são web/conta e não “só API”: Paid Apps Agreement aceito, dados bancários e fiscais completos, disponibilidade do IAP para submissão, screenshots/metadata de review do IAP quando exigidos, e conferência visual do grupo/níveis/territórios no App Store Connect. Antes de submeter, alguém precisa abrir o ASC e confirmar que os produtos estão em estado submetível/aprovável, com nome localizado pt-BR, descrição clara, preço BRL e review information preenchida.

Sequência de fases

P0 para destravar Apple 3.1.1: criar produtos no ASC no grupo existente; implementar StoreManager StoreKit 2 client-side; mudar PaywallSheet para exibir produtos reais com preço StoreKit, compra IAP e restaurar compras; criar `effectivePlan` combinando `profile.plan` com entitlement local; trocar gates críticos para `effectivePlan`, começando pelo Consultor IA em `GenerateView`; remover qualquer CTA de compra web dentro do app; adicionar tela/linha de assinatura em Configurações com status, restaurar e gerenciar assinatura; gravar vídeo de review mostrando cadastro/login, paywall, compra sandbox, restore, acesso ao Consultor e caminho de exclusão de conta.

P0 também deve blindar 5.1.1(v): o fluxo já existe em Settings → Zona de risco → Excluir minha conta, com link em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Settings/SettingsView.swift:122-137`, confirmação em dois passos em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Features/Settings/DeleteAccountView.swift:35-91`, e chamada real `DELETE /api/me/delete-account` em `/Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG/Services/AuthService.swift:379-382`. Para fidelidade com a Apple, deixe isso fácil de achar nas notas de review e, se possível, adicione uma linha “Conta” mais visível ou texto nas notas: Menu → Preferências → Zona de risco → Excluir minha conta → digitar EXCLUIR. A Apple exige que a opção seja fácil de encontrar e permita iniciar exclusão dentro do app.

P1 robusto: backend valida transações e sincroniza Supabase. Criar endpoint para receber transaction/originalTransactionId do cliente após compra, verificar com App Store Server API, persistir `app_store_original_transaction_id`, `product_id`, `expires_at`, `environment`, `status` e plano interno. Ativar App Store Server Notifications v2 para renovação, expiração, reembolso, billing retry e downgrade/upgrade. A partir daí, `profile.plan` pode voltar a ser a fonte principal porque passa a refletir IAP e web, mas o app ainda deve usar StoreKit local como fallback imediato.

P1.5 operacional: dashboard/admin para reconciliar usuários web + IAP, tratar troca de conta no mesmo Apple ID, restore em conta diferente, refund, expiração e suporte. Também revisar App Privacy: IAP em si é processado pela Apple, mas se o backend passar a armazenar transaction IDs e status de assinatura, isso entra como dado de compra/identificador associado ao usuário e precisa estar coerente com privacy policy/metadados.

Risco adicional DEX1: “demo account Pro” pode esconder o paywall. Para revisão da 3.1.1, a conta de review precisa estar sem plano no Supabase, para o reviewer bater no paywall e conseguir comprar via sandbox. Se a conta já vier com `profile.plan = pro`, o app vai liberar tudo e a Apple pode concluir que ainda há conteúdo pago externo sem IAP visível.

Risco adicional DEX1: se o app estiver “só Brasil”, não deixe produto indisponível no storefront usado pelo reviewer. Mesmo que a estratégia comercial seja BRL/Brasil, a submissão precisa garantir que App Review consiga carregar os produtos no ambiente deles. Se a Apple revisar com storefront diferente e `Product.products(for:)` vier vazio, o paywall precisa exibir erro de configuração/retry, mas isso é ruim para aprovação; melhor confirmar disponibilidade/teste em TestFlight/App Review antes.

Fontes Apple usadas para correção da arquitetura: App Review Guidelines 3.1.1 e 3.1.3(b), documentação StoreKit 2 de `Transaction.currentEntitlements`, `Transaction.updates`, `AppStore.sync()`, página Apple de auto-renewable subscriptions e guia oficial de account deletion.
