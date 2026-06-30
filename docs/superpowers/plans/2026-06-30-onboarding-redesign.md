# Onboarding Redesign — Implementation Plan

> **For agentic workers:** projeto Swift/SwiftUI. NÃO há testes unitários de UI; validação = `xcodebuild ... -derivedDataPath /tmp/laudousg-build build` + `#Preview`. Commits frequentes. Steps em checkbox.

**Goal:** Dar ao onboarding uma camada fotográfica/humana nas 3 telas emocionais (boas-vindas, microfone, conclusão), com nome no lugar do e-mail e indicador de progresso, sem alterar o fluxo de 6 etapas.

**Architecture:** Componente reutilizável `OnboardingPhotoBackdrop` (foto full-bleed + gradiente + slot de conteúdo). Indicador de progresso vive como overlay único no `OnboardingFlow` (cobre as 6 telas, estilo adaptado a fundo escuro/claro — assim não tocamos nos steps funcionais). Saudação por nome via `UserProfile.greetingFirstName`.

**Tech Stack:** SwiftUI, Assets.xcassets, tokens do DesignSystem.

**Decisão divergente do spec §4:** o indicador de progresso fica no `OnboardingFlow` (overlay), não dentro do backdrop — reduz duplicação e evita mexer em FirstRecording/Processing/FirstLaudo.

---

### Task 1: Integrar as 3 imagens no Assets.xcassets

**Files:**
- Create: `LaudoUSG/Assets.xcassets/OnboardingWelcome.imageset/{Contents.json, OnboardingWelcome.png}`
- Create: `LaudoUSG/Assets.xcassets/OnboardingMic.imageset/{Contents.json, OnboardingMic.png}`
- Create: `LaudoUSG/Assets.xcassets/OnboardingDone.imageset/{Contents.json, OnboardingDone.png}`
- Source: `docs/design/onboarding-images/*.png` (já geradas, 1080×1920)

- [ ] Criar os 3 `.imageset` (mkdir), copiar cada PNG e escrever `Contents.json` (universal, single-scale, igual ao modelo `LaudoUSGLogoFont.imageset`).
- [ ] Validar: `find Assets.xcassets -name "Onboarding*"` lista os 3 PNGs + 3 jsons.

`Contents.json` (trocar o filename por imageset):
```json
{ "images" : [ { "filename" : "OnboardingWelcome.png", "idiom" : "universal" } ], "info" : { "author" : "xcode", "version" : 1 } }
```

### Task 2: `UserProfile.greetingFirstName`

**Files:** Modify `LaudoUSG/Core/AppState.swift` (struct `UserProfile`, perto de `avatarInitial` ~244)

- [ ] Adicionar computed: retorna primeiro nome real, ou `nil` se vazio/for e-mail.
```swift
/// Primeiro nome para saudação. nil quando só há e-mail (displayName cai no email
/// quando o cadastro não tem nome) — aí a UI usa saudação neutra.
var greetingFirstName: String? {
    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains("@") else { return nil }
    return trimmed.split(separator: " ").first.map(String.init)
}
```

### Task 3: Componente `OnboardingProgressDots`

**Files:** Create `LaudoUSG/Features/Onboarding/OnboardingProgressDots.swift`

- [ ] Indicador de N pontos; o ativo é uma cápsula alongada. `onDark` adapta cores (sobre foto vs sobre fundo claro).
```swift
import SwiftUI

struct OnboardingProgressDots: View {
    let index: Int
    let count: Int
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: i == index ? 18 : 6, height: 6)
                    .animation(.spring(duration: 0.35, bounce: 0.2), value: index)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Passo \(index + 1) de \(count)")
    }

    private func color(for i: Int) -> Color {
        if i == index { return onDark ? Color(hex: "34D399") : BrandColor.primary }
        return onDark ? Color.white.opacity(0.4) : AppSurface.border
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingProgressDots(index: 0, count: 6)
        OnboardingProgressDots(index: 2, count: 6, onDark: true).padding().background(.black)
    }.padding()
}
```

### Task 4: Componente `OnboardingPhotoBackdrop`

**Files:** Create `LaudoUSG/Features/Onboarding/OnboardingPhotoBackdrop.swift`

- [ ] Foto full-bleed + gradiente escuro + slot de conteúdo ancorado embaixo. Fallback escuro se a imagem faltar. Texto do conteúdo é responsabilidade de quem chama (cores claras).
```swift
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingPhotoBackdrop<Content: View>: View {
    let imageName: String
    @ViewBuilder var content: Content

    private var imageExists: Bool {
        #if canImport(UIKit)
        UIImage(named: imageName) != nil
        #else
        true
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if imageExists {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(hex: "0B0B0F")
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.88)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.md) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingPhotoBackdrop(imageName: "OnboardingWelcome") {
        Text("Bem-vindo, Luiz.").font(TextStyle.h1).foregroundStyle(.white)
        Text("Subtítulo de exemplo.").foregroundStyle(.white.opacity(0.88))
    }
}
```

### Task 5: Refatorar `WelcomeStep`

**Files:** Modify `LaudoUSG/Features/Onboarding/Steps/WelcomeStep.swift`

- [ ] Trocar layout claro por `OnboardingPhotoBackdrop(imageName: "OnboardingWelcome")`. Texto branco. Manter `shortName`/fallback. `OnboardingStepContainer` permanece no arquivo (usado pelos steps funcionais).
```swift
struct WelcomeStep: View {
    let doctorName: String        // recebe greetingFirstName ?? "" do flow
    let onStart: () -> Void

    var body: some View {
        OnboardingPhotoBackdrop(imageName: "OnboardingWelcome") {
            Text(greeting)
                .font(TextStyle.h1)
                .foregroundStyle(.white)
            Text("Vamos fazer seu primeiro laudo agora. Em 60 segundos você entende o fluxo inteiro.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)
            PrimaryButton(title: "Vamos lá", icon: "arrow.right") { onStart() }
                .padding(.top, Spacing.xs)
        }
    }

    private var greeting: String {
        let cleaned = doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Bem-vindo,\ndoutor(a)." }
        let first = cleaned.split(separator: " ").first.map(String.init) ?? cleaned
        return "Bem-vindo,\n\(first)."
    }
}
```
- [ ] Manter o `OnboardingStepContainer` definido neste arquivo (não remover).

### Task 6: Refatorar `MicPermissionStep`

**Files:** Modify `LaudoUSG/Features/Onboarding/Steps/MicPermissionStep.swift`

- [ ] Usar backdrop. Preservar a lógica `permissionDenied` (texto/CTA atuais). Sobre foto, os 3 itens de checklist viram texto branco translúcido.
```swift
var body: some View {
    OnboardingPhotoBackdrop(imageName: "OnboardingMic") {
        Text(permissionDenied ? "Microfone bloqueado." : "Pra ditar, preciso do microfone.")
            .font(TextStyle.h2).foregroundStyle(.white)
        Text(permissionDenied
             ? "Abra Ajustes do iOS, entre em LaudoUSG e ative Microfone. Você pode fechar agora e voltar depois."
             : "O áudio vira texto na hora. Não guardamos áudio nem dado de paciente.")
            .font(TextStyle.bodyLarge).foregroundStyle(.white.opacity(0.9)).lineSpacing(3)
        if permissionDenied {
            SecondaryButton(title: "Fechar onboarding", icon: "xmark") { onClose() }
        } else {
            PrimaryButton(title: "Permitir microfone", icon: "mic.fill",
                          isLoading: isRequesting, isDisabled: isRequesting) {
                onRequestPermission()
            }
        }
    }
}
```
- [ ] Remover o ícone/círculo e o checklist antigos do corpo (a foto carrega o visual). Manter os `#Preview` (ajustar se referenciarem membros removidos).

### Task 7: Refatorar `CompletionStep`

**Files:** Modify `LaudoUSG/Features/Onboarding/Steps/CompletionStep.swift`

- [ ] Usar backdrop + confete por cima. Texto branco. Aceitar nome opcional para o título.
```swift
struct CompletionStep: View {
    let isCompleting: Bool
    let errorMessage: String?
    let celebrationTrigger: Int
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            OnboardingPhotoBackdrop(imageName: "OnboardingDone") {
                Text("Foi assim.\nAgora é com você.")
                    .font(TextStyle.h1).foregroundStyle(.white)
                Text("Pra fazer o próximo laudo, é só tocar no botão verde da tela inicial.")
                    .font(TextStyle.bodyLarge).foregroundStyle(.white.opacity(0.9)).lineSpacing(3)
                if let errorMessage {
                    Text(errorMessage).font(TextStyle.body).foregroundStyle(.white)
                        .padding(Spacing.sm)
                        .background(SemanticColor.errorText.opacity(0.85), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }
                PrimaryButton(title: "Entrar no app", icon: "arrow.right",
                              isLoading: isCompleting, isDisabled: isCompleting) { onFinish() }
                    .padding(.top, Spacing.xs)
            }
            ConfettiCanvas(trigger: celebrationTrigger).allowsHitTesting(false).ignoresSafeArea()
        }
    }
}
```
- [ ] Manter `ConfettiCanvas` no arquivo. Remover o ícone de check e o card "Dica" antigos.

### Task 8: `OnboardingFlow` — overlay de progresso + nome

**Files:** Modify `LaudoUSG/Features/Onboarding/OnboardingFlow.swift`

- [ ] No `body` (ZStack), adicionar overlay topo com `OnboardingProgressDots(index: step.rawValue, count: OnboardingFlowStep.allCases.count, onDark: isPhotoStep)`.
- [ ] Computed `isPhotoStep`: `step == .welcome || step == .micPermission || step == .completion`.
- [ ] `WelcomeStep(doctorName:)` passa `app.profile?.greetingFirstName ?? ""`.
```swift
// dentro do ZStack(alignment: .topTrailing) { ... }, após currentStep:
.overlay(alignment: .top) {
    OnboardingProgressDots(
        index: step.rawValue,
        count: OnboardingFlowStep.allCases.count,
        onDark: isPhotoStep
    )
    .padding(.top, Spacing.sm)
}
// e:
private var isPhotoStep: Bool { step == .welcome || step == .micPermission || step == .completion }
```
- [ ] `OnboardingFlowStep` precisa ser `CaseIterable` (já é) para `allCases.count`.

### Task 9: Build e validação

- [ ] `xcodebuild -project LaudoUSG.xcodeproj -scheme LaudoUSG -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/laudousg-build build` → `** BUILD SUCCEEDED **`.
- [ ] Commit final.

---

## Self-Review

- **Cobertura do spec:** §3.1 telas fotográficas (Tasks 5-7) ✓ · §3.2 funcionais inalteradas + progresso via overlay (Task 8) ✓ · §3.3 indicador 6 pontos (Tasks 3,8) ✓ · §4 backdrop (Task 4) — indicador movido pro flow (documentado) ✓ · §5 nome (Tasks 2,5,8) ✓ · §6 assets (Task 1) ✓.
- **Sem placeholders:** todo step tem código real.
- **Consistência de tipos:** `OnboardingPhotoBackdrop(imageName:content:)`, `OnboardingProgressDots(index:count:onDark:)`, `UserProfile.greetingFirstName`, `OnboardingFlowStep.allCases` — usados de forma consistente entre tasks.
- **Risco:** cor branca de texto fixa nas telas fotográficas (correto — fundo é sempre a foto escura, independente de light/dark mode).
