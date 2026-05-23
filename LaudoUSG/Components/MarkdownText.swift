import SwiftUI

struct MarkdownText: View {
    let raw: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks, id: \.id) { block in
                switch block.kind {
                case .heading(let level):
                    Text(formatInline(block.text))
                        .font(level <= 1 ? TextStyle.h2 : level == 2 ? TextStyle.h3 : TextStyle.subtitle)
                        .foregroundStyle(AppSurface.textPrimary)
                case .bullet:
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(BrandColor.primary)
                        Text(formatInline(block.text))
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(AppSurface.textPrimary)
                    }
                case .paragraph:
                    Text(formatInline(block.text))
                        .font(TextStyle.bodyLarge)
                        .foregroundStyle(AppSurface.textPrimary)
                case .blank:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        let lines = raw.components(separatedBy: "\n")
        for (idx, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                continue
            }
            if line.hasPrefix("### ") {
                result.append(Block(id: idx, kind: .heading(level: 3), text: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                result.append(Block(id: idx, kind: .heading(level: 2), text: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                result.append(Block(id: idx, kind: .heading(level: 1), text: String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(Block(id: idx, kind: .bullet, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("---") {
                continue
            } else {
                result.append(Block(id: idx, kind: .paragraph, text: line))
            }
        }
        return result
    }

    private func formatInline(_ text: String) -> AttributedString {
        guard let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(text)
        }
        return attr
    }

    private struct Block {
        let id: Int
        let kind: Kind
        let text: String

        enum Kind {
            case heading(level: Int)
            case bullet
            case paragraph
            case blank
        }
    }
}

#Preview {
    ScrollView {
        MarkdownText(raw: """
        ## Diagnósticos Diferenciais

        **Adenomiose** — 65%
        - ✅ Útero globoso e aumentado
        - ✅ Miométrio heterogêneo
        - ❌ Sem cistos miometriais

        **Mioma** — 25%
        - ✅ Útero aumentado
        - ❌ Sem nódulo identificado

        ## Síntese
        Achados sugerem adenomiose com alta probabilidade. Sugere-se *correlação clínica*.
        """)
        .padding()
    }
    .background(AppSurface.background)
}
