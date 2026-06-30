# Redesign do Onboarding — Direção Fotográfica

> **Data:** 2026-06-29
> **Status:** Aprovado para implementação
> **Origem:** brainstorming com o Luiz (Visual Companion)

## 1. Contexto e problema

O onboarding atual (`Features/Onboarding/`) é um fluxo hand-holding de 6 etapas que faz o usuário **gerar um laudo real** na primeira sessão (welcome → microfone → gravação → processamento → 1º laudo → conclusão). Funcionalmente é bom, mas visualmente está **muito simples**: SF Symbols, círculos com verde-claro (`primaryTint`), tipografia h1/h2 e `PrimaryButton`, na paleta restrita preto/branco/verde do app. Zero imagens.

Objetivo: deixar o onboarding **mais criativo, colorido e humano**, com **imagens reais** que aproximem o usuário, **sem alterar o fluxo** de 6 etapas nem a lógica de geração.

## 2. Decisões (travadas no brainstorming)

| Dimensão | Decisão |
|---|---|
| Direção estética | **Fotográfica / cinematográfica** (vs artística/geométrica) |
| Composição | **Full-bleed imersivo**: foto cobre a tela, gradiente escuro inferior, texto branco + botão |
| Escopo das fotos | **Só as 3 telas emocionais**: Boas-vindas, Microfone, Conclusão |
| Telas funcionais | Gravação, Processamento e 1º Laudo **sem foto** (texto/laudo brigaria com imagem); herdam só os toques de cor |
| Mood das fotos | **Lifestyle caloroso/humano** — pessoas, emoção, luz quente |
| Cor | O "colorido" vem da **luz quente das fotos** + acento de progresso verde-claro. Sem inventar paleta nova. |
| Saudação | **Nome no lugar do e-mail** na tela de boas-vindas |

O contraste entre o onboarding (caloroso, fotográfico) e o app (minimalista verde) é **intencional**: o onboarding acolhe; o app é a ferramenta limpa do dia a dia.

## 3. Design das telas

### 3.1 Telas emocionais (full-bleed)

Padrão visual comum:
- Foto cobre toda a tela (full-bleed).
- Gradiente escuro de baixo pra cima garante contraste do texto **independente da foto**.
- Indicador de progresso no topo (3 pontos; ativo alongado em verde-claro `#34D399`).
- Conteúdo ancorado embaixo: título (branco, bold), subtítulo (branco 88%), botão.
- Botão de ação primária mantém o verde da marca (`BrandColor.primary`).

| Tela | Título | Subtítulo | Botão | Foto (conteúdo) |
|---|---|---|---|---|
| **Boas-vindas** | "Bem-vindo, **{nome}**." | "Vamos fazer seu primeiro laudo agora. Em 60 segundos você entende o fluxo." | "Vamos lá →" | Sonografista com transdutor + gestante na maca, luz quente |
| **Microfone** | "Pra ditar, preciso do microfone." | "O áudio vira texto na hora. Não guardamos áudio nem dado de paciente." | "Permitir microfone" | Close de mão com celular / médico ditando, ondas de voz |
| **Conclusão** | "Pronto, {nome}!" | "Seu primeiro laudo está salvo no histórico. É assim, rápido, todos os dias." | "Começar a usar →" | Médico satisfeito/sorrindo, ambiente acolhedor |

O estado **microfone bloqueado** (`permissionDenied`) mantém a foto, mas troca texto/CTA para a orientação de Ajustes já existente (mensagem atual preservada).

### 3.2 Telas funcionais (sem foto)

`FirstRecordingStep`, `ProcessingStep`, `FirstLaudoStep` mantêm o layout atual focado no conteúdo. Recebem apenas:
- O mesmo indicador de progresso (ver §3.3).
- Coerência de espaçamento/tipografia com as telas novas.

Não há mudança funcional nessas telas.

### 3.3 Indicador de progresso

O fluxo tem 6 etapas (`OnboardingFlowStep`). O indicador mostra **6 pontos** (um por etapa), com o ponto da etapa atual alongado em verde-claro. Total = `OnboardingFlowStep.allCases.count`; índice = `rawValue` atual. Componente único, reutilizado por todas as telas (emocionais e funcionais).

## 4. Componentização

Para evitar duplicação e manter unidades bem-delimitadas:

- **Novo:** `Features/Onboarding/OnboardingPhotoBackdrop.swift` — view reutilizável que recebe `imageName: String` e um `@ViewBuilder` de conteúdo; renderiza foto full-bleed + gradiente + slot de conteúdo ancorado embaixo. Faz fallback gracioso (fundo escuro sólido) se a imagem não existir.
- **Novo:** `Features/Onboarding/OnboardingProgressDots.swift` — indicador de progresso. **Decisão de implementação:** vive como overlay único no `OnboardingFlow` (cobre as 6 telas, com `onDark` adaptando as cores), em vez de dentro do backdrop — evita duplicação e não toca nos steps funcionais.
- **Refatorar:** `WelcomeStep`, `MicPermissionStep`, `CompletionStep` para usar o `OnboardingPhotoBackdrop`.
- **Inalterado (estrutura):** `FirstRecordingStep`, `ProcessingStep`, `FirstLaudoStep` — só recebem o indicador de progresso.
- `OnboardingStepContainer` (hoje em `WelcomeStep.swift`) permanece para as telas funcionais.

## 5. Saudação por nome (corrigir o "e-mail")

**Causa:** `UserProfile.displayName` cai no e-mail quando o nome não vem (`AppState.swift:70` e `:120` usam `name ?? email`). O `WelcomeStep` então exibe o e-mail.

**Fix:**
- Adicionar a `UserProfile` um computed `var greetingFirstName: String?`:
  - Se `displayName` estiver vazio **ou contiver `@`** (é e-mail) → retorna `nil`.
  - Senão → primeiro token do `displayName`.
- `OnboardingFlow` passa `app.profile?.greetingFirstName` para Welcome/Conclusão.
- Quando `nil`, usar saudação neutra: **"Bem-vindo, doutor(a)."** / **"Pronto!"** (sem nome). Nunca exibir e-mail como se fosse nome.

## 6. Assets de imagem

- 3 imagens no `Assets.xcassets`: `OnboardingWelcome`, `OnboardingMic`, `OnboardingDone`.
- Geradas via **gpt-image2 no dex1/Maestri** (prompts na §7), proporção retrato 9:16, com **terço inferior "calmo"** (espaço para o gradiente/texto).
- Otimização: exportar comprimido (JPEG/HEIC de alta qualidade) para não inflar o bundle; full-bleed não exige PNG sem perdas.
- Unidade visual entre as 3: mesma paleta de luz quente, mesmo ambiente clínico, idealmente a **mesma profissional** como fio condutor.
- Acessibilidade: imagens são decorativas (o texto carrega a mensagem) → ocultar do VoiceOver ou `accessibilityLabel` curto; respeitar `reduceMotion` nas transições (já tratado no `OnboardingFlow`).

## 7. Prompts de imagem (gpt-image2)

Diretrizes comuns: fotografia realista, lifestyle médico caloroso, luz natural dourada, orientação **retrato 9:16 (1080×1920)**, **terço inferior mais limpo/escurecido** para sobreposição de texto, profundidade de campo suave, **sem nenhum texto na imagem**, diversidade representada com naturalidade, ambiente de clínica brasileira moderna.

1. **OnboardingWelcome** — "Médica ultrassonografista sorridente em sala de exame moderna e acolhedora, segurando um transdutor de ultrassom, ao lado de uma gestante deitada confortavelmente na maca. Luz natural quente entrando pela janela, tons dourados, atmosfera humana. Terço inferior limpo/escurecido para texto."

2. **OnboardingMic** — "Close-up da mesma médica segurando um smartphone próximo ao rosto, falando/ditando com expressão concentrada e tranquila, em ambiente clínico moderno com luz quente. Sutil glow/ondas sonoras ao redor do telefone sugerindo captura de voz. Terço inferior limpo/escurecido para texto."

3. **OnboardingDone** — "A mesma médica satisfeita e sorridente, segurando o smartphone, sensação de alívio e realização, em sala de exame acolhedora com luz dourada quente, atmosfera positiva. Terço inferior limpo/escurecido para texto."

## 8. Plano técnico (arquivos)

- `LaudoUSG/Features/Onboarding/OnboardingPhotoBackdrop.swift` — **novo** componente.
- `LaudoUSG/Features/Onboarding/Steps/WelcomeStep.swift` — usar backdrop + `greetingFirstName`.
- `LaudoUSG/Features/Onboarding/Steps/MicPermissionStep.swift` — usar backdrop (preservar estado `permissionDenied`).
- `LaudoUSG/Features/Onboarding/Steps/CompletionStep.swift` — usar backdrop + nome.
- `LaudoUSG/Features/Onboarding/Steps/{FirstRecording,Processing,FirstLaudo}Step.swift` — adicionar indicador de progresso.
- `LaudoUSG/Features/Onboarding/OnboardingFlow.swift` — passar `greetingFirstName` e `stepIndex/stepCount`.
- `LaudoUSG/Core/AppState.swift` — `UserProfile.greetingFirstName`.
- `LaudoUSG/Assets.xcassets/` — 3 imagens.

## 9. Não-objetivos (YAGNI)

- **Não** mexer no fluxo/lógica de geração do laudo de onboarding.
- **Não** introduzir a direção artística/geométrica (descartada).
- **Não** colocar foto nas telas funcionais.
- **Não** criar nova paleta de marca; cor extra vem das fotos + acento de progresso.
- **Não** mexer no onboarding `_LEGACY`.

## 10. Riscos e mitigações

- **Legibilidade sobre foto variável** → gradiente escuro garantido + terço inferior calmo nos prompts.
- **Peso do bundle** → imagens comprimidas.
- **Imagem ausente/erro de asset** → fallback de fundo escuro sólido no `OnboardingPhotoBackdrop`.
- **Foto "fria"/genérica do gpt-image2** → iterar prompt; manter consistência de personagem/luz entre as 3.
