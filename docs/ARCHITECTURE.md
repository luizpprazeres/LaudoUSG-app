# LaudoUSG iOS — Arquitetura

> **Última atualização:** 2026-05-17 (Sprint 3 fechado)
> **Repo:** `/Users/luizprazeres/laudousg-swift/LaudoUSG`
> **Bundle:** `com.laudousg.LaudoUSG`
> **Audiência:** Claude Code, Codex, agentes Maestri, e Luiz quando retoma após pausa.

---

## 1. O que é

App iOS nativo (SwiftUI) para médicos ultrassonografistas **ditarem achados e gerarem laudos via IA**. Frontend mobile de um produto que já roda em produção em `laudousg.com`. Backend Next.js já existe em `https://laudousgmobile.vercel.app` — **não recriamos**, só consumimos.

Workflow do usuário:
1. Login Supabase (email/senha)
2. Escolhe categoria (Abdome Total, Tireoide, Mamária, …)
3. Dita achados pelo microfone OU digita texto
4. Toca "Gerar laudo" → SSE stream do `/api/generate` retorna o laudo token por token
5. Edita o laudo final → auto-save (debounced 1.2s)
6. Consulta histórico de laudos anteriores

---

## 2. Stack

| Camada | Escolha | Por quê |
|---|---|---|
| Linguagem | Swift 5.0 (toolchain Xcode 26) | Native iOS, performance e DX |
| UI | SwiftUI + `@Observable` (iOS 17+) | Sem ViewModels imperativos; reactividade automática |
| Deployment target | iOS 26.4 | Bleeding-edge; permite `@Previewable`, `NavigationStack`, novos APIs |
| Concurrency | Async/await + actors | Sem MainActor isolation default (removida no Sprint 2 — ver §11) |
| Networking | `URLSession` puro | Sem SDK de terceiros |
| Auth | Supabase Auth via REST direto (`/auth/v1/token?grant_type=password`) | Evita adicionar SPM ao pbxproj |
| Database | Supabase REST (`/rest/v1/*` com RLS) | Mesmo padrão do RN antigo |
| Geração de laudo | `/api/generate` (backend Vercel) com SSE streaming | Mesmo endpoint do site web |
| Transcrição | `/api/transcribe` (backend Vercel → OpenAI Whisper-1 batch) | Apple Speech falha no Simulator iOS 26 — ver §11 |
| Captura áudio | `AVAudioRecorder` AAC 16kHz mono | Output direto pro Whisper |
| Persistência sessão | `UserDefaults` (JWT + refresh + email + userId) | Simplicidade; futuro: Keychain |

---

## 3. Layout do filesystem

```
LaudoUSG/
├── LaudoUSG.xcodeproj/         Projeto Xcode (usa PBXFileSystemSynchronizedRootGroup —
│                                qualquer .swift dentro de LaudoUSG/ é auto-incluído)
└── LaudoUSG/
    ├── App/                     (vazio — entrypoint principal está direto na raiz)
    ├── LaudoUSGApp.swift        @main da app (apenas ContentView)
    ├── ContentView.swift        delega pro AppShellView
    ├── Core/
    │   ├── AppConfig.swift      URLs do backend, Supabase URL, anon key, locale pt-BR
    │   └── AppState.swift       Estado global @Observable @MainActor (session, profile, styles, defaultWritingStyleId)
    ├── DesignSystem/
    │   ├── Color+Tokens.swift   BrandColor + NeutralColor + SemanticColor + AppSurface (dynamic light/dark)
    │   ├── Font+Tokens.swift    BrandFont (Inter + Barlow) com fallback SF Pro
    │   ├── Spacing.swift        Spacing + Radius (4px grid)
    │   └── Shadows.swift        BrandShadow + .brandShadow(_:) extension
    ├── Models/
    │   ├── Category.swift       enum ReportCategory (30 cases, label, subtitle, tint, ícone SF, priority array dos 13)
    │   ├── WritingStyle.swift   enum WritingStyle + struct WritingStyleRecord (do backend)
    │   ├── Report.swift         Report + StructuredFindings + SanityResult + Measurement
    │   ├── GenerationStatus.swift  enum GenerationPhase (state machine de geração)
    │   ├── GenerateRequest.swift   POST body pro /api/generate (snake_case auto via encoder)
    │   └── GenerateSSEEvent.swift  Discriminated union dos 12 eventos SSE
    ├── Services/
    │   ├── APIClient.swift       actor singleton. GET/POST/postMultipart/streamSSE/patchRaw. Bearer JWT.
    │   ├── SupabaseRESTClient.swift  actor singleton. GET/PATCH no /rest/v1/*. apikey + Bearer.
    │   ├── AuthService.swift     actor. signIn/signOut/restoreSession via /auth/v1/token. Persiste em UserDefaults.
    │   ├── ProfileService.swift  enum estático. fetchProfile, fetchWritingStyles, updateDefaultWritingStyle.
    │   ├── HistoryService.swift  enum estático. fetchRecentReports, fetchReport, updateFinalOutput.
    │   ├── ReportService.swift   enum estático. generateStream() encadeia APIClient.streamSSE + SSEStreamer.
    │   ├── SSEStreamer.swift     enum estático. Bytes → AsyncThrowingStream<GenerateSSEEvent>.
    │   ├── SpeechService.swift   @Observable @MainActor. AVAudioRecorder → upload Whisper.
    │   └── SanityChecker.swift   enum estático. 4 regras SÍNCRONAS ZERO IA (placeholder, magnitude, lateralidade, datas).
    ├── Components/
    │   ├── BrandLogo.swift          Wordmark "LaudoUSG" + dot
    │   ├── PrimaryButton.swift      PrimaryButton + SecondaryButton + PressableButtonStyle
    │   ├── PlaceholderView.swift    Tela genérica "em construção"
    │   └── Sheets/
    │       ├── CategorySheet.swift  30 categorias com busca diacrítica
    │       ├── MenuSheet.swift      Menu lateral (Histórico, Analytics, Bib, Prefs, Seg, Sair)
    │       ├── PlusSheet.swift      Snippets (DUM, USG, frases por categoria)
    │       └── RecordingOverlay.swift  Waveform animado + timer + Cancelar/Parar
    ├── Features/
    │   ├── Auth/LoginView.swift
    │   ├── Generate/
    │   │   ├── GenerateView.swift   Tela principal: header + categoria + editor "infinite" + bottom toolbar
    │   │   └── GenerateViewModel.swift  @Observable @MainActor. Consome SSE, handle each event type.
    │   ├── History/HistoryView.swift   Lista real Supabase + pull-to-refresh
    │   ├── ReportDetail/ReportDetailView.swift  Fetch /api/reports/[id] + edição auto-save
    │   ├── Settings/SettingsView.swift   Picker de Writing Style + PATCH /api/me/profile
    │   └── Shell/
    │       ├── AppShellView.swift   Auth gate + carrega profile/styles após login
    │       └── Destination.swift    enum AppDestination (Hashable, pra NavigationStack path)
    └── Assets.xcassets/
        ├── AppIcon.appiconset/      3 PNGs 1024×1024 (light, dark, tinted)
        └── AccentColor.colorset/

docs/                              ← este arquivo + DESIGN_SYSTEM.md
CLAUDE.md                          ← entrypoint pra agentes
```

---

## 4. Pipeline de geração de laudo

```
USER no GenerateView
   │
   │ toca "Gerar laudo" → vm.generate(writingStyleId: app.defaultWritingStyleId)
   ▼
ReportService.generateStream(GenerateRequest)
   │
   │ POST https://laudousgmobile.vercel.app/api/generate
   │ Headers: Authorization Bearer <JWT>, Content-Type: application/json, Accept: text/event-stream
   │ Body: { raw_input, category_hint, writing_style_id, ... }
   ▼
APIClient.streamSSE → URLSession.AsyncBytes
   │
   ▼
SSEStreamer.stream → AsyncThrowingStream<GenerateSSEEvent>
   │
   │ for try await event in stream { vm.handle(event:) }
   ▼
GenerateViewModel.handle(event:)
   │
   │ .open(reportId)      → guarda lastReportId
   │ .heartbeat           → ignora
   │ .structured(findings) → ignora (Sprint 4: mostrar achados estruturados)
   │ .validator(ok, ...)   → se !ok, Sprint 4 trata clarify
   │ .clarify(questions)   → Sprint 4 mostra dialog
   │ .rag(blocks)          → ignora (Sprint 4: mostrar blocos usados)
   │ .warning(msg)         → lastError = msg
   │ .token(delta)         → streamedOutput += delta  ← STREAMING LIVE
   │ .sanity(result)       → ignora (vamos rodar SanityChecker próprio depois)
   │ .done(reportId,text)  → streamedOutput = text + SanityChecker.check() + phase = .done
   │ .blocked(reason)      → lastError + phase = .error
   │ .error(msg)           → lastError + phase = .error
   ▼
UI atualiza reativamente (@Observable)
```

**Tipos de evento SSE:** 12 (`open`, `heartbeat`, `structured`, `validator`, `clarify`, `rag`, `warning`, `token`, `sanity`, `done`, `blocked`, `error`). Contrato canônico em `/Users/luizprazeres/laudousgmobile-def/packages/shared/src/schemas/generate.ts`.

**Auto-save no histórico:** backend salva o report no Supabase ao chegar `.done`. App não precisa POST — só consome.

---

## 5. Pipeline de transcrição (Whisper batch)

```
USER toca 🎤 no GenerateView
   │
   ▼
vm.startRecording()
   │
   ▼
SpeechService.requestPermissions() → AVAudioApplication.requestRecordPermission
   │
   ▼
SpeechService.start()
   │
   │ AVAudioSession.setCategory(.playAndRecord, mode: .measurement)
   │ AVAudioRecorder cria laudousg-rec-<UUID>.m4a (AAC 16kHz mono 32kbps)
   │ Ativa overlay com waveform animado + timer
   ▼
USER fala...
   ▼
USER toca "Parar e usar" → vm.finishRecording()
   │
   │ Overlay fecha, phase = .transcribing, botão vira "Transcrevendo…"
   ▼
SpeechService.stop() retorna async String
   │
   │ recorder.stop(), valida duração ≥ 0.6s
   │ APIClient.postMultipart(/api/transcribe, fileURL, "audio", audio/m4a)
   │
   ▼ POST https://laudousgmobile.vercel.app/api/transcribe
   │   multipart/form-data com field "audio"
   │   Backend → OpenAI Whisper-1 com prompt médico pt-BR
   │   Response: { transcript: "..." }
   ▼
Texto cai em vm.inputText (append com \n se já tinha algo)
Arquivo temp deletado, AVAudioSession deactivated
phase = .ready
```

**Por que NÃO usamos SFSpeechRecognizer (Apple Speech):**
- iOS Simulator 26.4 falha em `Failed to initialize recognizer` pra `pt-BR` mesmo com permissões e `supportsOnDeviceRecognition = true`.
- Apple Speech vira **opcional** para device físico em Sprint 4+ (streaming live + zero custo API se funcionar).
- Tentar consertar isso no Simulator é perda de tempo.

---

## 6. Auth flow

```
Launch
   │
   ▼
AppShellView.task
   │
   ▼
AuthService.restoreSession()
   │
   │ Lê StoredSession do UserDefaults
   │ Valida expiresAt (com margem 60s)
   │ Se ok: APIClient.setToken + SupabaseRESTClient.setToken
   │
   ├── Sessão válida → app.signIn → loadPostLogin (profile + styles em paralelo)
   └── Sessão inválida/ausente → app.markChecked(signedIn: false) → LoginView
       │
       │ User submete email + senha
       ▼
       AuthService.signIn → POST /auth/v1/token?grant_type=password
       │ Headers: apikey: <anonKey>, Authorization: Bearer <anonKey>
       │ Body: { email, password }
       │ Response: { access_token, refresh_token, expires_in, user: {id, email} }
       ▼
       Persist + setToken nos dois clients + app.signIn → loadPostLogin
```

**Refresh token:** ainda não implementado. Quando JWT expirar (1h por default Supabase), próxima request dá 401 e user precisa relogar. **Backlog Sprint 4.**

---

## 7. Estado global (AppState)

`@Observable @MainActor final class AppState`:

```swift
var session: SessionState              // .checking / .signedOut / .authenticated
var profile: UserProfile?              // email + displayName
var defaultWritingStyleId: String      // do /api/me/profile, fallback "11111111..."
var availableStyles: [WritingStyleRecord]  // do /rest/v1/writing_styles
```

Injeção: `@Environment(AppState.self)` em qualquer view abaixo de `AppShellView`.

---

## 8. Endpoints consumidos

### Backend Vercel (`https://laudousgmobile.vercel.app`)

| Método | Path | Quem chama | Pra quê |
|---|---|---|---|
| POST | `/api/generate` | ReportService | SSE de geração de laudo |
| POST | `/api/transcribe` | SpeechService | Multipart audio → texto |
| GET | `/api/reports/[id]` | HistoryService | Detalhe de um laudo |
| GET | `/api/me/profile` | ProfileService | Perfil + default_writing_style_id |
| PATCH | `/api/me/profile` | ProfileService | Atualiza default_writing_style_id |

### Supabase REST direto (`https://yldtkqrsbgcnwlydrrot.supabase.co`)

| Método | Path | Quem chama | Pra quê |
|---|---|---|---|
| POST | `/auth/v1/token?grant_type=password` | AuthService | Login → JWT |
| GET | `/rest/v1/reports?select=...&order=created_at.desc&limit=50` | HistoryService | Listagem (RLS filtra user) |
| PATCH | `/rest/v1/reports?id=eq.<uuid>` | HistoryService | Atualiza final_output |
| GET | `/rest/v1/writing_styles?...` | ProfileService | Lista de estilos disponíveis |

Backend **não tem** `GET /api/reports` (listagem). Listing vai direto no Supabase com RLS.

---

## 9. Decisões trancadas (não-negotiables)

Replicadas/derivadas de `/Users/luizprazeres/laugousg-vault/LaudoUSG/docs-projeto/non-negotiables.md`. Quebrar requer ADR explícito.

| Regra | Razão |
|---|---|
| Sanity check 100% síncrono, ZERO IA | Detectar inconsistências determinísticas; LLM pra isso = vazio |
| Cota é incrementada ANTES do stream no backend | Sem rollback automático — proteção contra abuso |
| 13 categorias ativas (em `ACTIVE_CATEGORIES`) | Resto do enum existe mas não é ofertado no picker priority |
| **LGPD:** dados sensíveis de paciente NÃO armazenados | Não capturar nome, CPF, RG, etc. |
| **LGPD:** imagens NÃO armazenadas | Não enviamos JPEG/PNG de ultrassom |
| Disclaimer médico obrigatório | "Revise antes de assinar" sempre que mostrar laudo |
| Backend `gpt-4.1-mini` primário, fallback Groq `llama-3.3-70b` | LLM_API_KEY = Groq, OPENAI_API_KEY = OpenAI (separação) |
| Transcrição streaming: Deepgram nova-3 (futuro WS proxy) | Whisper-1 é fallback batch atual |
| 3 estilos de escrita fixos: Tradicional, Estruturado, Livre | PR #5 (preset global) rejeitado |

---

## 10. Como adicionar uma nova categoria

1. Adicione o case em `Models/Category.swift` `enum ReportCategory`
2. Adicione label, subtitle, tintHex, iconSystemName em todas as `var`s do enum
3. Se for prioritária, adicione ao array `ReportCategory.priority`
4. Verifique que o backend tem a categoria registrada (`ACTIVE_CATEGORIES`)
5. Pronto — picker, geração, histórico funcionam automaticamente

Nenhuma string hardcoded em outro arquivo. Tudo passa pelo enum.

---

## 11. Lições aprendidas (consultar antes de tocar nesses tópicos)

### 11.1 iOS Simulator 26 + SFSpeechRecognizer pt-BR
`Failed to initialize recognizer` mesmo com permissões OK e `supportsOnDeviceRecognition = true`. **Não tente debugar no Simulator.** Use Whisper batch via `/api/transcribe` (já implementado).

### 11.2 iOS Simulator e mic do Mac
Por default, simulator **não roteia** mic do Mac. Acessar: menu do simulator → **Device → Microphone → Internal Microphone**. Sem isso, 0 buffers chegam.

### 11.3 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
**Removido** do pbxproj no Sprint 2. Causava 12+ warnings sobre `AuthSession` Decodable em actor não-MainActor. Hoje usamos `@MainActor` explícito apenas onde precisa (AppState, ViewModels, SpeechService).

### 11.4 PBXFileSystemSynchronizedRootGroup
Projeto criado com Xcode 26 usa esse modo. **Qualquer `.swift` dentro de `LaudoUSG/`** é auto-incluído. Não mexa em pbxproj pra adicionar arquivos — só pra build settings (ex: `INFOPLIST_KEY_*`).

### 11.5 AppIcon precisa ser EXATAMENTE 1024×1024
Imagens não-quadradas causam warnings de build. Use `sips -z 1024 1024 input.png --out output.png` pra forçar.

### 11.6 Edits sequenciais cegas em arquivos grandes
Faz-Edit-faz-Edit-faz-Edit no mesmo arquivo sem reler pode resultar em `}` extras ou função fora da struct. Re-ler arquivo inteiro depois de 2-3 Edits encadeadas.

### 11.7 Cache de Xcode pode estar stale
Sintoma: arquivos existem no disco mas `Cannot find 'XYZ' in scope`. Fix:
```bash
osascript -e 'tell application "Xcode" to quit' && \
  rm -rf ~/Library/Developer/Xcode/DerivedData/LaudoUSG-* && \
  open <path>/LaudoUSG.xcodeproj
```

### 11.8 Build via `xcodebuildmcp` (do Codex) usa DerivedData isolado
Codex consegue compilar limpo mesmo quando Xcode local do user falha por cache. Útil pra validação cruzada.

---

## 12. Delegação Maestri (Codex)

Codex (`dex1` no Maestri, OpenAI Codex v0.130 gpt-5.5 high YOLO mode) é forte em:
- Parsers determinísticos (SSE, JSON, regex)
- Componentes UI bem-escopados
- Validação de build (`xcodebuildmcp`)
- Sanity rules síncronas

NÃO usar Codex pra:
- Decisões de arquitetura ou produto
- Integração com state global
- UX com julgamento

Brief eficaz (testado nos Sprints 1, 2, 3):
1. **Contexto do produto** (2-3 frases)
2. **Arquivos existentes** (paths absolutos + 1 linha cada)
3. **Tarefas numeradas** (path + bullets das exigências)
4. **Padrões de qualidade** (use tokens, zero comentários, #Preview, etc.)
5. **Quando terminar** (cole primeiras 20 linhas pra audit + rode build_sim)

Timeout `maestri ask dex1`: 600000ms (10min) para 3-5 arquivos UI; 900000ms (15min) para parsers complexos.

Padrão completo salvo em `/Users/luizprazeres/.claude/projects/-Users-luizprazeres-laudousg-swift-LaudoUSG/memory/feedback_codex_delegation.md`.

---

## 13. Referências externas (paths absolutos)

| Recurso | Path |
|---|---|
| Vault Obsidian (produto canônico) | `/Users/luizprazeres/laugousg-vault/LaudoUSG/docs-projeto/` (typo "laugousg") |
| Mapa retrieval-first do vault | `<vault>/context-map.md` |
| Non-negotiables produto | `<vault>/non-negotiables.md` |
| Design system canônico | `<vault>/design-system.md` |
| RN/Expo legado (referência, NÃO converter) | `/Users/luizprazeres/laudousgmobile-def/` |
| Backend Next.js (referência de contrato) | `<rn-legado>/apps/api/src/` |
| Prompts extraídos do laudousg.com | `<rn-legado>/_extraction/from-laudousg-original/` |
| Web em produção | `https://laudousg.com` (login `luizp02121@gmail.com` / `teste123`) |
| Backend mobile em produção | `https://laudousgmobile.vercel.app` |
| Supabase | `https://yldtkqrsbgcnwlydrrot.supabase.co` |

---

## 14. Status & roadmap (Sprints)

| Sprint | Status | Entregável principal |
|---|---|---|
| 0 | ✅ | Fundação: DesignSystem + Models + APIClient stub + RootView placeholder |
| 1 | ✅ | UI Shell navegável: Login, Generate, CategorySheet, MenuSheet, PlusSheet, RecordingOverlay, History (mock), ReportDetail (4 tabs) |
| 2 | ✅ | End-to-end Abdome Total: Login Supabase + Whisper transcrição + SSE generate live + auto-save |
| 3 | ✅ | Expansão: HistoryView real (Supabase REST), edição inline auto-save, SettingsView style picker, SanityChecker client-side (zero IA), ProfileService |
| 3.5 | ✅ | Documentação versionada (este doc + DESIGN_SYSTEM.md + CLAUDE.md) |
| 4 | pending | Calculadoras (IG ACOG + Doppler FMF) + PlusSheet snippets clicáveis + dark mode polimento + haptics + fontes Inter+Barlow embarcadas |
| 5+ | pending | Analytics real, Biblioteca clínica, Segurança/2FA, Sala do Auxiliar, billing Stripe |

### 14.1 Próximas categorias com prioridade

13 categorias estão hoje em `ReportCategory.priority` (Generate picker). Faltam **17** que existem no enum mas ainda não são oferecidas, e várias **não têm esquema/parser dedicado** (vs. o que já existe pra Tireoide, Mamária, Doppler venoso MMII). Lista priorizada por volume clínico esperado × custo de implementação:

| Prio | Categoria | Status atual | Próximo passo |
|---|---|---|---|
| **P0** | `OBSTETRICA` | No picker. Sem calculadora IG dedicada (só doppler) | Esquema biometria fetal: DBP/CC/CA/CF → IG Hadlock auto + percentis peso (Intergrowth-21st) |
| **P0** | `MORFOLOGICO` | No picker. Sem checklist anatômico | Checklist 20-22 sem: SNC, face, tórax, abdome, urinário, esquelético + status (visto/não visto) |
| **P0** | `MAMARIA` | Esquema mamário existe (BreastSchemaEditor) | Step 6: parser BI-RADS por lesão + recomendação automática (acompanhamento/biópsia) |
| **P0** | `PELVE_FEMININA` | No picker. Esquema miomas planejado (`roadmap-esquema-miomas.md`) | Implementar mockup FIGO PALM-COEIN + parser de miomas (já tem regex no backend) |
| **P1** | `DOPPLER_VENOSO_MMII_MEDIDAS` | Editor + parser existem (S19.15) | Cartografia visual pré-op safena magna/parva com calibres |
| **P1** | `DOPPLER_ARTERIAL_MMII` | No picker | Tabela ITB + segmentos (femoral/poplítea/tibiais) + classificação Rutherford |
| **P1** | `DOPPLER_RENAL` | No picker | Tabela IR/IP por rim + diferença esquerda/direita (estenose >70% se IR>0.8) |
| **P1** | `ESCROTAL` | No picker (S5+ planejado) | Esquema testicular L/R + checklist varicocele/hidrocele/microlitíase |
| **P2** | `PROSTATA_TRANSRETAL` | No picker | Volume PSA-density + zonas (periférica/transição) + classes BPH |
| **P2** | `PROSTATA_SUPRAPUBICA` | No picker | Volume + resíduo pós-miccional já existe na calc (S19.6) — wire-up |
| **P2** | `PARATIREOIDE` | No enum, sem priority | Reuso UI Tireoide + esquema 4 paratireoides + scintigraphy cross-ref |
| **P2** | `CERVICAL` | No enum, sem priority | Reuso parcial Tireoide + linfonodos por nível (Ia-VI) |
| **P2** | `GLANDULAS_SALIVARES` | No enum, sem priority | Esquema parótidas/submandibulares + sialolitíase |
| **P3** | `REGIAO_INGUINAL` | No enum, sem priority | Esquema canal inguinal + classificação hérnia (indireta/direta/femoral) |
| **P3** | `PAREDE_ABDOMINAL` | No enum, sem priority | Localização hérnia (umbilical/incisional) + medidas defeito |
| **P3** | `PARTES_MOLES` | No enum, sem priority | Generic lesion mapper (localização + dimensões + ecotextura) |
| **P3** | `TRANSFONTANELA` | No enum, sem priority | Neonatal: ventriculomegalia + hemorragia Papile + checklist anatômico |
| **P3** | `OCULAR` | No enum, sem priority | Biometria axial + relações vítreas |
| **P3** | `MUSCULOESQUELETICO_RARAS` | No enum, sem priority | Cobre indicações <5% (parede torácica, plexo braquial) |
| **P3** | `DOPPLER_FISTULA_AV` | No enum, sem priority | Hemodiálise: PSV anastomose + classificação maturação |

**P0 = 4 categorias** (alto volume + diferencial competitivo, próximas 3-4 sprints).
**P1 = 4 categorias** (alto volume mas wire-up de coisa já pronta no backend).
**P2 = 5 categorias** (volume médio, exigem trabalho de modelagem).
**P3 = 7 categorias** (cauda longa, agrupar em sprint de "completude").

---

## 15. Anti-patterns conhecidos (não faça)

- **Não converta** código React Native pra Swift. Recriamos nativo.
- **Não recrie** logos/identidade visual. Reuse PNGs de `/Users/luizprazeres/laudousgmobile-def/apps/mobile/assets/brand/logos/`.
- **Não adicione SDKs pesados** (Supabase Swift SDK, Alamofire, etc.) — REST direto é suficiente.
- **Não use** `print(...)` pra logging — use `os.Logger(subsystem: "com.laudousg.LaudoUSG", category: "...")`.
- **Não cuide** dos warnings de constraints do keyboard (`accessoryView.bottom`) — bug do iOS 26 simulator, não nosso.
- **Não tente** rodar SFSpeechRecognizer pt-BR no simulator — falha conhecida (§11.1).
- **Não armazene** dados sensíveis do paciente no banco (LGPD).
- **Não introduza** LLM no sanity check (§9).
- **Não dispare** push/PR pelo Codex — Codex é code editor + builder, não devops.
