# Mensagem para a Apple — build 147 (resposta extensa, cronológica)

> Colar na conversa do App Store Connect ao reenviar o build 147. Preencher os campos [____].

---

Dear App Review Team,

Thank you for your continued and careful review of LaudoUSG. This is our first app, and we are fully committed to following the App Store Review Guidelines. Below is a complete, chronological summary of how we have addressed every issue raised so far, followed by one remaining item where we sincerely need your guidance, as we believe it may be a configuration or propagation issue on the App Store Connect side rather than a problem with the app itself.

## 1. Our business model — In-App Purchase (Guidelines 3.1.1 / 3.1.3(b))

We want to be completely unambiguous: **all paid features in LaudoUSG are unlocked exclusively through Apple In-App Purchase (StoreKit 2). We want every subscription and payment to be processed through Apple's platform.** There is no web checkout, no external payment form, no Pix, no credit-card form, and no promo codes outside Apple's own system.

We sincerely apologize for a previous reply (June 24) in which we stated the app had "no in-app purchases" and that access was "provisioned outside the app." That statement was made out of confusion during a difficult back-and-forth and does **not** reflect our model. We have fully corrected this: the app offers our four auto-renewable subscriptions via In-App Purchase, and they are the **only** way to unlock paid features.

The four subscriptions (subscription group "LaudoUSG Planos"), each with a 7-day free trial:

- Essencial Mensal — com.laudousg.LaudoUSG.essential.monthly — R$ 99.90 / month
- Essencial Anual — com.laudousg.LaudoUSG.essential.yearly — R$ 1,019.90 / year
- Profissional Mensal — com.laudousg.LaudoUSG.pro.monthly — R$ 159.90 / month
- Profissional Anual — com.laudousg.LaudoUSG.pro.yearly — R$ 1,629.90 / year

Implementation uses StoreKit 2 (Product.purchase()), entitlements via Transaction.currentEntitlements, and a "Restore Purchases" option. The paywall is reachable from Settings ("Assinar — 7 dias grátis") and when a user accesses a premium feature. The users are Brazilian ultrasonography physicians who use the app to write medical ultrasound reports.

## 2. Account deletion (Guideline 5.1.1(v)) — RESOLVED

The app now offers in-app account deletion: **Settings → "Excluir conta" → confirm by typing "EXCLUIR" → "Excluir minha conta"**. The account and all associated data are **permanently deleted on our server** (this is a real deletion, not a deactivation). A success confirmation ("Conta excluída com sucesso") is shown and the user is returned to the login screen. A screen recording of the complete flow is included with this submission.

## 3. Microphone permission (Guideline 5.1.1(iv)) — RESOLVED

The pre-permission button no longer uses the word "Permitir" (Allow). It now uses neutral wording — **"Continuar" (Continue)** — before the system permission dialog appears.

## 4. Demo account and purchase flow (Guideline 2.1) — RESOLVED

We provide a working demo account in the App Review Information section. This account is **free** (it has no pre-granted subscription), so you can review the **entire purchase flow**: open the paywall, see the four subscriptions with the 7-day free trial, and complete a purchase using a Sandbox account, which unlocks all premium features. This also lets you verify that In-App Purchase is the only path to paid content.

## 5. The remaining difficulty — submitting the In-App Purchases (Guideline 2.1(b))

Here we genuinely need your help, because we are uncertain about what is happening and suspect it may be an App Store Connect issue on our side.

We have completed **all** required metadata for the four subscriptions and have verified each field repeatedly:

- Reference name, Product ID, and duration (1 month / 1 year) — set
- Price for Brazil (BRL) for each subscription — set
- Localization (Portuguese display name + description) — set
- 7-day free trial (StoreKit introductory offer) — set
- App Review screenshot uploaded for each subscription — uploaded
- Subscription group localization ("Planos LaudoUSG") — set
- Paid Applications Agreement: Active; bank account (Brazil / BRL): Active; tax forms: Active

Despite all of the above being completed and saved, the four subscriptions remained in **"Missing Metadata"** status for an extended period. We refreshed the page, re-saved every field, and re-verified all of the items above, and we believe this may be a **propagation or caching delay in App Store Connect**, not a missing field on our side. We have attached the four In-App Purchases to this version (build 147) so they are submitted together with the binary.

If any specific field is still required, we would be extremely grateful if you could tell us exactly which one, so we can correct it immediately.

## A sincere request

As a first-time, early-stage developer, we are working with very limited resources and significant costs, and we already have physicians waiting to subscribe through the App Store. We deeply value the quality, security, and trust that the App Store and In-App Purchase provide — that is exactly why we want all payments to flow through Apple's platform. We have done our best to address every point raised in this review, and we would be sincerely grateful for your help in approving this submission as soon as possible.

Thank you very much for your time, your patience, and your guidance.

Demo account (full purchase flow can be tested via Sandbox):
  Username: [____]
  Password: [____]

Sandbox tester (optional, if you prefer a pre-created one):
  Username: [____]
  Password: [____]

Best regards,
Dr. Luiz Prazeres
Developer, LaudoUSG

---

## Checklist de envio do build 147 (resumo)
- [ ] Microfone "Continuar" ✅ (corrigido no código) + toast de exclusão ✅ — garantir que estão no build.
- [ ] **Bump build → 147**, Product → Archive → Upload.
- [ ] As 4 assinaturas em "Pronto para envio" (se travarem em "Faltam metadados", ver doc plano-apple-iap-100).
- [ ] Página da versão → "Compras dentro de apps e assinaturas" → **adicionar as 4** (vão junto com o binário).
- [ ] Conta demo do revisor **FORA** da BETA_TESTER_EMAILS (conta gratuita → testa o paywall/IAP via Sandbox).
- [ ] Colar esta mensagem + screen recording do delete nas Notes.
