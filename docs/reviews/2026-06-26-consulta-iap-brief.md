# CONSULTA — IAP nativo (StoreKit) no app Swift LaudoUSG p/ destravar Apple (3.1.1) + delete account (5.1.1v)

> Fase de PLANEJAMENTO. NÃO implemente. Quero parecer técnico sobre a MELHOR abordagem.
> Dex1 → `/tmp/resposta-dex1-iap.md` (fidelidade/correção). Dex2 → `/tmp/resposta-dex2-iap.md` (adversarial: onde a Apple
> rejeita de novo). Sejam concretos com file:line. Paths são na mesma máquina; podem ler `/Users/luizprazeres/laudousg-swift`.

## SITUAÇÃO
App iOS Swift `com.laudousg.LaudoUSG` (build 146) **rejeitado de novo** pela Apple:
- **3.1.1 (IAP):** "app accesses paid digital content purchased outside the app (subscriptions) that isn't available
  via In-App Purchase." Hoje o app **não tem StoreKit nenhum** (foi removido de propósito na estratégia "sem IAP, paga
  na web"). O Consultor IA é liberado por `hasPro` (campo `plan` do Supabase, setado após pagamento na web). Foi isso
  que a Apple barrou.
- **5.1.1(v) (delete account):** Apple diz que falta exclusão de conta. MAS o app **já tem** `DeleteAccountView.swift`
  (Configurações → "Zona de risco" → "Excluir minha conta", confirmação em 2 passos, `DELETE /api/me/delete-account`).
  Provável: o reviewer não chegou lá OU o demo account não estava configurado. A Apple pediu **screen recording**.

## DECISÃO DO DR. LUIZ
Ir para **IAP nativo (StoreKit 2)**, **só Brasil, português, em BRL**. Criar as assinaturas no ASC (já existe o grupo
"LaudoUSG Planos" id=22108912, com 0 produtos). Quer tudo dentro do app na próxima build.

## ESTADO DO CÓDIGO (mapeado)
- Gating: `Core/AppState.swift` — `UserProfile.plan`, `hasEssencialOrAbove` (essential/clinic/pro), `hasPro` (clinic/pro).
- `plan` vem do Supabase via `ProfileService.fetchProfile()`; setado após pagamento web (`web.laudousg.com`).
- Consultor IA gated por `hasPro` em `Features/Generate/GenerateView.swift:123`.
- `Features/Paywall/PaywallSheet.swift` — modal "acesso restrito" SEM preços/links/compra.
- Zero StoreKit. Bundle `com.laudousg.LaudoUSG`. Backend `laudousgmobile.vercel.app`. Auth Supabase.

## PERGUNTAS DEX1 (fidelidade/correção da arquitetura)
I1.1 StoreKit 2: estrutura recomendada (Product.products, Transaction.currentEntitlements, Transaction.updates listener,
     purchase(), AppStore.sync() p/ restore). Onde plugar no app (um StoreManager observável? como injetar no AppState).
I1.2 Fonte de verdade do entitlement: StoreKit local (currentEntitlements) vs. backend. Como conciliar com o `plan` do
     Supabase sem quebrar o gating atual (hasPro/hasEssencialOrAbove). Recomenda mapear produto IAP → plan, e/ou validar
     via App Store Server Notifications v2 no backend? O que é P0 (client-side) vs P1 (server-side validation).
I1.3 Multiplataforma (guideline 3.1.3b): o app PODE continuar liberando quem comprou na web E ter IAP? Como não violar
     (não pode ter "link/CTA para comprar fora"; a compra no app tem que ser via IAP). O que muda no PaywallSheet.
I1.4 Mapear produtos: 2 tiers (Essencial, Pro/Clinic) × períodos (mensal/anual?) — como modelar no grupo de assinatura
     (níveis de upgrade/downgrade dentro do mesmo grupo). Product IDs sugeridos.
I1.5 Criar os produtos via App Store Connect API (POST /v1/subscriptions, /v1/subscriptionPrices, localizations pt-BR):
     o que dá pra automatizar e o que exige ASC web (screenshots de review do IAP, Paid Apps Agreement, banking/tax).

## PERGUNTAS DEX2 (adversarial: onde a Apple rejeita DE NOVO)
I2.1 Se mantivermos o gating por `plan` do backend (web) mas adicionarmos IAP, a Apple aceita? Risco: reviewer não vê
     caminho de compra IAP (conta de review já vem com plano setado) → rejeita por "não consegui comprar". Como garantir
     que o reviewer VÊ e CONSEGUE comprar via IAP (paywall com produtos reais, sandbox).
I2.2 5.1.1v de novo: por que a Apple não viu o delete account? Demo account, visibilidade, ou regressão no build 146?
     Como blindar (vídeo + tornar o fluxo óbvio + notas de review com passo-a-passo).
I2.3 Paid Apps Agreement / banking / tax como bloqueador absoluto de IAP. Conta é **Individual** (não Organization
     ainda). IAP funciona em conta Individual? O que precisa estar preenchido antes de submeter.
I2.4 Edge cases que geram rejeição/bug: sandbox testing, restore purchases obrigatório, family sharing, reembolso,
     downgrade/upgrade, expiração, "manage subscription", links proibidos (não pode CTA "compre no site"). Privacy
     nutrition labels (Payment Info muda?). Texto/metadata que mencione preço fora.
I2.5 Risco de remover o pagamento web vs. manter ambos. Recomenda, para destravar AGORA, qual caminho mínimo?

## ENTREGA
Cada um: parecer + sequência de fases (P0 mínimo p/ destravar a loja vs P1) + riscos não listados. Escrever no arquivo.
