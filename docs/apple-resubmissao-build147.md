# Reenvio à Apple — resposta à rejeição do build 146 (5.1.1v + 3.1.1)

> Rejeição revisada em 25/jun no build **146** (anterior às correções de delete+IAP, de 26/jun).
> O código atual já cumpre os dois. Subir **build 147** e enviar os materiais abaixo.

## Checklist antes de enviar
- [ ] Bump do build para **147** (versão 1.0) e Archive + Upload.
- [ ] App Store Connect: os **4 produtos IAP** (`essential/pro` × `monthly/yearly`) em **"Ready to Submit"**,
      com nome/descrição/preço + **screenshot de review**, e **anexados a esta versão** (1ª submissão de IAP
      exige enviar os produtos JUNTO com o build).
- [ ] Testar a compra em **sandbox** (Sandbox Tester) — confirmar que `Product.products` carrega e a compra completa.
- [ ] Conta demo = **gratuita** (pra o revisor bater no paywall) — preencher credenciais nas Notes.
- [ ] Gravar os **2 vídeos** (roteiros abaixo) e anexar/linkar nas Notes.

---

## A. Resposta ao App Review (colar na conversa do App Store Connect)

Hello,

Thank you for the detailed review. Both items have been addressed in the new build (1.0, build 147). The previously reviewed build (146) was submitted before these changes were completed.

**Guideline 5.1.1(v) — Account Deletion**
The app now supports in-app account deletion. From the Settings tab → "Excluir conta" (Delete account), the user confirms by typing "EXCLUIR" and the account, together with all associated data, is permanently deleted server-side (this is a real deletion, not a deactivation). A success confirmation is shown and the app returns to the login screen. A screen recording of the complete flow is included in the App Review Information notes.

**Guideline 3.1.1 — In-App Purchase**
The app now offers auto-renewable subscriptions through StoreKit In-App Purchase: four products (Essential and Pro, monthly and yearly), each with a 7-day free trial. The paywall is reachable from the Settings tab and when generating a report. "Restore Purchases" is included. LaudoUSG is a multiplatform service (web, iOS, Android): per guideline 3.1.3(b), subscriptions purchased on other platforms are honored, and the same subscriptions are now available to purchase via In-App Purchase inside the app. The app does not direct users to any external purchase mechanism.

The demo account credentials and step-by-step test instructions for both flows are provided in the App Review Information notes.

Thank you,
Dr. Luiz Prazeres — LaudoUSG

---

## B. App Review Information → Notes (colar no campo Notes)

Demo account (free tier):
  Email: __________
  Password: __________

== ACCOUNT DELETION (Guideline 5.1.1(v)) ==
1. Sign in with the demo account (or create a new account).
2. Open the Settings tab → tap "Excluir conta" (Delete account).
3. Tap "Continuar com exclusão", type EXCLUIR, then tap "Excluir minha conta".
4. A success confirmation is shown ("Conta excluída com sucesso") and the account is
   permanently deleted server-side; the app returns to the login screen.
Screen recording: delete-account.mp4

== IN-APP PURCHASE (Guideline 3.1.1 / 3.1.3(b)) ==
- The app offers 4 auto-renewable subscriptions via StoreKit (Essential/Pro, monthly/yearly,
  each with a 7-day free trial).
- The paywall is reachable from: Settings → "Assinar", and when tapping Generate at the free limit.
- "Restore Purchases" is available inside the paywall.
- LaudoUSG is a multiplatform service (web/iOS/Android). Subscriptions purchased on other
  platforms are honored, and are also available for purchase via IAP in the app (guideline 3.1.3(b)).
  No external purchase links are used.
Screen recording: iap-purchase.mp4

---

## C. Roteiro dos screen recordings (iPhone físico)

### Vídeo 1 — Exclusão de conta (OBRIGATÓRIO)
1. Iniciar a gravação de tela.
2. Abrir o app e fazer login com a conta demo.
3. Ir na aba **Ajustes** (Settings).
4. Tocar em **"Excluir conta"**.
5. Tocar **"Continuar com exclusão"**.
6. Digitar **EXCLUIR**.
7. Tocar **"Excluir minha conta"**.
8. Mostrar a tela **"Conta excluída com sucesso"** → o app volta para o login.
9. (Reforço opcional) tentar logar de novo com as mesmas credenciais → falha (prova a deleção).

### Vídeo 2 — Compra via IAP (RECOMENDADO)
1. No iPhone: Ajustes do iOS → App Store → **Sandbox Account** com um Sandbox Tester logado.
2. Iniciar a gravação. Abrir o app e logar (conta **gratuita**).
3. Abrir o paywall (Ajustes → "Assinar", ou tocar Gerar no limite free).
4. Mostrar os **4 planos** com preço + **7 dias grátis**.
5. Tocar um plano → folha de compra da **Apple (sandbox)** → confirmar.
6. Mostrar o acesso liberado.
7. Mostrar também o botão **"Restaurar compras"**.

---

## Onde está cada coisa no código (referência)
- Delete UI: `LaudoUSG/Features/Settings/DeleteAccountView.swift` (+ entrada em `SettingsView.swift:110`).
- Delete API: `AuthService.deleteAccount()` → `DELETE /api/me/delete-account` → backend `auth.admin.deleteUser`.
- IAP: `Services/StoreManager.swift` (4 produtos, restore via `AppStore.sync()`), `Features/Paywall/PaywallSheet.swift`.
- Entitlement: `Core/AppState.swift` → `effectiveTier = max(backendTier, store.entitlementTier)` (3.1.3b).
- Config local de teste: `LaudoUSG.storekit` (NÃO substitui o App Store Connect).
