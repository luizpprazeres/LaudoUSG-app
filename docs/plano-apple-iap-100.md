# Plano robusto — IAP 100% no App Store Connect (re-submissão build 147)

> Diagnóstico (confirmado por revisão das guidelines + docs StoreKit): o bloqueio do 3.1.1
> NÃO é código — é que as 4 assinaturas estão em **"Faltam metadados"** e não foram **anexadas
> à versão**. "Faltam metadados" não se desmarca: some quando os campos obrigatórios são preenchidos.
> Código de IAP (StoreManager/PaywallSheet/AppState/.storekit) já está correto: produtos carregam,
> restore presente, trial 7d, sem steering externo, `effectiveTier = max(backendTier, IAP)` (3.1.3b).

## Guidelines (o que cada uma exige de fato)
- **3.1.1** — conteúdo digital usado no app deve ser comprável via IAP. → Satisfeito quando as
  assinaturas estiverem LIVE (metadados completos) + ofertadas no paywall (já estão no código).
- **3.1.3(b)** — app multiplataforma pode honrar compra feita fora DESDE QUE também ofereça IAP. →
  `effectiveTier = max(backendTier, IAP)` + paywall com IAP = OK. Nenhum link de compra externa.
- **5.1.1(v)** — exclusão de conta in-app, real. → `DeleteAccountView` → `DELETE /api/me/delete-account`
  → `auth.admin.deleteUser` → toast "Conta excluída com sucesso" → signOut. OK.

---

## PARTE 1 — Completar metadados de CADA assinatura (faz o "Faltam metadados" sumir)
Em **App Store Connect → seu app → Assinaturas → grupo "LaudoUSG Planos"**, clique em cada uma das
4 assinaturas e preencha TODOS os campos abaixo. Status só vira **"Pronto para envio"** com todos:

1. **Duração da assinatura** — já está (1 mês / 1 ano). ✔
2. **Preço da assinatura** — "Add Subscription Price" → escolher o preço em **BRL**
   (mensal Essencial R$99,90 · anual Essencial R$1019,90 · mensal Pro R$159,90 · anual Pro R$1629,90;
   confirmar com os preços do negócio). É um agendamento de preço por território.
3. **Localização (App Store Localization)** — adicionar **Português (Brasil)** com:
   - **Nome de exibição** da assinatura (ex.: "Essencial — Mensal").
   - **Descrição** (1–2 linhas do que o plano dá). ← campo mais esquecido; sem ele = "Faltam metadados".
4. **Informações de análise → Imagem de análise (screenshot) — OBRIGATÓRIA**:
   - Um print do **paywall** (PaywallSheet) mostrando o plano. Pode usar o MESMO screenshot do paywall
     para as 4 (só precisa exibir a compra). Sem screenshot = "Faltam metadados".
5. **Ofertas introdutórias → Avaliação gratuita (Free Trial) de 1 semana (P1W)** — para bater com o
   trial de 7 dias do código (`introductoryOffer` no `.storekit`).

> Dica: faça a "Profissional Mensal" 100% primeiro; depois replique exatamente nas outras 3.

## PARTE 2 — Localização do GRUPO (senão as 4 continuam em "Faltam metadados")
No grupo **"LaudoUSG Planos"** → **Localização do grupo de assinaturas** → adicionar Português (Brasil)
com o **nome de exibição do grupo** (ex.: "Planos LaudoUSG"). O "Nome de referência" é interno; o
grupo precisa do nome localizado que aparece na compra.

## PARTE 3 — Anexar à VERSÃO e enviar JUNTO com o build (a caixa azul do ASC)
1ª submissão de IAP **tem que ir com a versão**:
1. Garantir as 4 em **"Pronto para envio"** (Parte 1+2 completas).
2. Página da **versão** do app (build **147**) → seção **"Compras dentro de apps e assinaturas"** →
   **adicionar/selecionar as 4 assinaturas**.
3. Enviar a versão **com as assinaturas anexadas**. (Se não anexar, o revisor não testa o IAP → re-rejeição.)

## PARTE 4 — Testar em SANDBOX antes de enviar (evita a re-rejeição clássica)
- iPhone físico → Ajustes iOS → App Store → **Sandbox Account** (criar Sandbox Tester em ASC → Usuários e Acesso).
- Abrir o app (conta free) → paywall → confirmar que os **4 planos CARREGAM com preço + 7 dias grátis**
  e que a **compra completa** em sandbox, e o **Restaurar compras** funciona.
- Se o paywall vier vazio em sandbox = metadados/anexo ainda incompletos → corrigir antes de enviar.

## PARTE 5 — Build + conta demo + materiais do revisor
- **Bump build → 147**, Archive + Upload.
- **Conta demo = gratuita** (pra o revisor bater no paywall e ver o IAP).
- Colar **resposta + Review Notes + 2 vídeos** de `docs/apple-resubmissao-build147.md`.

---

## Riscos residuais que ainda re-rejeitam (checklist final)
- [ ] Alguma das 4 ficou em "Faltam metadados" → some o paywall no review.
- [ ] Assinaturas NÃO anexadas à versão 147.
- [ ] Paywall vazio em sandbox (não testou).
- [ ] Conta demo pré-assinada (revisor não vê o IAP) → usar conta free + Notes apontando o paywall.
- [ ] Faltou o screen recording do delete nas Notes.
- [ ] Preço não publicado / território Brasil ausente.

## Confirmações de código (não precisa mexer)
- IDs batem: `com.laudousg.LaudoUSG.{essential,pro}.{monthly,yearly}` (StoreManager == .storekit == ASC).
- `StoreManager`: `Product.products(for:)`, `purchase()`, `restore()` via `AppStore.sync()`.
- `PaywallSheet`: botões comprar + "Restaurar compras" + tratamento de produtos vazios.
- `AppState`: `effectiveTier = max(backendTier, store.entitlementTier)` (PlanTier: Int, Comparable).
- Sem nenhuma referência a compra externa (só o aviso padrão "Gerencie em Ajustes › Apple ID").
