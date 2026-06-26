# P7 — Deploy LaudoUSG.lab (Vercel + lab.laudousg.com)

> Guia passo-a-passo pra subir o painel admin em produção.
> Pré-requisito: build local passa (`pnpm --filter @laudousg/lab build` no monorepo).

---

## 1. Pré-requisitos

- Conta Vercel logada na CLI (`vercel login`) — provavelmente já tem, dado que `laudousgmobile.vercel.app` e `laudousg.com` já estão lá
- Acesso ao painel Vercel onde `laudousg.com` está gerenciado (mesma org)

---

## 2. Criar o projeto no Vercel (escolha um dos 2 caminhos)

### Caminho A — CLI (mais rápido, recomendado)

Do diretório do app:

```bash
cd /Users/luizprazeres/laudousgmobile-def/apps/lab
vercel link
```

A CLI vai perguntar:
- Set up and deploy? **Y**
- Which scope? → escolha a org onde `laudousg.com` está
- Link to existing project? **N**
- Project name? → `laudousg-lab` (ou similar)
- In which directory is your code located? → **`.`** (default, já estamos em apps/lab)

Após o link, faça o primeiro deploy de **preview** (não prod ainda):

```bash
vercel
```

A primeira build vai falhar por falta de env vars — esperado. Configure no passo 3 e depois faça `vercel --prod`.

### Caminho B — Dashboard

1. https://vercel.com/new
2. Import Git Repository → escolha o repo `laudousgmobile-def`
3. **Root Directory:** `apps/lab` (clique em **Edit** e selecione)
4. Framework Preset: Next.js (detectado automaticamente)
5. Build/Install: o `apps/lab/vercel.json` já tem os comandos certos — deixe os defaults
6. **Não clique Deploy ainda** — vá pra Settings → Environment Variables primeiro

---

## 3. Configurar Environment Variables

No dashboard do projeto → **Settings → Environment Variables**, adicione (todas com escopo Production + Preview + Development):

| Variável | Valor |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | (copiar do `.env` raiz do monorepo — `SUPABASE_URL`) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | (copiar `SUPABASE_ANON_KEY` do `.env` raiz) |
| `SUPABASE_SERVICE_ROLE_KEY` | (copiar `SUPABASE_SERVICE_ROLE_KEY` do `.env` raiz) |
| `BACKEND_API_URL` | `https://laudousgmobile.vercel.app` |
| `LAB_ADMIN_EMAIL` | `luizp02121@gmail.com` |
| `LAB_ADMIN_PASSWORD` | `teste123` |
| `ADMIN_EMAIL_WHITELIST` | `luizp02121@gmail.com,contato@luizprazeres.com.br` |
| `LAB_BASIC_AUTH_USER` | escolha um username (ex: `luiz`) |
| `LAB_BASIC_AUTH_PASS` | **escolha uma senha forte** (mín 16 chars aleatórios) |

⚠️ **Importante sobre LAB_BASIC_AUTH:** se essas duas vars estiverem vazias/ausentes, o painel fica **público**. Defina ambas pra ativar a proteção HTTP Basic Auth.

⚠️ **NÃO commitar valores** — `.env.local` está gitignored.

Pra copiar do `.env` raiz sem expor no terminal:

```bash
grep -E "^SUPABASE_URL=" /Users/luizprazeres/laudousgmobile-def/.env
grep -E "^SUPABASE_ANON_KEY=" /Users/luizprazeres/laudousgmobile-def/.env
grep -E "^SUPABASE_SERVICE_ROLE_KEY=" /Users/luizprazeres/laudousgmobile-def/.env
```

---

## 4. Deploy de produção

```bash
cd /Users/luizprazeres/laudousgmobile-def/apps/lab
vercel --prod
```

Ou no dashboard: clica em **Deploy**. O Vercel vai:
1. Clonar o monorepo
2. `cd ../..` (definido no `vercel.json`)
3. `pnpm install --frozen-lockfile`
4. `pnpm --filter @laudousg/lab build`
5. Servir o `.next` build

Build esperado: ~2-4min.

**Após sucesso, URL temporária:** `https://laudousg-lab-<hash>.vercel.app`

Teste essa URL com basic auth: o browser vai pedir user/pass — digite os de `LAB_BASIC_AUTH_USER`/`LAB_BASIC_AUTH_PASS`.

---

## 5. Configurar subdomínio `lab.laudousg.com`

Como `laudousg.com` **já está na Vercel** (confirmamos isso na P7.5.B.1), o setup é trivial:

1. Dashboard do projeto `laudousg-lab` → **Settings → Domains**
2. **Add Domain**
3. Digite `lab.laudousg.com` → **Add**
4. Vercel detecta que o domínio raiz `laudousg.com` está em outro projeto da mesma org → adiciona o registro CNAME automaticamente
5. SSL Let's Encrypt provisiona em ~30s
6. Pronto: `https://lab.laudousg.com` resolve

Se aparecer instrução manual de CNAME (improvável): valor é `cname.vercel-dns.com`, TTL 60s.

**Custo:** R$ 0,00 (Hobby plan suporta múltiplos projetos + subdomínios ilimitados + SSL automático).

---

## 6. Validação pós-deploy

Acesse `https://lab.laudousg.com` em **janela anônima** (pra não cachear basic auth):

- [ ] Browser pede basic auth → digite credenciais
- [ ] `/` Dashboard mostra números reais do Supabase (não os mocks 487/23/4.2)
- [ ] `/audit` lista as 50 gerações mais recentes
- [ ] Click em uma row → painel detalhe carrega sem erro
- [ ] `/reviewer` redirecione pro mais recente, com trechos coloridos
- [ ] `/changelog` lista os 11 marcos
- [ ] Click num marco → 2 abas funcionam (Médico & Negócios / Técnico)
- [ ] `/testbench` → ABRE, mas **NÃO TESTE GERAR LAUDO AINDA** (vai criar audit row em prod). Quando testar, será logado como `luizp02121@gmail.com`.
- [ ] `/blocks` → mostra tree filesystem (deve funcionar graças ao `outputFileTracingIncludes`)

Se algo falhar:
- **500 em /changelog**: o `outputFileTracingIncludes` não incluiu `docs/changelog/`. Investigar logs Vercel.
- **500 em /blocks**: mesmo, mas pra `packages/knowledge/snippets/`.
- **401 em todos**: basic auth env vars estão OK no Vercel?
- **/testbench falha**: `BACKEND_API_URL` setada corretamente? Backend tem `verifyJwt` funcionando?

---

## 7. Limitações conhecidas em prod (saber antes de testar)

1. **Editor read-only**: `fs.writeFileSync` falha porque filesystem do Vercel é read-only. Botão "Salvar" mostra badge `read-only` automaticamente. **Pra editar markdown, use o Lab em dev local** (P7.6.B futuro: migrar pra GitHub API).
2. **Testbench cria audits em prod**: cada "Gerar laudo" persiste no `generation_audit` do Supabase prod com user_id de Luiz. Use com moderação.
3. **Basic auth é client-cached**: pra trocar usuário, fechar e reabrir browser ou usar janela anônima.

---

## 8. Próximos sprints sugeridos pós-deploy

- **P7.6** — Auth real (Supabase magic link, substitui basic auth)
- **P7.5.B.6** — Re-ingest automático após Save no Editor
- **P7.5.B.7** — Editor com GitHub API (Save funciona em prod via commit no repo)
- **P7.C.3** — Automação de changelog (script gera draft a partir de git log)
- **P7.B** — `sala.laudousg.com` (apps/sala/)

---

## Troubleshooting

### Build falha com erro de pnpm-lock

Atualize o lock no monorepo antes:

```bash
cd /Users/luizprazeres/laudousgmobile-def
pnpm install --lockfile-only
git add pnpm-lock.yaml && git commit -m "chore: lock pos apps/lab"
git push
```

### `outputFileTracingIncludes` não inclui arquivos

Verificar build log do Vercel — deve ter trace de "Including files matching..." pros patterns configurados. Se não, revisar o glob no `next.config.ts`.

### Subdomain SSL pending

Aguardar 1-2min. Se persistir > 5min, abrir issue no dashboard Vercel → Domain → Refresh.
