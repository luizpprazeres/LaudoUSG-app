import SwiftUI

struct MarkdownDocumentView: View {
    let title: String
    let resourceName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let lines = bundleLines, !lines.isEmpty {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        renderLine(line)
                    }
                } else {
                    Text("Não foi possível carregar o documento.")
                        .font(TextStyle.body)
                        .foregroundStyle(SemanticColor.errorText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fechar") {
                    dismiss()
                }
                .foregroundStyle(BrandColor.primary)
            }
        }
    }

    private var bundleLines: [String]? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content.components(separatedBy: "\n")
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else if trimmed.hasPrefix("# ") {
            Text(strip(String(trimmed.dropFirst(2))))
                .font(TextStyle.h2)
                .foregroundStyle(AppSurface.textPrimary)
                .padding(.top, Spacing.md)
        } else if trimmed.hasPrefix("## ") {
            Text(strip(String(trimmed.dropFirst(3))))
                .font(TextStyle.h3)
                .foregroundStyle(AppSurface.textPrimary)
                .padding(.top, Spacing.sm)
        } else if trimmed.hasPrefix("### ") {
            Text(strip(String(trimmed.dropFirst(4))))
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)
                .padding(.top, Spacing.xs)
        } else if trimmed.hasPrefix("#### ") {
            Text(strip(String(trimmed.dropFirst(5))))
                .font(TextStyle.bodyLargeSemibold)
                .foregroundStyle(AppSurface.textPrimary)
                .padding(.top, Spacing.xs)
        } else if trimmed.hasPrefix("> ") {
            HStack(alignment: .top, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(BrandColor.primary)
                    .frame(width: 3)
                inlineText(String(trimmed.dropFirst(2)))
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .italic()
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.xxs)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .top, spacing: Spacing.xs) {
                Text("•")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textPrimary)
                inlineText(String(trimmed.dropFirst(2)))
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.leading, Spacing.sm)
        } else if let numbered = numberedListPrefix(trimmed) {
            HStack(alignment: .top, spacing: Spacing.xs) {
                Text("\(numbered.number).")
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textPrimary)
                    .frame(minWidth: 20, alignment: .trailing)
                inlineText(numbered.rest)
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.leading, Spacing.sm)
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            Divider()
                .padding(.vertical, Spacing.xs)
        } else if trimmed.hasPrefix("|") {
            // Tabela — renderiza monospace simplificada
            // (não tentamos render visual; preserva leitura)
            if trimmed.hasPrefix("|---") || trimmed.contains("|---") {
                EmptyView() // ignora separador de header
            } else {
                Text(trimmed)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppSurface.textSecondary)
                    .lineLimit(nil)
            }
        } else if trimmed.hasPrefix("```") {
            // marcadores de bloco de código — ignora
            EmptyView()
        } else {
            inlineText(trimmed)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Renderiza texto inline (parágrafo) com suporte a **bold**, *italic*, [link](url), `code`.
    private func inlineText(_ raw: String) -> Text {
        if let attr = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(raw)
    }

    /// Limpa marcadores markdown simples (**, __) pra usar em headings sem render inline.
    private func strip(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    /// Detecta lista numerada do tipo "1. texto", "12. texto".
    private func numberedListPrefix(_ line: String) -> (number: Int, rest: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let prefix = line[line.startIndex..<dotIndex]
        guard let number = Int(prefix), number > 0, number < 1000 else { return nil }
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        let rest = String(line[line.index(after: afterDot)...])
        return (number, rest)
    }
}

#Preview {
    NavigationStack {
        MarkdownDocumentView(title: "Termos de Uso", resourceName: "terms-of-use")
    }
    .environment(AppState())
}
