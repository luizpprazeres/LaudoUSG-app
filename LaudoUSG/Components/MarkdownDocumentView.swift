import SwiftUI

struct MarkdownDocumentView: View {
    let title: String
    let resourceName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let attributedContent {
                    Text(attributedContent)
                        .font(TextStyle.body)
                        .foregroundStyle(AppSurface.textPrimary)
                        .textSelection(.enabled)
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

    private var attributedContent: AttributedString? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
    }
}

#Preview {
    NavigationStack {
        MarkdownDocumentView(title: "Termos de Uso", resourceName: "terms-of-use")
    }
    .environment(AppState())
}
