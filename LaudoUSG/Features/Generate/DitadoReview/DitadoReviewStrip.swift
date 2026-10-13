import SwiftUI

/// Faixa discreta abaixo dos achados: "Revisão do ditado · 1 corrigido · 2 para conferir".
/// Fechada por padrão; abre com um toque. Número e negação nunca mudam sem o toque do médico.
struct DitadoReviewStrip: View {
    let state: DitadoReviewState
    /// Texto atual dos achados — para mostrar a sugestão com as palavras em volta.
    let text: String
    let onAccept: (DitadoSuggestion) -> Void
    let onDismiss: (DitadoSuggestion) -> Void
    let onUndo: (DitadoReviewState.Applied) -> Void
    var onUndoFormatting: () -> Void = {}
    let onDismissUncertain: () -> Void

    #if DEBUG
    // Captura de tela do modo de demonstração: abre já expandida.
    @State private var expanded = UserDefaults.standard.bool(forKey: "DitadoReviewDemoAberto")
    #else
    @State private var expanded = false
    #endif

    var body: some View {
        if !state.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Button {
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: state.toReviewCount > 0 ? "exclamationmark.circle" : "checkmark.circle")
                            .foregroundStyle(state.toReviewCount > 0 ? SemanticColor.warningText : BrandColor.primary)
                        Text(summary)
                            .font(TextStyle.captionMedium)
                            .foregroundStyle(AppSurface.textSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppSurface.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Revisão do ditado: \(summary)")
                .accessibilityHint(expanded ? "Fecha a lista" : "Abre a lista")

                if expanded {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        ForEach(state.pending) { s in
                            let p = DitadoReviewEngine.phrase(original: s.original, replacement: s.replacement, near: s.start, in: text)
                            row(icon: "questionmark.circle", tint: SemanticColor.warningText,
                                text: "“\(p.from)” → “\(p.to ?? "")”?") {
                                pill("Manter") { onDismiss(s) }
                                pill("Trocar", primary: true) { onAccept(s) }
                            }
                        }
                        ForEach(state.warnings) { s in
                            row(icon: "ruler", tint: SemanticColor.warningText,
                                text: "Confira a medida “\(s.original)”") {
                                pill("Ok") { onDismiss(s) }
                            }
                        }
                        if !state.formatted.isEmpty {
                            row(icon: "number", tint: BrandColor.primary,
                                text: state.formatted.count == 1
                                    ? "Formatado: “\(state.formatted[0].original)” → “\(state.formatted[0].replacement)”"
                                    : "Números e medidas formatados (\(state.formatted.count))") {
                                pill("Desfazer") { onUndoFormatting() }
                            }
                        }
                        ForEach(state.corrected) { a in
                            let p = DitadoReviewEngine.phrase(original: a.replacement, replacement: nil, near: a.start, in: text)
                            row(icon: "checkmark", tint: BrandColor.primary,
                                text: "Corrigido: “\(a.original)” → “\(p.from)”") {
                                pill("Desfazer") { onUndo(a) }
                            }
                        }
                        if !state.uncertainWords.isEmpty {
                            row(icon: "waveform", tint: AppSurface.textMuted,
                                text: "Ouvido com pouca certeza: " + state.uncertainWords.joined(separator: ", ")) {
                                pill("Ok") { onDismissUncertain() }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Radius.md).fill(AppSurface.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppSurface.border, lineWidth: 1))
        }
    }

    private var summary: String {
        var parts: [String] = []
        if !state.corrected.isEmpty { parts.append(state.corrected.count == 1 ? "1 corrigido" : "\(state.corrected.count) corrigidos") }
        if !state.formatted.isEmpty { parts.append("medidas formatadas") }
        if state.toReviewCount > 0 { parts.append("\(state.toReviewCount) para conferir") }
        if parts.isEmpty, !state.uncertainWords.isEmpty { parts.append("palavras incertas") }
        return "Revisão do ditado · " + parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func row<Actions: View>(icon: String, tint: Color, text: String, @ViewBuilder actions: () -> Actions) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: icon).font(.caption).foregroundStyle(tint).frame(width: 16)
            Text(text)
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            HStack(spacing: Spacing.xxs) { actions() }
        }
    }

    private func pill(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TextStyle.captionMedium)
                .foregroundStyle(primary ? BrandColor.primary : AppSurface.textSecondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(Capsule().fill(primary ? BrandColor.primaryTint : AppSurface.muted))
        }
        .buttonStyle(.plain)
    }
}
