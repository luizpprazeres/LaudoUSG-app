# CLAUDE.md

> Entrypoint para agentes (Claude Code, Codex/dex1) e devs retomando o projeto.
> **Última atualização:** 2026-05-17 — Sprint 3 fechado.

## O que é

App iOS nativo (SwiftUI) que permite médicos ultrassonografistas **ditarem achados e gerarem laudos por IA**. Frontend mobile de um produto que roda em produção em `laudousg.com`. Backend Next.js já existe e é consumido — **não recriar**.

## Status atual

- ✅ Sprint 0: Fundação (DesignSystem, Models, APIClient, RootView)
- ✅ Sprint 1: UI Shell navegável (Login, Generate, sheets, History/ReportDetail mock)
- ✅ Sprint 2: **End-to-end Abdome Total funcionando** (login Supabase real, Whisper transcrição, SSE generate streaming, auto-save)
- ✅ Sprint 3: Histórico real Supabase, edição inline auto-save, SettingsView style picker, SanityChecker (4 regras client-side, zero IA)
- ⏳ Sprint 4 (próximo): Calculadoras (IG ACOG + Doppler FMF), fontes Inter+Barlow embarcadas, dark mode polimento, haptics, push do laudo gerado pro ReportDetail

## Leia ANTES de codar

Ordem de leitura sugerida:
1. **`docs/ARCHITECTURE.md`** — stack, pipeline geração/transcrição, endpoints, lições aprendidas, decisões trancadas
2. **`docs/DESIGN_SYSTEM.md`** — tokens (cores, fontes, spacing), componentes, voz/tom
3. **Vault Obsidian** (canônico do produto inteiro): `/Users/luizprazeres/laugousg-vault/LaudoUSG/docs-projeto/` — **path tem typo intencional "laugousg"**. Comece pelo `context-map.md` (retrieval-first).

## Comandos essenciais

```bash
# Build via CLI (DerivedData isolado pra não conflitar com Xcode)
xcodebuild -project LaudoUSG.xcodeproj -scheme LaudoUSG \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/laudousg-build build

# Cache do Xcode corrompido (Cannot find 'XYZ' in scope)? Limpe:
osascript -e 'tell application "Xcode" to quit' && \
  rm -rf ~/Library/Developer/Xcode/DerivedData/LaudoUSG-* && \
  open /Users/luizprazeres/laudousg-swift/LaudoUSG/LaudoUSG.xcodeproj

# No Simulator depois de Cmd+R: Device → Microphone → Internal Microphone (precisa ativar pra mic funcionar)
```

## Onde está o que

```
LaudoUSG/                  ← código Swift
├── Core/                  Config + AppState global (@Observable @MainActor)
├── DesignSystem/          Tokens (cores, fontes, spacing, radii, shadows)
├── Models/                enum/struct puros (Category, Report, GenerateRequest, SSE event, etc)
├── Services/              actor/enum stateless (APIClient, Supabase, Auth, Speech, Sanity, etc)
├── Components/            UI compartilhada (Button, BrandLogo, Sheets/...)
└── Features/              Telas por feature (Auth, Generate, History, ReportDetail, Settings, Shell)
```

**Projeto usa `PBXFileSystemSynchronizedRootGroup`**: qualquer `.swift` dentro de `LaudoUSG/` é auto-incluído. Não mexa no pbxproj pra adicionar arquivos — só pra build settings.

## Decisões trancadas (não-negotiables)

Quebrar requer ADR explícito. Detalhes em `docs/ARCHITECTURE.md §9`.

- **Sanity check** = 100% síncrono, ZERO IA (rodando em `SanityChecker.swift`)
- **LGPD:** nada de dados sensíveis de paciente ou imagens no banco
- **Sem SDK Supabase** — REST direto via `SupabaseRESTClient` (URLSession puro)
- **Transcrição:** Whisper batch via `/api/transcribe` (Apple Speech falha no Simulator iOS 26 — não tente)
- **Backend `/api/generate`** (Vercel) — não recriar; só consumir
- **Bundle:** `com.laudousg.LaudoUSG`
- **3 estilos fixos** (Tradicional, Estruturado, Livre)

## Lições aprendidas (poupam tempo)

Resumo. Detalhes em `docs/ARCHITECTURE.md §11`.

1. SFSpeechRecognizer pt-BR **falha** no Simulator iOS 26 (`Failed to initialize recognizer`). Use Whisper batch (já implementado).
2. Simulator **não roteia mic do Mac** por default → ative `Device → Microphone → Internal Microphone` no menu do simulator.
3. **NÃO use** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` no pbxproj (removido no Sprint 2). Use `@MainActor` explícito.
4. **AppIcon DEVE ser 1024×1024 exato.** Resize com `sips -z 1024 1024 in.png --out out.png`.
5. **Re-leia o arquivo** depois de 2-3 Edits encadeadas — Edits cegas podem deixar `}` extra.
6. **Xcode com cache stale** → quit + apaga DerivedData + reabre (comando acima).
7. **Ruído nos logs** (`accessoryView.bottom`, `hapticpatternlibrary.plist`, `HALC_ProxyIOContext`) são bugs do simulator iOS 26, **NÃO** do nosso código. Ignore.

## Delegação Maestri / Codex

Codex (`dex1` no Maestri, OpenAI Codex v0.130 gpt-5.5 high YOLO) é forte em:
- Parsers determinísticos (SSE, JSON, regex)
- Componentes UI bem-escopados
- Validação de build via `xcodebuildmcp`
- Sanity rules síncronas

**Brief eficaz** (validado nos Sprints 1-3): 5 seções:
1. Contexto do produto (2-3 frases)
2. Arquivos existentes (paths absolutos + 1 linha cada)
3. Tarefas numeradas (path do arquivo + bullets)
4. Padrões (use tokens, zero comentários, #Preview)
5. Quando terminar (cole 20 primeiras linhas + rode build_sim)

```bash
maestri ask dex1 "$(cat <<'BRIEF'
... brief estruturado em 5 seções ...
BRIEF
)"
```

Timeout: 600000 (10min) para 3-5 arquivos UI; 900000 (15min) para parsers/services.

NÃO delegue ao Codex: decisões de arquitetura, integração com state global, julgamento UX, push/PR/devops.

## Anti-patterns (NÃO faça)

- **NÃO converta** código React Native pra Swift. Recriamos nativo.
- **NÃO recrie** logos. Reuse PNGs em `/Users/luizprazeres/laudousgmobile-def/apps/mobile/assets/brand/logos/`.
- **NÃO use** `print(...)`. Use `os.Logger(subsystem: "com.laudousg.LaudoUSG", category: "...")`.
- **NÃO armazene** dados de paciente no banco (LGPD).
- **NÃO introduza** LLM no sanity check.
- **NÃO mexa** em pbxproj pra adicionar arquivos (filesystem synced group cuida disso).
- **NÃO faça** Edits sequenciais cegas em um arquivo grande.

## Como retomar em 5 minutos

1. Lê esse arquivo (você está aqui)
2. Roda Cmd+B no Xcode pra confirmar que compila
3. Lê `docs/ARCHITECTURE.md §14` pra ver onde o último sprint parou
4. Pede `git log --oneline -20` pra ver últimas mudanças
5. Continua o próximo sprint ou pega backlog do `docs/ARCHITECTURE.md §14`

## Credenciais & URLs (não-segredo, são públicas e/ou do dev env)

- Backend: `https://laudousgmobile.vercel.app`
- Supabase: `https://yldtkqrsbgcnwlydrrot.supabase.co`
- Web em produção: `https://laudousg.com` (login dev: `luizp02121@gmail.com` / `teste123`)
- Anon key Supabase: em `LaudoUSG/Core/AppConfig.swift` (não é secret — é anon key pública, RLS protege)
