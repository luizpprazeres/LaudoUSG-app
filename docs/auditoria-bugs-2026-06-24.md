# Auditoria de Bugs — App iOS Swift (2026-06-24)

> Auditoria automática do core (voz/Deepgram, geração/SSE, auth, concorrência). 12 bugs reais, do mais grave ao menos. Status: **mapeados, correção em andamento**.

## 🔴 Corrigir já (risco de laudo errado / perda de dado clínico)

### #1 CRÍTICA — Geração não-cancelável → laudo de um paciente sobre o de outro
`Features/Generate/GenerateViewModel.swift:349` — o `Task` de `generate()` não é guardado nem cancelado. Em `reset()` ou nova geração, o stream antigo continua e sobrescreve `streamedOutput/displayedOutput/lastReportId/phase` com o laudo errado.
**Fix:** `private var generateTask: Task<…>?`; cancelar em `generate`/`reset`; `guard !Task.isCancelled` antes de `handle(event:)`.

### #2 CRÍTICA — Fim da fala perdido (última medida some)
`GenerateViewModel.swift:302` — `finishRecording` lê `liveTranscript` após `stop()`, mas o `CloseStream` é assíncrono e o app não espera o `is_final` final; o último parcial (ex: "2,5 cm") não é promovido. Perde medida no laudo.
**Fix:** em `stop()`, aguardar `is_final` (timeout ~500ms) após `CloseStream`, ou promover `interimText`→`finalText` antes de encerrar.

### #10 MÉDIA — `done` com `finalText` vazio zera o laudo já transmitido
`GenerateViewModel.swift:448` — `.done` sobrescreve `streamedOutput`/`displayedOutput` incondicionalmente; se o `done` vier vazio/truncado, o laudo completo vira vazio (e é salvo).
**Fix:** só sobrescrever se `!finalText.trimmed.isEmpty` (ou se for ≥ o acumulado).

### #5 ALTA — Retry de 401 pode gerar/cobrar dois laudos
`Services/APIClient.swift:144,153` — retry cego do POST `/api/generate` após 401 pode criar 2 reports; multipart relê o `.m4a` do disco que pode já ter sido apagado.
**Fix:** SSE só refaz se nenhum `open`/byte recebido; multipart lê `Data` uma vez e reusa.

## 🟠 Robustez de áudio / sessão

### #3 ALTA — Interrupção de áudio para e nunca retoma
`Services/DeepgramLiveService.swift:430` — `handleInterruption` trata só `.began` (chama `stop()`); `.ended`/`shouldResume` ignorado. Siri/timer interrompe → ditado perdido silenciosamente.
**Fix:** tratar `.ended` com `shouldResume` (retomar ou avisar claramente).

### #6 ALTA — `start()` no erro deixa engine/sessão/tap vivos
`DeepgramLiveService.swift:142` — cleanup no `catch` depende de `isStreaming`/guard; tap pode ficar instalado e sessão ativa.
**Fix:** cleanup incondicional no `catch`; `stop()` idempotente.

### #7 MÉDIA — `pending` não zera na reconexão → dropa áudio
`DeepgramLiveService.swift:19-32,403` — `set(nil)` na reconexão não reseta `pending`; após reconexões o contador trava e descarta áudio válido (transcrição incompleta).
**Fix:** zerar `pending=0` em `set(_:)` ao trocar a conexão.

### #12 MÉDIA — Observers de interrupção podem duplicar / ordem invertida
`DeepgramLiveService.swift:418-452` — `start()` sem `stop()` registra observer duplicado; `Task{@MainActor stop()}` atrasado pode derrubar gravação recém-iniciada.
**Fix:** `unregisterNotifications()` idempotente antes de registrar; ou `NotificationCenter.notifications(named:)` com `for await` no ciclo de vida.

## 🟡 Auth / UX / estado

### #4 ALTA — Logout desnecessário a cada abertura (não tenta refresh)
`Services/AuthService.swift:459` — `restoreSession` retorna `nil` se o access token expirou, **sem chamar `refresh()`**; ignora o refresh token válido (semanas). Usuário deslogado toda vez que abre após ~1h.
**Fix:** se expirado mas há `refreshToken`, `try? await refresh()`; só `nil` se o refresh falhar.

### #9 MÉDIA — Logout espúrio sob concorrência de refresh
`AuthService.swift:384` — consumidor que só aguardou `refreshTask.value` e falhou chama `signOut()` mesmo que o criador tenha tido sucesso.
**Fix:** só `signOut()` no caminho que criou o task.

### #11 MÉDIA — Stream sem `done`/`error` → spinner infinito
`Services/SSEStreamer.swift:84` + `Models/GenerateSSEEvent.swift:55` — frame com tipo desconhecido/truncado é descartado em silêncio; se o stream acaba sem `done`/`error`, `phase` fica `.generating` pra sempre.
**Fix:** ao terminar sem `done/error/blocked`, tratar como erro; logar frames descartados.

### #8 MÉDIA — `liveTranscript` do VM é estado fantasma (sempre vazio)
`GenerateViewModel.swift:98` — setado só para `""`; o overlay lê `deepgram.liveTranscript`. Campo enganoso.
**Fix:** remover do VM ou espelhar de fato.

---

## Plano de correção
- **Lote 1 (na build 146, baixo risco):** #10, #4, #1, #11.
- **Lote 2 (build 147, exige teste de áudio no device):** #2, #5, #3, #6, #7, #12.
- **Lote 3 (limpeza):** #8, #9.
