# Auditoria UI / Estado — App iOS (2026-06-24)

> 3ª auditoria (Histórico, Analytics, Settings, ReportDetail, estado/navegação). Não-clínicos → posso corrigir com mais liberdade, mas valido tudo por compilação.

## 🔴 Crítico
- **#U1 Busca do Histórico só vê os 50 laudos carregados** (`HistoryView.swift:18-27` + `HistoryService.swift:4`). Busca client-side sobre `fetchRecentReports(limit:50)` → médico com >50 laudos busca termo antigo e recebe "nenhum resultado" embora exista. Sem paginação. **Fix:** enviar busca ao backend (`ilike`) ou paginar.
- **#U2 Autosave do laudo: gravações concorrentes fora de ordem** (`ReportDetailView.swift:38-60`). `textChanged` cancela só o debounce, não a `save()` em voo; sem guard de reentrância → PATCH antiga (texto curto) pode sobrescrever a nova. **Fix:** serializar (`guard !isSaving`) + re-disparar se mudou.

## 🟠 Alto
- **#U3 Perda de edição ao sair rápido** (`ReportDetailView.swift:42-47`). Debounce 1,2s sem flush ao alternar p/ "Visualizar" ou pop da navegação. **Fix:** `await vm.save()` ao sair da edição e em `onDisappear`.
- **#U4 Delete em lote parcial fica invisível** (`HistoryView.swift:69-84` + `HistoryService.swift:42`). DELETE `id=in.(...)` retorna 200 mesmo se RLS deixar parte; cliente remove todos localmente; no refresh reaparecem. **Fix:** `Prefer: return=representation` e remover só o confirmado.
- **#U5 Seleção não saneada no reload** (`HistoryView.swift:65-67`). Pull-to-refresh em modo seleção troca `reports` sem limpar `selectedIds` → contador mente. **Fix:** `selectedIds.formIntersection(...)` após load.

## 🟡 Médio
- **#U6/#U7 Reordenar/criar "Minhas Frases"** (`MyPhrasesView.swift:41-64,110`): PATCHes paralelos com `try?` engolido + `position` calculada na construção do sheet → ordem inconsistente. **Fix:** persistir sequencial + posição no save.
- **#U8 Toast da Sala zumbi ao entrar em seleção** (`HistoryView.swift:176-188`). **Fix:** limpar `lastSalaResult`/cancelar task ao trocar de modo.
- **#U9 Analytics heatmap:** `reports` limitado a 500 sem aviso; "média de minutos" conta laudos de pacientes diferentes como duração de exame. **Fix:** rotular como "cadência", documentar teto.
- **#U10 Métricas sem clamp** (`AnalyticsView.swift:241,266`): latência "600.0s" / editsRatio ">100%" sem saneamento. **Fix:** clamp.
- **#U11 Profile placeholder dispara gates legais por um flash** (`AppState.swift:33-47` + `AppShellView.swift:15-36`). `signIn` cria profile com nils → `showLegalGate/Onboarding` viram true até o perfil real chegar. **Fix:** manter `profile=nil`/flag `profileLoaded` até o fetch.
- **#U12 Analytics sem guard de reentrância** (`AnalyticsView.swift:12-28`): `.task` + `.refreshable` concorrentes intercalam `summary`/`reports`. **Fix:** guard `isLoading`/cancelar anterior.

## ✅ Verificado OK
Offset do calendário; `DeleteAccountView` (2 passos sólido); `PreferencesStore`; sem `fatalError`/`try!`/index sem checagem nessas telas.

## Plano
Lote seguro (não-clínico, posso fazer): #U3, #U5, #U11, #U12, #U8, #U10. Mais delicados (backend/serialização): #U1, #U2, #U4, #U6/#U7.
