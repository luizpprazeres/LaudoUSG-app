# Plano de ação — IAP nativo (StoreKit) + delete account → destravar Apple

> **Status:** 🟢 EM EXECUÇÃO (2026-06-26). App `com.laudousg.LaudoUSG`, rejeitado no build 146.
> Planejamento validado por Dex1 (fidelidade) + Dex2 (adversarial) — pareceres em `docs/reviews/2026-06-26-dex*-iap.md`.

## Problemas da Apple (build 146)
- **3.1.1 (IAP):** o app libera o Consultor IA (feature paga) via plano comprado **fora** (web), sem IAP. → adicionar IAP nativo.
- **5.1.1(v) (delete account):** a Apple não encontrou a exclusão de conta. Mas **ela já existe** e funciona
  (`Features/Settings/DeleteAccountView.swift`, `DELETE /api/me/delete-account`). → questão de **visibilidade + vídeo + notas**.

## Decisões travadas (Dr. Luiz)
- IAP nativo StoreKit, **só Brasil, pt-BR, BRL**. Preços **iguais à web**. **Trial 7 dias** em todos.
- 4 produtos no grupo existente **"LaudoUSG Planos"** (id `22108912`):

| Product ID | Plano | Período | Preço | Trial |
|---|---|---|---|---|
| `com.laudousg.LaudoUSG.essential.monthly` | Essencial | mensal | R$ 99,90 | 7 dias |
| `com.laudousg.LaudoUSG.essential.yearly` | Essencial | anual | R$ 1.018,98 | 7 dias |
| `com.laudousg.LaudoUSG.pro.monthly` | Profissional | mensal | R$ 159,90 | 7 dias |
| `com.laudousg.LaudoUSG.pro.yearly` | Profissional | anual | R$ 1.630,98 | 7 dias |

Grupo único, níveis: **Pro = nível 1** (topo), **Essencial = nível 2**. Entitlement → `plan`: `essential.*`→`essential`;
`pro.*`→`clinic` (mantém `hasPro`, que já aceita `clinic`/`pro`). **Small Business Program: inscrever (15%).**

## A descoberta central (Dex1+Dex2): o que faz rejeitar de novo
1. **Conta demo com plano Pro esconde o IAP.** Se o reviewer loga e já tem tudo liberado, nunca vê o paywall → rejeita.
   → conta de review deve vir **SEM plano**.
2. **Consultor IA fica oculto sem `hasPro`** (`GenerateView.swift:120-126` → `PlusSheet.swift:393-437`). Conta grátis
   nem vê o recurso pago. → tornar o recurso **visível**; tocar sem entitlement → **paywall de compra**.
3. **PaywallSheet não compra nada** (`PaywallSheet.swift:39-83`, só "já tenho acesso"). → virar **tela de compra real**.
4. **Entitlement só por `profile.plan`** quebra: compra IAP ocorre mas feature segue bloqueada. → usar **entitlement
   efetivo = StoreKit local OU backend plan**.

## Base legal: multiplataforma 3.1.3(b)
Pode **manter** quem comprou na web E ter IAP, **desde que** as mesmas assinaturas estejam disponíveis como IAP no app
**e** o iOS **não** tenha CTA/link/preço para comprar fora. → remover qualquer menção a web-checkout no app e na metadata.

---

## FASE 0 — App Store Connect (pré-requisitos, antes/junto ao código)
- [x] **Criar os 4 produtos via ASC API** (2026-06-26) — FEITO. Grupo `22108912` "LaudoUSG Planos". Scripts em
      `/tmp/asc-create-subs.mjs`, `asc-avail-price-all.mjs`, `asc-trials.mjs`. Cada produto: nome pt-BR + descrição +
      availability **Brasil** + preço BRL + **trial FREE_TRIAL ONE_WEEK (7 dias)**. (Gotcha resolvido: o preço só é
      aceito **depois** de criar a `subscriptionAvailability` com BRA — senão 409 RELATIONSHIP.INVALID.)

  | Product ID | sub id | nível | preço BRA | trial | state |
  |---|---|---|---|---|---|
  | `…essential.monthly` | 6784768067 | 2 | R$ 99,90 | 7d | MISSING_METADATA |
  | `…essential.yearly` | 6784768069 | 2 | R$ 1.019,90 | 7d | MISSING_METADATA |
  | `…pro.monthly` | 6784768031 | 1 | R$ 159,90 | 7d | MISSING_METADATA |
  | `…pro.yearly` | 6784768215 | 1 | R$ 1.629,90 | 7d | MISSING_METADATA |

  > Anuais caíram no price point Apple mais próximo (não há o centavo exato): essential R$1.019,90 (alvo 1.018,98),
  > pro R$1.629,90 (alvo 1.630,98). Diferença ~R$1 — confirmar com Dr. Luiz se ok.
  > `MISSING_METADATA` = falta o **review screenshot** de cada IAP (obrigatório p/ submeter) — só dá p/ tirar com o
  > paywall pronto (Fase 1/2). Resto (nome/preço/trial/disponibilidade) completo.
- [ ] **Confirmar Paid Apps Agreement = Active** + banking/tax preenchidos (ASC › Business). **Bloqueador absoluto** —
      sem isso o sandbox falha e o reviewer cai em tela vazia. Conta Individual **não** impede IAP. ← Dr. Luiz verifica.
- [ ] Inscrever no **Small Business Program** (15%). ← Dr. Luiz aceita no ASC.
- [ ] **Review screenshot** de cada IAP (depois do paywall pronto) + confirmar disponibilidade no storefront do review.

## FASE 1 — Código StoreKit (P0, vai na build nova) — ✅ NÚCLEO FEITO (2026-06-26, BUILD SUCCEEDED)
- [x] `Services/StoreManager.swift` (NOVO, StoreKit 2): `Product.products(for:)`; `Transaction.currentEntitlements`;
      listener `Transaction.updates`; `purchase()`; `AppStore.sync()` (restore). `PlanTier` (essential<pro). Instanciado
      em `AppState` (`let store`).
- [x] `Core/AppState.swift`: `effectiveTier` = melhor entre `profile.plan` (backend) e `store.entitlementTier` (IAP);
      `hasProEffective`/`hasEssencialOrAboveEffective`/`hasActiveIAP`/`effectivePlanLabel`.
- [x] **Consultor IA visível para todos** quando há laudo (`GenerateView`): com plano → Consultor; sem plano → paywall.
- [x] `Features/Paywall/PaywallSheet.swift` → **tela de assinatura real**: 4 produtos, **preço BRL do StoreKit**,
      trial, "Assinar", **"Restaurar compras"**, links Termos/Privacidade + texto de auto-renovação. "Já assino" discreto.
- [x] Configurações: seção **Assinatura** (Ver planos/Assinar → paywall; Restaurar; Gerenciar assinatura via
      `.manageSubscriptionsSheet`). Plano agora mostra `effectivePlanLabel`.
- [x] **`LaudoUSG.storekit`** (raiz do projeto) p/ testar o paywall no simulador sem sandbox — 4 produtos, BRL, trial 7d.
      ⚠️ ATIVAR no Xcode: Edit Scheme → Run → Options → StoreKit Configuration → `LaudoUSG.storekit`.
- [x] **Auditoria CTA de compra web:** app LIMPO — nenhum link/CTA/preço/Safari de compra. `AppConfig.webBaseURL` existe
      mas é **código morto** (não referenciado em lugar nenhum). Não viola 3.1.1. (Remover a constante é opcional.)
- [ ] **Falta P1:** sincronizar IAP→backend após compra (App Store Server Notifications v2 + Server API).

## FASE 2 — Prontidão de review (P0) — parcial
- [x] Exclusão de conta **mais visível**: movida para a seção **"Conta"** em Preferências (era só "Zona de risco").
- [x] **Review Notes + resposta ao Resolution Center + roteiro de gravação** escritos →
      `docs/appstore/review-readiness-147.md` (texto pronto p/ colar; falta anexar o vídeo).
- [ ] **Conta demo SEM plano** no Supabase MOBILE: `apple-review@laudousg.com` → `plan=NULL`. ← Dr. Luiz (ou via admin).
- [ ] **Screen recording** em device (roteiro pronto no doc). ← Dr. Luiz.
- [ ] **Review screenshots dos 4 IAPs** (tirar do paywall) + subir no ASC.
- [ ] Validar em **TestFlight**: `Product.products(for:)` retorna os 4; compra sandbox gera entitlement; restore funciona.
- [ ] Build **147** + Archive/Upload + selecionar build + colar resposta no Resolution Center + Submit.

## FASE 3 — Backend robusto (P1, depois de aprovar — não bloqueia a 1ª aprovação)
- [ ] App Store **Server Notifications v2** + **Server API**: validar transação, persistir
      `original_transaction_id`/`product_id`/`expires_at`/`environment`/`status`/plano, reconciliar refund/cancel/
      expiração/upgrade/downgrade/family sharing → `profile.plan` reflete IAP e web.
- [ ] Tela "Gerenciar assinatura", pending/Ask-to-Buy/billing-retry/grace-period, erros localizados.
- [ ] Revisar **Privacy nutrition labels** se enviar transaction IDs ao backend.

## Riscos-chave (Dex2)
1. **Conta demo errada** (Pro = esconde IAP; grátis sem visibilidade = reviewer não acha) → maior causa de re-rejeição.
2. **Paid Apps Agreement pendente** → sandbox vazio → rejeição mesmo com código pronto.
3. **"Só Brasil"** → se o storefront do reviewer não tiver os produtos, StoreKit vem vazio. Garantir disponibilidade +
   notas; paywall trata produto indisponível sem parecer quebrado.
4. **Produtos não anexados/submetíveis** (draft sem screenshot/review info) → app compila, review falha.
5. **Vazamento de acesso** (refund/cancel) sem backend P1 → aceitável no P0 client-side, resolver em P1.

## Ordem de execução
**IAP/Apple = P0 absoluto** (loja bloqueada). Trissomias Fase 1 segue em paralelo/depois.
Processo por fase: implementar → Dex1 (fidelidade) + Dex2 (adversarial) → build → @devops push/submit.
