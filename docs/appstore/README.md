# LaudoUSG — Materiais App Store Connect

Pasta com tudo pronto pra copiar/colar no App Store Connect quando estiver na hora.

## Índice

| Arquivo | O que tem | Onde usa no ASC |
|---|---|---|
| `app-store-description.md` | Descrição + texto promocional + keywords + URLs | App Information + Localization (Portuguese - Brazil) |
| `privacy-nutrition-labels.md` | Mapping completo dos 5 tipos de dados coletados + 25+ não-coletados | App Privacy → Data Types |
| `app-review-notes.md` | Notas pro reviewer + demo account credentials + setup SQL | App Review Information |
| `screenshots-checklist.md` | 5 cenas a capturar no Simulator iPhone 6.7" | App Information → Screenshots |
| `site-privacy.html` | HTML pronto pra publicar em laudousg.com/privacy | URL externa obrigatória pelo Apple §5.1 |
| `site-terms.html` | HTML pronto pra publicar em laudousg.com/terms | URL externa (linkar em App Information) |

## Manifest técnico no app

`LaudoUSG/PrivacyInfo.xcprivacy` — manifest exigido pela Apple desde iOS 17 declarando APIs sensíveis usadas (UserDefaults, FileTimestamp, etc.) + alinhamento com Privacy Nutrition Labels.

## Status do submit

- [ ] **Fase 1 (Setup técnico):** Bundle ID registrado + Signing OK + Archive de teste
- [ ] **Fase 2 (Conteúdo):** copiar materiais desta pasta pro ASC
- [ ] **Fase 3 (Build):** Archive → Upload pro App Store Connect → TestFlight
- [ ] **Fase 4 (Submit):** preencher Privacy Labels + demo account + submit pra review
- [ ] **Fase 5 (Apple Review):** aguardar 24-72h
- [ ] 🎯 **Live na App Store**

## Pricing combinado (pro futuro IAP — Sprint 12+)

- **Free:** 20 laudos vitalícios
- **Essencial:** R$ 99,90/mês
- **Pro:** temporariamente indisponível

> IAP não está no Sprint 11. Quando implementar, adicionar produtos no ASC → In-App Purchases e atualizar Terms (Cláusula 9).

## Categorias

- Primary: **Medicine**
- Secondary: **Productivity**

## Disponibilidade inicial

Apenas **Brasil**.
