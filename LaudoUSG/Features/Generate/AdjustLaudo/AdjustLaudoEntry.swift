import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Toque e segure num trecho

/// Laudo em linhas tocáveis: tocar e segurar marca a linha e oferece "Ajustar este
/// trecho" (ditado) e "Copiar trecho" — este substitui a seleção de texto, que não
/// convive com o toque longo. Tocar fora desmarca.
struct AdjustableLaudoText: View {
    let text: String
    var issues: [LaudoHighlightIssue] = []
    @Binding var selectedLine: Int?
    let onAdjust: (_ trecho: String) -> Void
    @State private var copiedLine: Int?

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                lineView(index: index, line: line)
            }
        }
    }

    @ViewBuilder
    private func lineView(index: Int, line: String) -> some View {
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(" ").font(TextStyle.bodyLarge)
        } else {
            let isSelected = selectedLine == index
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ReviewHighlightedText(text: line, issues: issues, selectionEnabled: false)
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 3)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(isSelected ? BrandColor.primary.opacity(0.12) : .clear)
                    )
                    .contentShape(Rectangle())
                    // Simultâneos: o toque nos destaques de revisão (links) continua valendo.
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                            Haptics.press()
                            copiedLine = nil
                            withAnimation(.easeOut(duration: 0.15)) { selectedLine = index }
                        }
                    )
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            withAnimation(.easeOut(duration: 0.15)) { selectedLine = nil }
                        },
                        including: selectedLine == nil ? .subviews : .all
                    )
                    .accessibilityAction(named: "Ajustar este trecho") { onAdjust(line) }
                    .accessibilityAction(named: "Copiar trecho") { copy(line, index: index) }

                if isSelected {
                    actions(index: index, line: line)
                        .padding(.leading, 3)
                        .padding(.bottom, Spacing.xs)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func actions(index: Int, line: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Button {
                Haptics.tap()
                onAdjust(line)
            } label: {
                Label("Ajustar este trecho", systemImage: "mic")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 32)
                    .background(Capsule().fill(BrandColor.primary))
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                copy(line, index: index)
            } label: {
                Label(copiedLine == index ? "Copiado" : "Copiar trecho",
                      systemImage: copiedLine == index ? "checkmark" : "doc.on.doc")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 32)
                    .background(Capsule().fill(AppSurface.card))
                    .overlay(Capsule().stroke(AppSurface.border, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                withAnimation(.easeOut(duration: 0.15)) { selectedLine = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppSurface.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppSurface.card))
                    .overlay(Circle().stroke(AppSurface.border, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Desmarcar trecho")
        }
        .lineLimit(1)
    }

    private func copy(_ line: String, index: Int) {
        #if canImport(UIKit)
        UIPasteboard.general.string = line.strippedReviewMarkers
        #endif
        Haptics.success()
        withAnimation(.easeOut(duration: 0.15)) { copiedLine = index }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeOut(duration: 0.15)) {
                if copiedLine == index { copiedLine = nil }
                if selectedLine == index { selectedLine = nil }
            }
        }
    }
}

// MARK: - Dica (uma vez)

/// Dica mostrada UMA vez, no primeiro laudo pronto. Some ao tocar ou sozinha.
enum AdjustHint {
    static let seenKey = "laudousg.hint.adjustTrecho.seen"
    static let visibleSeconds: Double = 6
}

struct AdjustHintBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)
                Text("Dica: toque e segure um trecho do laudo para ajustá-lo por voz.")
                    .font(TextStyle.footnote)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppSurface.textMuted)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(.regularMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
            .brandShadow(.md)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dica: toque e segure um trecho do laudo para ajustá-lo por voz. Toque para fechar.")
    }
}

// MARK: - Desfazer

/// Linha curta logo abaixo da barra do laudo depois de um ajuste aplicado. Sai
/// quando o médico desfaz, edita à mão ou gera outro laudo.
struct AdjustUndoChip: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SemanticColor.successText)
            Text("Laudo ajustado")
                .foregroundStyle(AppSurface.textSecondary)
            Text("·")
                .foregroundStyle(AppSurface.textMuted)
            Button {
                onUndo()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .bold))
                    Text("Desfazer")
                }
                .foregroundStyle(BrandColor.primary)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Desfazer o ajuste do laudo")
            Spacer(minLength: 0)
        }
        .font(TextStyle.captionMedium)
        .lineLimit(1)
        .padding(.leading, Spacing.xxs)
        .transition(.opacity)
    }
}
