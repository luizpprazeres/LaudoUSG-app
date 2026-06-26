# Review readiness — Build 147 (IAP + delete account)

> Resolve a rejeição do build 146: **3.1.1** (IAP) e **5.1.1(v)** (exclusão de conta).
> Branch: `feat/iap-storekit`.

## ⚠️ PRÉ-REQUISITOS antes de submeter (sem isto a Apple rejeita de novo)
1. **Paid Apps Agreement = Active** + banking/tax preenchidos (ASC › Business › Agreements). **Bloqueador.**
2. **Small Business Program** aceito (15%).
3. **Conta demo SEM plano:** no Supabase MOBILE (`yldtkqrsbgcnwlydrrot`), `apple-review@laudousg.com` deve ter
   `plan = NULL` (ou `free`). **Mudança vs. builds anteriores** (antes era `clinic`/`pro`). Motivo: o reviewer precisa
   cair no paywall e comprar via IAP — se já vier com plano, ele não vê o fluxo de compra e rejeita de novo (3.1.1).
4. **Review screenshots dos 4 IAPs** no ASC (estão em MISSING_METADATA) — tirar do paywall no simulador/sandbox e subir.
5. Build **147** (≥146) arquivada e selecionada na versão 1.0.

## ✉️ Resposta ao Resolution Center (colar em inglês)

```
Hello, and thank you for the review. We addressed both issues in this build.

Guideline 3.1.1 (In-App Purchase): The app now sells auto-renewable subscriptions
via In-App Purchase (StoreKit). The "Essencial" and "Profissional" plans (monthly
and yearly, with a 7-day free trial) can be purchased directly in the app, in
Settings ("Preferências") -> "Assinatura" -> "Assinar", or by tapping the AI
Consultant feature ("Consultor IA"). All paid functionality is unlocked through
IAP, and the app contains no buttons or links to purchase outside of IAP.
Customers who subscribed on our website keep their access as a multiplatform
service (3.1.3(b)). "Restore Purchases" is available in the same "Assinatura" section.

How to test the purchase:
1) Sign in with the demo account below (it has NO active plan).
2) Open the top-right menu -> "Preferências" -> "Assinatura" -> "Assinar".
3) The paywall shows the plans in BRL with a 7-day free trial. Complete a purchase
   with the App Review sandbox account. The AI Consultant is then unlocked.

Guideline 5.1.1(v) (Account Deletion): Account deletion is available in the app at
the top-right menu -> "Preferências" -> "Conta" -> "Excluir minha conta". It asks
for a typed confirmation ("EXCLUIR") and permanently deletes the account and its
data. A screen recording is attached.

Demo account:
  user: apple-review@laudousg.com
  password: apple12345

Thank you.
```

## 📝 App Review Notes (campo "Notes" em App Review Information)

```
Demo account (no active plan): apple-review@laudousg.com / apple12345

IN-APP PURCHASE: Menu (top-right) -> Preferências -> Assinatura -> Assinar.
Paywall shows the 4 plans (Essencial/Profissional, monthly/yearly) in BRL with a
7-day free trial. Purchase with the sandbox account unlocks the AI Consultant.
Restore Purchases is in the same section.

ACCOUNT DELETION: Menu (top-right) -> Preferências -> Conta -> Excluir minha conta
-> type "EXCLUIR" -> Confirmar. Permanently deletes the account.
```

## 🎥 Roteiro do screen recording (gravar em device físico)
1. Abrir o app → login com `apple-review@laudousg.com` / `apple12345`.
2. Menu (canto superior) → **Preferências** → **Assinatura** → **Assinar**.
3. Mostrar o **paywall** com os 4 planos, preços em BRL e "7 dias grátis".
4. Comprar (sandbox) → mostrar o **Consultor IA liberado** (gerar um laudo e abrir o Consultor).
5. Voltar em **Preferências → Assinatura → Restaurar compras** (mostrar que funciona).
6. **Preferências → Conta → Excluir minha conta** → digitar **EXCLUIR** → Confirmar → volta ao login.
> Anexar o vídeo no campo **Notes** da App Review Information (e responder no Resolution Center).

## ✅ Feito no código (Fase 1 + readiness)
- StoreKit nativo (StoreManager), entitlement efetivo (IAP OU web), paywall de compra, restore, gerenciar assinatura.
- Consultor IA visível → paywall quando sem plano.
- **Exclusão de conta agora na seção "Conta"** (mais visível), em vez de só na "Zona de risco".
- App sem nenhum CTA/link de compra externa (auditado).

## Pendências P1 (não bloqueiam a 1ª aprovação)
- Sincronizar IAP→backend (App Store Server Notifications v2 + Server API) para refletir refund/cancel/expiração.
