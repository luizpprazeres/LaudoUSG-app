import SwiftUI

/// Por onde o médico chega ao "Ajustar laudo". Três variantes discretas em teste;
/// o Luiz escolhe uma e as outras saem.
///
/// Em DEBUG dá para trocar sem recompilar:
/// `-experiments.adjustEntryStyle A|B|C` nos argumentos de execução (o domínio de
/// argumentos do `UserDefaults` lê isso sozinho).
enum AdjustLaudoEntryStyle: String, CaseIterable {
    /// (A) Item no menu "…" da barra do laudo.
    case menu = "A"
    /// (B) Toque longo num trecho do laudo → "Ajustar este trecho".
    case trecho = "B"
    /// (C) Botão pequeno no canto do laudo.
    case cantinho = "C"

    static let defaultsKey = "experiments.adjustEntryStyle"
    static let recommended: AdjustLaudoEntryStyle = .cantinho

    static var current: AdjustLaudoEntryStyle {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: defaultsKey)?.uppercased(),
           let style = AdjustLaudoEntryStyle(rawValue: raw) {
            return style
        }
        #endif
        return recommended
    }
}

// MARK: - (A) menu "…"

struct AdjustMenuButton: View {
    let onVoice: () -> Void
    let onType: () -> Void

    var body: some View {
        Menu {
            Button {
                onVoice()
            } label: {
                Label("Ajustar laudo por voz", systemImage: "mic")
            }
            Button {
                onType()
            } label: {
                Label("Ajustar laudo digitando", systemImage: "keyboard")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppSurface.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppSurface.card))
                .overlay(Circle().stroke(AppSurface.border, lineWidth: 1))
        }
        .accessibilityLabel("Mais ações do laudo")
    }
}

// MARK: - (C) canto do laudo

struct AdjustCornerButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 5) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "mic")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "pencil")
                        .font(.system(size: 7, weight: .heavy))
                        .padding(1.5)
                        .background(Circle().fill(AppSurface.card))
                        .offset(x: 4, y: 3)
                }
                Text("Ajustar")
                    .font(TextStyle.captionMedium)
            }
            .foregroundStyle(AppSurface.textSecondary)
            .padding(.leading, Spacing.sm)
            .padding(.trailing, Spacing.sm + 2)
            .frame(minHeight: 32)
            .background(Capsule().fill(.regularMaterial))
            .overlay(Capsule().stroke(AppSurface.border, lineWidth: 1))
            .brandShadow(.sm)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Ajustar laudo por voz")
        .accessibilityHint("Dite uma correção; você confere antes de aplicar.")
    }
}

// MARK: - (B) toque longo num trecho

/// Laudo em linhas tocáveis: toque longo marca a linha e oferece "Ajustar este
/// trecho". Toque em outra área desmarca.
struct AdjustableLaudoText: View {
    let text: String
    var issues: [LaudoHighlightIssue] = []
    @Binding var selectedLine: Int?
    let onAdjust: (_ trecho: String) -> Void

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
                    .onLongPressGesture(minimumDuration: 0.35) {
                        Haptics.press()
                        withAnimation(.easeOut(duration: 0.15)) { selectedLine = index }
                    }
                    .onTapGesture {
                        if selectedLine != nil {
                            withAnimation(.easeOut(duration: 0.15)) { selectedLine = nil }
                        }
                    }

                if isSelected {
                    HStack(spacing: Spacing.xs) {
                        Button {
                            Haptics.tap()
                            onAdjust(line)
                        } label: {
                            Label("Ajustar este trecho", systemImage: "mic")
                                .font(TextStyle.captionMedium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.sm)
                                .frame(minHeight: 30)
                                .background(Capsule().fill(BrandColor.primary))
                        }
                        .buttonStyle(PressableButtonStyle())

                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { selectedLine = nil }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppSurface.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(AppSurface.card))
                                .overlay(Circle().stroke(AppSurface.border, lineWidth: 1))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Cancelar")
                    }
                    .padding(.leading, 3)
                    .padding(.bottom, Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
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
