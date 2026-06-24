# Submissão Build 146 — checklist + textos prontos (resubmissão Apple)

> Tudo o que você precisa pra compilar e submeter à tarde. Branch: `fix/apple-resubmission-146`.
> A build 145 foi **REJECTED**; esta resolve os 3 issues.

---

## 1. O que mudou nesta build (para suas anotações)
- **5.1.1(iv):** botão de pré-permissão `"Permitir microfone"` → `"Continuar"`.
- **2.1(b)/2.1:** removidas as referências a assinatura. Consultor IA fica **oculto** para quem não tem o plano (gating pelo backend, sem modal de venda); paywall pós-tour removido. App = "grátis, conta gerenciada externamente".
- **Bugs do core (qualidade):** geração cancelável; `done` vazio não zera laudo; sem spinner infinito; sem logout a cada abertura.
- **Calculadoras:** anemia MCA-PSV cutoff 1,50 MoM (Mari); pré-eclâmpsia com P95 do IP uterino por IG (Gómez 2008).

---

## 2. ✉️ RESPOSTA PARA A APPLE (colar no Resolution Center, em inglês)

```
Hello, and thank you for the review.

We addressed all points:

5.1.1(iv) — Microphone permission: The pre-permission screen button no longer
uses "Permitir" (Allow). It now uses neutral wording ("Continuar" / Continue).
No button text encourages granting the permission.

2.1(b) and 2.1 — Subscriptions / In-App Purchases: We removed all references to
subscriptions from the app. The app contains NO in-app purchases. Access to
features is managed by the user's account, provisioned outside the app. Because
there are no subscriptions in the app, a demo account with an expired
subscription does not apply.

The demo account for review remains:
  user: apple-review@laudousg.com
  password: apple12345

Please let us know if anything else is needed. Thank you.
```

---

## 3. 🔨 Build + Upload (Xcode)
1. Abrir `LaudoUSG.xcodeproj` no Xcode (na branch `fix/apple-resubmission-146`).
2. **Build number = 146** (a 145 já foi pra Apple → tem que ser maior).
   - Xcode → target LaudoUSG → General → Identity → **Build = 146**
   - ou no terminal: `agvtool new-version -all 146`
3. Selecionar destino **"Any iOS Device (arm64)"**.
4. **Product → Archive**.
5. No Organizer: **Distribute App → App Store Connect → Upload** (signing automático com o time `W772N4FGJ6`).
6. Aguardar o processamento da build no ASC (~5–15 min, chega email).

## 4. ✅ App Store Connect (depois do upload)
1. App Store Connect → app LaudoUSG → versão **1.0**.
2. Em **Build**, selecionar a build **146** recém-processada.
3. **App Review Information**: confirmar demo account `apple-review@laudousg.com` / `apple12345`. (Não precisa mais de "subscription expirada".)
4. **Resolution Center** → responder com o texto da seção 2.
5. Conferir que a **descrição/keywords** do app NÃO mencionam "assinatura/plano/pro pago" (se mencionarem, ajustar — o app é grátis).
6. **Add for Review → Submit**.

## 5. Notas
- Antes do review, garantir no backend (Supabase iOS) que a conta `apple-review@laudousg.com` está com plano **clinic/pro** → o revisor vê o Consultor IA funcionando, sem paywall.
- Posso configurar **Fastlane** depois (build+upload automático via ASC API key) — não precisa clonar repo, é ferramenta padrão. Fica pra depois desta submissão manual.
