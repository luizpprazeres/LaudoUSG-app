import SwiftUI
import Combine

/// Sheet compacto do "Ajustar laudo".
///
/// Abre já ouvindo; o médico fala, toca "Ajustar", confere a prévia (antes riscado,
/// depois destacado) e aplica — ou descarta. Recusa do servidor mostra o motivo
/// com o aviso de que o laudo não foi alterado.
struct AdjustLaudoSheet: View {
    @Bindable var model: AdjustLaudoModel
    let onSubmit: (_ targetOverride: AdjustTarget?) -> Void
    let onApply: () -> Void
    let onDismiss: () -> Void

    @State private var detent: PresentationDetent = AdjustLaudoSheet.compactDetent
    @State private var isTyping = false
    @State private var showsProposal = false
    @FocusState private var isFieldFocused: Bool

    static let compactDetent = PresentationDetent.height(330)
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            switch model.phase {
            case .composing, .failed:
                composer
            case .submitting:
                submitting
            case .preview(_, let changes):
                preview(changes)
            case .rejected(let rejection, let proposal):
                rejected(rejection, proposal: proposal)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppSurface.background)
        .presentationDetents([AdjustLaudoSheet.compactDetent, .medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.disabled)
        .onReceive(ticker) { _ in model.tick() }
        .onChange(of: phaseKey) { _, key in
            withAnimation(.easeOut(duration: 0.2)) {
                detent = (key == "preview" || key == "rejected") ? .medium : AdjustLaudoSheet.compactDetent
            }
            if key == "composing" { showsProposal = false }
        }
        .onAppear {
            if model.prefersTyping {
                isTyping = true
                isFieldFocused = true
            }
            detent = (phaseKey == "preview" || phaseKey == "rejected") ? .medium : AdjustLaudoSheet.compactDetent
        }
    }

    private var phaseKey: String {
        switch model.phase {
        case .composing: return "composing"
        case .submitting: return "submitting"
        case .preview: return "preview"
        case .rejected: return "rejected"
        case .failed: return "failed"
        }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Text(title)
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer(minLength: Spacing.xs)
            if phaseKey == "composing" || phaseKey == "failed" {
                targetMenu
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppSurface.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppSurface.muted))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Fechar sem ajustar")
        }
    }

    private var title: String {
        switch model.phase {
        case .preview: return "Confira o ajuste"
        case .rejected: return "Ajuste não aplicado"
        default: return "Ajustar laudo"
        }
    }

    /// Alvo fica escondido num chip: "Automático" resolve quase sempre.
    private var targetMenu: some View {
        Menu {
            Picker("Onde ajustar", selection: $model.targetChoice) {
                ForEach(AdjustTargetChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(model.targetChoice == .automatic ? "Onde: automático" : "Onde: \(model.targetChoice.label.lowercased())")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(TextStyle.caption)
            .foregroundStyle(AppSurface.textSecondary)
            .padding(.horizontal, Spacing.xs)
            .frame(minHeight: 26)
            .background(Capsule().stroke(AppSurface.border, lineWidth: 1))
        }
        .accessibilityLabel("Onde aplicar o ajuste")
    }

    // MARK: - Ditado

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let anchor = model.anchor {
                anchorQuote(anchor)
            }

            ZStack(alignment: .topLeading) {
                if isTyping {
                    TextField("Ex.: troque a frase do líquido, ILA 10,4", text: $model.instruction, axis: .vertical)
                        .font(TextStyle.bodyLarge)
                        .lineLimit(2...4)
                        .focused($isFieldFocused)
                        .submitLabel(.done)
                } else if model.trimmedInstruction.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(model.isListening ? "Fale o ajuste…" : "Toque no microfone e fale o ajuste.")
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(AppSurface.textMuted)
                        Text("Ex.: \u{201C}acrescente cisto simples de 2 cm no rim direito\u{201D}")
                            .font(TextStyle.footnote)
                            .foregroundStyle(AppSurface.textMuted)
                    }
                } else {
                    Text(model.instruction)
                        .font(TextStyle.bodyLarge)
                        .foregroundStyle(AppSurface.textPrimary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(AppSurface.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(model.isListening ? BrandColor.primary.opacity(0.6) : AppSurface.border, lineWidth: 1)
            )

            statusLine

            HStack(spacing: Spacing.sm) {
                Button {
                    Haptics.tap()
                    isTyping = false
                    isFieldFocused = false
                    Task { await model.toggleListening() }
                } label: {
                    Image(systemName: model.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(model.isListening ? .white : BrandColor.primary)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(model.isListening ? SemanticColor.errorAccent : BrandColor.primarySoft))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(model.isListening ? "Parar o ditado" : "Ditar o ajuste")

                Button {
                    Haptics.tap()
                    Task {
                        await model.stopListening()
                        isTyping = true
                        isFieldFocused = true
                    }
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppSurface.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(AppSurface.card))
                        .overlay(Circle().stroke(AppSurface.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Digitar o ajuste")

                PrimaryButton(
                    title: "Ajustar",
                    isDisabled: model.trimmedInstruction.count < 2
                ) {
                    Haptics.press()
                    isFieldFocused = false
                    onSubmit(nil)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if case .failed(let message) = model.phase {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(TextStyle.footnote)
                .foregroundStyle(SemanticColor.errorText)
        } else if let micError = model.micError {
            Label(micError, systemImage: "mic.slash")
                .font(TextStyle.footnote)
                .foregroundStyle(SemanticColor.warningText)
        } else if model.isListening {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(SemanticColor.errorAccent)
                    .frame(width: 8, height: 8)
                Text("Ouvindo")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                Text("· você confere antes de aplicar")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                    .lineLimit(1)
            }
        } else {
            Text("Só o trecho pedido muda. Você confere antes de aplicar.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
        }
    }

    private func anchorQuote(_ anchor: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(BrandColor.primary)
                .frame(width: 3)
            Text(anchor)
                .font(TextStyle.footnote)
                .foregroundStyle(AppSurface.textSecondary)
                .lineLimit(2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Trecho escolhido: \(anchor)")
    }

    // MARK: - Enviando

    private var submitting: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            echo(model.sentInstruction)
            HStack(spacing: Spacing.xs) {
                ProgressView().controlSize(.small).tint(BrandColor.primary)
                Text("Ajustando só o trecho pedido…")
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textSecondary)
            }
            .padding(.top, Spacing.xs)
        }
    }

    private func echo(_ instruction: String) -> some View {
        Text("\u{201C}\(instruction)\u{201D}")
            .font(TextStyle.footnote)
            .italic()
            .foregroundStyle(AppSurface.textSecondary)
            .lineLimit(3)
    }

    // MARK: - Prévia

    private func preview(_ changes: [LaudoDiff.Change]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            echo(model.sentInstruction)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(changes) { change in
                        AdjustDiffCard(change: change, dimmed: false)
                    }
                    Text(changes.count == 1 ? "1 linha muda. O restante do laudo fica igual." : "\(changes.count) linhas mudam. O restante do laudo fica igual.")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                        .padding(.top, Spacing.xxs)
                }
            }
            .scrollIndicators(.hidden)

            HStack(spacing: Spacing.sm) {
                SecondaryButton(title: "Descartar") {
                    Haptics.tap()
                    onDismiss()
                }
                .frame(width: 120)
                PrimaryButton(title: "Aplicar", icon: "checkmark") {
                    onApply()
                }
            }
        }
    }

    // MARK: - Recusa

    private func rejected(_ rejection: AdjustRejection, proposal: [LaudoDiff.Change]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label(AdjustRejection.intactNotice, systemImage: "checkmark.shield.fill")
                    .font(TextStyle.bodySemibold)
                    .foregroundStyle(AppSurface.textPrimary)
                Text(rejection.title)
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(SemanticColor.warningText)
                Text(rejection.message)
                    .font(TextStyle.footnote)
                    .foregroundStyle(AppSurface.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                echo(model.sentInstruction)
                    .padding(.top, Spacing.xxs)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(SemanticColor.warningBg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(SemanticColor.warningBorder, lineWidth: 1)
            )

            if !proposal.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { showsProposal.toggle() }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: showsProposal ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("Ver o que a IA tentou mudar")
                    }
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                }
                .buttonStyle(.plain)

                if showsProposal {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(proposal) { change in
                                AdjustDiffCard(change: change, dimmed: true)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: Spacing.sm) {
                SecondaryButton(title: "Ditar de novo", icon: "mic") {
                    model.restart(listen: true)
                }
                if let retryTarget = rejection.retryTarget, let retryLabel = rejection.retryLabel {
                    PrimaryButton(title: retryLabel) {
                        onSubmit(retryTarget)
                    }
                }
            }
        }
    }
}

/// Uma linha alterada: antes (riscado) e depois (destacado), palavra a palavra.
struct AdjustDiffCard: View {
    let change: LaudoDiff.Change
    let dimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if !change.before.isEmpty {
                row(symbol: "minus", tokens: change.before, removed: true)
            }
            if !change.after.isEmpty {
                row(symbol: "plus", tokens: change.after, removed: false)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(AppSurface.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
        .opacity(dimmed ? 0.7 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func row(symbol: String, tokens: [LaudoDiff.Token], removed: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(removed ? SemanticColor.errorText : SemanticColor.successText)
                .frame(width: 12)
            Text(attributed(tokens, removed: removed))
                .font(TextStyle.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func attributed(_ tokens: [LaudoDiff.Token], removed: Bool) -> AttributedString {
        var result = AttributedString()
        for token in tokens {
            var piece = AttributedString(token.text)
            if removed {
                piece.foregroundColor = token.changed ? SemanticColor.errorText : AppSurface.textMuted
                if token.changed {
                    piece.strikethroughStyle = .single
                    piece.backgroundColor = SemanticColor.errorBg
                }
            } else {
                piece.foregroundColor = AppSurface.textPrimary
                if token.changed {
                    piece.backgroundColor = SemanticColor.successBg
                    piece.foregroundColor = SemanticColor.successText
                }
            }
            result += piece
        }
        return result
    }

    private var accessibilityText: String {
        switch change.kind {
        case .replaced: return "Antes: \(change.beforeText). Depois: \(change.afterText)."
        case .inserted: return "Linha nova: \(change.afterText)."
        case .removed: return "Linha removida: \(change.beforeText)."
        }
    }
}
