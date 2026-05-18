# LaudoUSG — App Review Information

Conteúdo pra preencher em **App Store Connect → My Apps → LaudoUSG → App Review Information**.

---

## Contact Information

| Campo | Valor |
|---|---|
| First Name | Luiz Paulo |
| Last Name | de Souza Prazeres |
| Phone Number | (preencher) |
| Email | contato@laudousg.com |

---

## Demo Account (CRÍTICO — sem isso o reviewer não consegue entrar)

```
Email:    apple-review@laudousg.com
Password: ReviewLaudoUSG2026!
```

> ⚠️ Senha forte, mas fácil de digitar (sem caracteres ambíguos). Atualize aqui se mudar.

### Setup do demo account

Pra criar o demo account no Supabase, **delega ao Claude Code do Maestri** o seguinte:

```sql
-- 1. Criar user em auth.users (provisionado via Auth Admin API, NÃO direto em SQL)
-- Usar service_role via supabase.auth.admin.createUser na console MCP:
-- email: apple-review@laudousg.com
-- password: ReviewLaudoUSG2026!
-- email_confirm: true (pra dispensar confirmação por email no fluxo do reviewer)

-- 2. Após criar, popular profiles (id virá do auth.users.id, deixar Supabase preencher via trigger ou inserir manualmente):
INSERT INTO public.profiles (
  id, email, name, crm, uf, role, plan,
  terms_accepted_at,
  terms_version_accepted,
  privacy_version_accepted,
  medical_disclaimer_version_accepted,
  onboarding_completed_at,
  created_at, updated_at
)
SELECT
  u.id,
  'apple-review@laudousg.com',
  'Apple Reviewer',
  'REVIEW0001',
  'SP',
  'user',
  'free',
  NOW(),
  '1.2', '1.2', '1.2',
  NOW(),
  NOW(), NOW()
FROM auth.users u
WHERE u.email = 'apple-review@laudousg.com'
ON CONFLICT (id) DO UPDATE SET
  terms_accepted_at = EXCLUDED.terms_accepted_at,
  terms_version_accepted = EXCLUDED.terms_version_accepted,
  privacy_version_accepted = EXCLUDED.privacy_version_accepted,
  medical_disclaimer_version_accepted = EXCLUDED.medical_disclaimer_version_accepted,
  onboarding_completed_at = EXCLUDED.onboarding_completed_at;

-- 3. Verificar
SELECT id, email, name, crm, uf, terms_accepted_at
FROM public.profiles
WHERE email = 'apple-review@laudousg.com';
```

**Resultado esperado:** reviewer entra com email/senha, **pula confirm email + aceite legal + onboarding** (todos pré-aceitos via SQL acima) e cai direto na Generate.

> Não há validação real de CRM em runtime — `REVIEW0001/SP` é dummy, aceito.

---

## Notes (pro reviewer ler)

Copia o texto abaixo no campo "Notes":

```
LaudoUSG é um app B2C-profissional para médicos ultrassonografistas brasileiros, que dita os achados de um exame de ultrassonografia e recebe uma minuta de laudo estruturada por IA generativa. O médico revisa, edita e assina o laudo final — ele é sempre o responsável clínico.

ACESSO PARA REVIEW

Demo account pré-configurado (sem necessidade de confirmar email nem aceitar termos novamente — já pré-aceitos):

Email:    apple-review@laudousg.com
Password: ReviewLaudoUSG2026!

ROTEIRO DE TESTE SUGERIDO (5 minutos)

1. Abrir o app → Login com credentials acima.
2. Toque em "Selecionar categoria" → escolha "Abdome Total".
3. Toque no microfone (🎤) e dite por 10-15 segundos uma descrição genérica de achados (ex: "fígado com dimensões e ecotextura normais, vesícula biliar de paredes finas sem cálculos, vias biliares sem dilatação"). Toque "Parar e usar".
4. Aguarde a transcrição (~5 seg) → texto vai aparecer na aba ACHADOS.
5. Toque "Gerar laudo". O laudo será gerado por IA via streaming na aba LAUDO (~10-20 seg).
6. O laudo pode ser editado livremente. Há um footer obrigatório (não-dispensável) com aviso médico ao final do laudo.
7. Em Configurações → "Sobre o LaudoUSG", reviewer pode ver versão do app e abrir os documentos legais (Termos, Privacidade, Disclaimer Médico).
8. Em Configurações → "Excluir minha conta" — fluxo de exclusão de conta (Apple obriga apps com login a oferecer isso desde 2022).

OBSERVAÇÕES TÉCNICAS PARA O REVIEWER

— App requer autenticação. Não há modo guest.
— Categoria-alvo: médicos com CRM ativo em CRM brasileiro. Demo account tem CRM dummy aceito.
— O app NÃO armazena dados identificáveis de pacientes. Os achados ditados são despersonalizados por design e por contrato com o usuário (Cláusula 5.2 dos Termos).
— IA usada: OpenAI Whisper (transcrição) + OpenAI gpt-4.1-mini (geração de texto), via backend Vercel próprio. Áudio é enviado pra transcrição e descartado imediatamente.
— Permissões usadas: Microfone (pra ditado). Câmera está declarada no Info.plist mas NÃO é usada na versão atual — pode ser removida em build futuro.
— Deep link: laudousg:// usado pra confirmar email no signup e pra recuperar senha.

CONFORMIDADE

— LGPD (Lei 13.709/2018): documento Privacy Policy em laudousg.com/privacy
— Marco Civil da Internet
— Apple App Store Review Guidelines §5.1 (Privacy)
— Resolução CFM 2.314/2022 (Telemedicina) — aplicável quando há atos de telemedicina; este app é primariamente ferramenta de apoio à redação de laudos, não realiza atendimento remoto

Disclaimer médico explícito é exibido:
1. No signup (aceite obrigatório com checkbox)
2. No footer de todo laudo gerado (não-dispensável)
3. Em Configurações → Disclaimer Médico (disponível pra consulta)

Qualquer dúvida durante a review: contato@laudousg.com (respondemos em até 24h).

Obrigado.
```

---

## App Review Attachment

Não é obrigatório. Se quiser anexar, pode incluir:
- Print da tela de Configurações → "Sobre o LaudoUSG" com versão e build visíveis
- Print do fluxo de exclusão de conta funcionando

---

## Sign-In Information for Reviewer

Mesma info da seção "Demo Account" acima. ASC tem 2 campos separados (Demo Account no app review + Sign-In info) que preenchem com a mesma coisa.

---

## Notas sobre senha do demo account

A senha `ReviewLaudoUSG2026!` é válida pra primeira review. **Após app aprovado, recomenda-se trocar** a senha (a Apple pode armazenar credentials em sistema interno deles, e qualquer leak é risco).

Roteiro pós-aprovação:
1. Logar no Dashboard Supabase com seu user admin
2. Authentication → Users → procurar `apple-review@laudousg.com`
3. Reset password com nova senha gerada
4. Documentar nova senha aqui pra eventuais resubmits/atualizações de versão futuras
