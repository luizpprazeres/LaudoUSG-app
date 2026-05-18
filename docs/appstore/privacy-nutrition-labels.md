# LaudoUSG — Privacy Nutrition Labels (App Privacy)

Mapping completo dos dados coletados/não-coletados pra preencher em **App Store Connect → My Apps → LaudoUSG → App Privacy → Data Types**.

> **Critério Apple:** se houver discrepância entre o que você declara aqui e o que o app realmente faz, é motivo de rejeição. Mantenha alinhado com `PrivacyInfo.xcprivacy` (no bundle) e a Política de Privacidade pública.

---

## Pergunta inicial

**"Does this app collect data?"** → **YES** ✅

---

## Tipos de dados COLETADOS (declare estes)

### 1. Contact Info → Email Address

| Campo | Valor |
|---|---|
| Used for tracking? | **NO** |
| Linked to user identity? | **YES** (autenticação) |
| Purposes | **App Functionality** (autenticação, recuperação de senha, comunicação transacional) |

---

### 2. User Content → Audio Data

| Campo | Valor |
|---|---|
| Used for tracking? | **NO** |
| Linked to user identity? | **YES** (vinculado à sessão autenticada) |
| Purposes | **App Functionality** (transcrição de ditado via Whisper) |

> Nota a colocar no campo "How is this data used?" se houver: "Áudio é enviado para transcrição automática e descartado imediatamente após o processamento. Não é armazenado em servidores."

---

### 3. User Content → Other User Content

| Campo | Valor |
|---|---|
| Used for tracking? | **NO** |
| Linked to user identity? | **YES** |
| Purposes | **App Functionality** (texto dos ditados, laudos gerados, frases customizadas — armazenados no histórico do usuário) |

---

### 4. Identifiers → User ID

| Campo | Valor |
|---|---|
| Used for tracking? | **NO** |
| Linked to user identity? | **YES** |
| Purposes | **App Functionality** (UUID Supabase Auth do usuário, vinculado à Conta) |

> Não declarar Device ID — não usamos IDFA nem IDFV pra propósitos publicitários.

---

### 5. Other Data → Other Data Types

| Campo | Valor |
|---|---|
| Used for tracking? | **NO** |
| Linked to user identity? | **YES** |
| Purposes | **App Functionality** (nome completo, CRM e UF do médico — necessários pra elegibilidade profissional) |

> Apple não tem categoria específica pra "informação profissional". Esse campo "Other Data Types" cobre.

---

## Tipos de dados NÃO COLETADOS (NÃO marcar)

⚠️ **Não marque** nenhum desses no questionário do ASC:

### Contact Info
- Phone Number — NÃO
- Physical Address — NÃO
- Other Contact Info — NÃO

### Health & Fitness
- Health — NÃO (não usamos HealthKit nem coletamos dados de saúde do usuário-médico)
- Fitness — NÃO

### Financial Info
- Payment Info — NÃO (pagamento de IAP futuro é processado pela Apple, não nós)
- Credit Info — NÃO
- Other Financial Info — NÃO

### Location
- Precise Location — NÃO
- Coarse Location — NÃO

### Sensitive Info
- Sensitive Info — NÃO

### Contacts
- Contacts — NÃO

### User Content (não cobertos acima)
- Emails or Text Messages — NÃO
- Photos or Videos — NÃO (não coletamos imagens médicas nem fotos)
- Customer Support — NÃO (suporte é via email externo, sem coleta in-app)
- Gameplay Content — NÃO

### Browsing History
- Browsing History — NÃO

### Search History
- Search History — NÃO

### Identifiers (não cobertos acima)
- Device ID — NÃO (não usamos IDFA/IDFV)

### Purchases
- Purchase History — NÃO (Apple processa, não temos histórico próprio até IAP)

### Usage Data
- Product Interaction — NÃO (não temos analytics implementado ainda)
- Advertising Data — NÃO
- Other Usage Data — NÃO

### Diagnostics
- Crash Data — NÃO (não usamos Crashlytics/Sentry/similar ainda)
- Performance Data — NÃO
- Other Diagnostic Data — NÃO

---

## Tracking

**Question:** "Does your app track users?"

→ **NO** ✅

Tracking no contexto Apple = linkar dados deste app com dados de outras apps ou sites de terceiros pra publicidade ou compartilhamento com data brokers. **Nada disso fazemos.**

→ **App Tracking Transparency (ATT) prompt: NÃO necessário.**

---

## Resumo final (como vai aparecer pro usuário na App Store)

Após preencher tudo acima, a Apple gera os "Privacy Nutrition Labels" mostrados no App Store. Esperado:

> **Data Linked to You**
> - Contact Info (Email)
> - User Content (Audio, Other)
> - Identifiers (User ID)
> - Other Data

> **Data Not Linked to You**
> - (nenhum)

> **Data Used to Track You**
> - (nenhum)

Esse perfil é **honesto, compatível com app médico profissional** e não levanta red flags na review.

---

## Atualizações futuras

Quando adicionar:

| Feature | Atualizar Labels |
|---|---|
| IAP (Sprint 12+) | Adicionar "Purchases → Purchase History" |
| Push notifications | Já coberto por Device ID se necessário (provavelmente não) |
| Crashlytics/Sentry | Adicionar "Diagnostics → Crash Data" + "Performance Data" |
| Analytics (Mixpanel/PostHog) | Adicionar "Usage Data → Product Interaction" |

Cada mudança nos dados coletados requer **resubmit dos Labels** no ASC (sem precisar nova versão do app necessariamente — Labels são atualizáveis separadamente).
