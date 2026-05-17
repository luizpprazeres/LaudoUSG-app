# LaudoUSG iOS — Design System

> **Última atualização:** 2026-05-17
> **Single source of truth (produto inteiro):** `/Users/luizprazeres/laugousg-vault/LaudoUSG/docs-projeto/design-system.md`
> **Implementação iOS:** `LaudoUSG/DesignSystem/*.swift`
> **Filosofia:** médico-pra-médico. Direto. Sem firula. Sem emoji em UI funcional.

---

## 1. Cores

### 1.1 Brand (emerald)
Definidas em `Color+Tokens.swift` → `enum BrandColor`.

| Token | Hex | Uso |
|---|---|---|
| `BrandColor.primary` | `#059669` | **Botões primários**, links, accents |
| `BrandColor.primaryHover` | `#047857` | Hover/pressed, logo |
| `BrandColor.primaryDeep` | `#065F46` | Gradientes, área escura de marca |
| `BrandColor.primarySoft` | `#D1FAE5` | Filter chip ativo, avatar bg |
| `BrandColor.primaryBorder` | `#A7F3D0` | Bordas em contexto primário |
| `BrandColor.primaryTint` | `#ECFDF5` | Bg sutil, nav ativo, banners |
| `BrandColor.wordmark` | `#18533F` | Cor de "Laudo" do wordmark (light) |
| `BrandColor.wordmarkAccent` | `#4A8A6A` | Accent secundário do wordmark |
| `BrandColor.wordmarkDark` | `#6EE7B7` | Cor de "Laudo" no dark mode |

### 1.2 Neutros (gray scale)
`enum NeutralColor` em `Color+Tokens.swift`. 10 tons do `gray50` ao `gray900`. Usar:
- `gray900` títulos h1
- `gray700` labels formulário
- `gray500` nav inativo, terciário
- `gray400` placeholders
- `gray200` bordas
- `gray50` fundo de painel

### 1.3 Semantic
`enum SemanticColor`. Pares background + border + text:

| Contexto | Bg | Border | Text |
|---|---|---|---|
| Erro | `errorBg` `#FEF2F2` | `errorBorder` `#FECACA` | `errorText` `#B91C1C` |
| Aviso | `warningBg` `#FFFBEB` | `warningBorder` `#FDE68A` | `warningText` `#B45309` |
| Sucesso | `successBg` `#F0FDF4` | `successBorder` `#BBF7D0` | `successText` `#15803D` |
| Info | — | — | `info` `#2563EB` |

`errorAccent` `#FF3B30` para casos especiais (ex: tint do menu "Sair", botão "Parar e usar").

### 1.4 Surface (adaptativo light/dark)
`enum AppSurface`. **Sempre use estes pra background/text** — eles fazem light/dark dinâmico via `Color.dynamic(light:dark:)`.

| Token | Light | Dark | Quando |
|---|---|---|---|
| `AppSurface.background` | `#F2F2F7` | `#0B0B0F` | Fundo da tela inteira |
| `AppSurface.card` | `#FFFFFF` | `#1C1C1E` | Cards, sheets, inputs |
| `AppSurface.muted` | `gray50` | `#131316` | Painel interno |
| `AppSurface.border` | `gray200` | `#2C2C2E` | Bordas |
| `AppSurface.textPrimary` | `gray900` | `#FFFFFF` | H1, body principal |
| `AppSurface.textSecondary` | `gray600` | `#8E8E93` | Secundário |
| `AppSurface.textMuted` | `gray400` | `#636366` | Placeholder, footer caption |
| `AppSurface.wordmark` | `BrandColor.wordmark` | `BrandColor.wordmarkDark` | Wordmark |

**Regra:** texto sobre `AppSurface.card` ou `AppSurface.background` usa `AppSurface.textPrimary/Secondary/Muted` — NUNCA hex direto. Garante WCAG AA em ambos os modos.

### 1.5 Como adicionar nova cor
1. Adicione em `Color+Tokens.swift` no enum apropriado
2. Documente aqui com hex + uso
3. **NÃO** use `Color(hex: "...")` espalhado nas views — vire token.

---

## 2. Tipografia

`Font+Tokens.swift` define:
- `BrandFont.body(_:)` → família **Inter** com fallback SF Pro
- `BrandFont.display(_:)` → família **Barlow** com fallback SF Pro Rounded

**Aposentadas em 2026-04-26:** Space Grotesk, Playfair Display. **Não usar.**

### 2.1 Escala (em pt)
Acessar via `enum TextStyle` (presets prontos):

| Token | Tamanho | Família | Quando |
|---|---|---|---|
| `TextStyle.caption` | 12 | Inter Regular | Caption |
| `TextStyle.captionMedium` | 12 | Inter Medium | Label uppercase |
| `TextStyle.footnote` | 13 | Inter Regular | Subtítulos de row |
| `TextStyle.body` | 14 | Inter Regular | Body padrão |
| `TextStyle.bodyMedium` | 14 | Inter Medium | Botão, link |
| `TextStyle.bodySemibold` | 14 | Inter SemiBold | Botão primário |
| `TextStyle.bodyBold` | 14 | Inter Bold | — |
| `TextStyle.bodyLarge` | 16 | Inter Regular | Body de leitura |
| `TextStyle.bodyLargeMedium` | 16 | Inter Medium | Body destacado |
| `TextStyle.bodyLargeSemibold` | 16 | Inter SemiBold | Body com peso |
| `TextStyle.subtitle` | 18 | Inter SemiBold | Subtitle |
| `TextStyle.h3` | 20 | Barlow Bold | Header de seção |
| `TextStyle.h2` | 24 | Barlow Bold | Header de página |
| `TextStyle.h1` | 30 | Barlow ExtraBold | Título grande |
| `TextStyle.display` | 36 | Barlow ExtraBold | Hero |
| `TextStyle.hero` | 48 | Barlow ExtraBold | Marketing |

### 2.2 Fontes embarcadas (Inter + Barlow .ttf)
**Status:** ainda não embarcadas. Cai pra SF Pro / SF Pro Rounded até alguém arrastar os `.ttf` em `LaudoUSG/Resources/Fonts/` e adicionar `INFOPLIST_KEY_UIAppFonts` no pbxproj.

Quando embarcar:
- Inter: Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf, Inter-Bold.ttf
- Barlow: Barlow-Regular.ttf, Barlow-Medium.ttf, Barlow-SemiBold.ttf, Barlow-Bold.ttf, Barlow-ExtraBold.ttf

O `BrandFont` já detecta automaticamente via `UIFont.fontNames(forFamilyName:)` e usa a família custom se disponível, senão fallback.

---

## 3. Espaçamento (grid 4px)

`enum Spacing` em `Spacing.swift`:

| Token | Pt | Uso típico |
|---|---|---|
| `Spacing.zero` | 0 | — |
| `Spacing.xxs` | 4 | Gap micro entre label/value |
| `Spacing.xs` | 8 | Gap entre itens de HStack pequeno |
| `Spacing.sm` | 12 | Gap entre rows |
| `Spacing.md` | 16 | Padding padrão de card, gap entre seções pequenas |
| `Spacing.lg` | 24 | Padding de tela, gap entre seções grandes |
| `Spacing.xl` | 32 | Gap entre blocos hero |
| `Spacing.xxl` | 48 | Spacer vertical generoso |
| `Spacing.xxxl` | 64 | — |
| `Spacing.huge` | 96 | — |

### Radii
`enum Radius`:

| Token | Pt | Uso |
|---|---|---|
| `Radius.sm` | 4 | Tags pequenas |
| `Radius.md` | 6 | — |
| `Radius.lg` | 8 | Inputs, toolbar controls |
| `Radius.xl` | 12 | **Botões primários, cards, inputs de página** |
| `Radius.xxl` | 16 | **Modais, sheets, auth card** |
| `Radius.xxxl` | 24 | — |
| `Radius.pill` | 999 | Chip pill (segmented control) |

---

## 4. Shadows

`struct BrandShadow` em `Shadows.swift`. Use o modifier `.brandShadow(_:)`:

```swift
RoundedRectangle(...).fill(...).brandShadow(.md)
```

| Token | Pra |
|---|---|
| `.sm` | Botão secundário sutil |
| `.md` | Cards na lista |
| `.lg` | FAB (mic button) |
| `.xl` | Modais |
| `.cardHover` | Hover state com tint emerald |

---

## 5. Componentes

### 5.1 Botões — `Components/PrimaryButton.swift`
**PrimaryButton** (verde, full-width default):
```swift
PrimaryButton(
    title: "Gerar laudo",
    icon: "sparkles",        // SF Symbol, opcional
    isLoading: false,
    isDisabled: false
) { /* action */ }
```
- `BrandColor.primary` bg, branco texto
- minHeight 48, `Radius.xl`
- ProgressView (branco) durante `isLoading`
- `.opacity(0.5)` quando `isDisabled`
- `PressableButtonStyle` (scale 0.98 + opacity 0.92)

**SecondaryButton** (transparente com borda):
```swift
SecondaryButton(title: "Fechar", icon: "xmark") { /* action */ }
```
- `AppSurface.card` bg, `AppSurface.border` borda, `AppSurface.textSecondary` texto
- minHeight 40, `Radius.lg`
- Padding horizontal `Spacing.sm`

### 5.2 Cards
Padrão visual (não há componente — é convenção):
```swift
.padding(Spacing.md)
.background(
    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        .fill(AppSurface.card)
)
.overlay(
    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        .stroke(AppSurface.border, lineWidth: 1)
)
```

### 5.3 Sheets
Padrão: `VStack` raiz, `.background(AppSurface.background.ignoresSafeArea())`, `.presentationDetents([.large])`, `.presentationDragIndicator(.visible)`.

Header: `HStack { Text("Título").font(.subtitle); Spacer(); SecondaryButton("Fechar") }`. Padding `Spacing.md`.

### 5.4 BrandLogo
```swift
BrandLogo(size: .small)   // 18pt
BrandLogo(size: .medium)  // 26pt (padrão)
BrandLogo(size: .large)   // 36pt (login, splash)
```
Wordmark "Laudo" + "USG" + dot circular emerald.

### 5.5 PlaceholderView
Tela "em construção" genérica com ícone + título + mensagem:
```swift
PlaceholderView(title: "Analytics", icon: "chart.bar.fill", message: "...")
```

### 5.6 PressableButtonStyle
Aplicar em qualquer Button pra dar feedback de toque:
```swift
Button { ... } label: { ... }
    .buttonStyle(PressableButtonStyle())
```

---

## 6. Ícones

- **Padrão:** SF Symbols (`Image(systemName: "...")`).
- Brand específicos: BrandLogo (text-based, sem SVG).
- Pesos comuns: `.medium`, `.semibold`, `.bold`.
- Tamanhos: 12, 14, 16, 18, 20, 22, 24, 28 pt — match com escala do Tailwind w-3 a w-7.

**Mapeamento usado:**

| Conceito | SF Symbol |
|---|---|
| Menu | `line.3.horizontal` |
| Adicionar / Mais | `plus`, `plus.circle.fill` |
| Microfone | `mic`, `mic.fill` |
| Buscar | `magnifyingglass` |
| Gerar (sparkle) | `sparkles` |
| Disclosure | `chevron.right`, `chevron.up.chevron.down` |
| Sucesso | `checkmark.circle.fill` |
| Erro | `xmark.octagon.fill` |
| Aviso | `exclamationmark.triangle.fill`, `exclamationmark.bubble.fill` |
| Info | `info.circle.fill` |
| Calculadora | `function` |
| Logout | `rectangle.portrait.and.arrow.right` |
| Histórico | `clock` |
| Analytics | `chart.bar`, `chart.bar.fill` |
| Biblioteca | `books.vertical`, `books.vertical.fill` |
| Preferências | `slider.horizontal.3` |
| Segurança | `lock.shield`, `lock.shield.fill` |
| Copiar | `doc.on.doc` |
| Compartilhar | `square.and.arrow.up` |
| Empty state | `tray` |

---

## 7. Padrões de UI

### 7.1 Disclaimer médico (banner)
**Removido** da Generate em Sprint 3 (decisão do user). Aparece só em ReportDetail/footer da Login: "Seus laudos são privados. Revise antes de assinar."

### 7.2 Error card inline
`SemanticColor.errorBg` + `SemanticColor.errorBorder` + `SemanticColor.errorText`. Padding `Spacing.md`, `Radius.lg`. Sempre com botão "Dispensar" (✕).

### 7.3 Sanity card warning
Aparece após laudo gerado se `SanityChecker.check()` retorna issues. `SemanticColor.warningBg/Border/Text`. Lista de issues com severity ícone (critical = `xmark.octagon`, warning = `exclamationmark.triangle`).

### 7.4 Empty state
```
Image(systemName: "tray")
  .font(.system(size: 36, weight: .light))
  .foregroundStyle(AppSurface.textMuted)
Text("Nenhum [item] ainda. Crie o primeiro.")
  .font(TextStyle.body)
  .foregroundStyle(AppSurface.textSecondary)
```
**Centralizado**, sem boxes. Mensagem direta sem emoji.

### 7.5 Loading
`ProgressView()` (tint `BrandColor.primary` quando sobre fundo claro, `.white` quando sobre brand). Para refresh: `.refreshable { await ... }`.

### 7.6 GenerateView layout
- Header fixo (menu, logo, plus)
- Categoria card (não scrollável)
- Editor "tela infinita" — sem borda, blenda com AppSurface.background
- Bottom toolbar: `[+ small]` | `[Gerar laudo wide]` | `[🎤 small]`

### 7.7 Bottom toolbar
Sempre **3 elementos:** ícone secundário esquerdo (44pt circle) + botão primário central (wide) + ícone primário direito (44pt circle). Padding `Spacing.md` horizontal + `Spacing.sm` vertical.

---

## 8. Voz e tom

**Princípios:**
1. Direto. Sem rodeios. Verbo na primeira frase.
2. De igual pra igual. Médico falando com médico.
3. Autoridade clínica. Sem hype.
4. Foco no problema real (tempo, padronização).
5. Sem firula. Menos é mais.

**Microcopy canônico:**

| Contexto | Texto |
|---|---|
| Botão primário | "Gerar laudo" / "Salvar" / "Continuar" / "Cancelar" / "Excluir" / "Entrar" |
| Sucesso toast | "Laudo gerado." / "Laudo salvo." / "Configurações atualizadas." |
| Erro genérico | "Erro de conexão. Tente novamente." / "Falha ao salvar. Verifique seus dados." |
| Empty state | "Nenhum laudo ainda. Crie o primeiro." |
| Auth | "Faça login para continuar." / "10 laudos grátis. Sem cartão." |
| Disclaimer | "Seus laudos são privados." / "Revise antes de assinar." |
| Recording | "Toque em Parar e usar quando terminar." / "Transcrevendo…" |

**BANIDO em UI funcional:**
- Emojis (🚀 🎉 ⚡ etc.)
- "ops!", "eita", "vixe"
- "mágico", "milagre", "incrível", "revolucionário"
- "nobre profissional", "prezado Dr."
- "Vamos te ensinar"
- "tecnologia de ponta"
- "click here", "go" (use PT-BR: "Abrir", "Continuar")

---

## 9. Dark mode

App suporta light + dark adaptativo via `AppSurface.*`. Todas as views devem usar tokens do `AppSurface` — NUNCA hex direto. SwiftUI faz o switch automaticamente conforme `userInterfaceStyle` do sistema.

**Polimento dark mode:** Sprint 4. Hoje funciona mas alguns shadows e overlays podem precisar ajuste.

---

## 10. Acessibilidade

- **Sempre** `.accessibilityLabel("...")` em botões com só ícone
- **Contraste:** WCAG AA validado por construção dos tokens AppSurface
- **Tamanho de toque:** mínimo 44pt em iOS, garantido por `frame(minHeight: 48)` nos botões primários e `frame(width: 44, height: 44)` em ícones de toolbar
- **VoiceOver:** identifiable rows, grouping com `.accessibilityElement(children: .combine)` quando faz sentido
- **`prefers-reduced-motion`:** animações respeitam automaticamente

---

## 11. Quando criar um novo componente

✅ Crie quando:
- Pattern aparece em 3+ lugares
- Lógica não-trivial (animação, state interno)
- Quer testar isolado

❌ Não crie quando:
- É inline simples (HStack + Text + Image)
- Usado uma vez só
- Variações são pequenas (use parâmetros, não componentes separados)

Localização:
- **Visual reusável:** `Components/`
- **Sheet/Overlay reusável:** `Components/Sheets/`
- **View específica de feature:** `Features/<Feature>/`

Sempre termine com `#Preview`. Cada componente deve renderizar em isolado.

---

## 12. Referências externas

| Recurso | Path |
|---|---|
| Design system canônico do produto | `/Users/luizprazeres/laugousg-vault/LaudoUSG/docs-projeto/design-system.md` |
| Voz/tom completa | `<vault>/design-system.md §5` |
| Marca / logos PNG (reusar, não recriar) | `/Users/luizprazeres/laudousgmobile-def/apps/mobile/assets/brand/logos/` |
| ARCHITECTURE.md (pipeline + stack) | `docs/ARCHITECTURE.md` |
