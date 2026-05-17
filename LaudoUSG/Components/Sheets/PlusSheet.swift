import SwiftUI

struct PlusSheet: View {
    let onPick: (String) -> Void
    let onDismiss: () -> Void

    private let sections: [SnippetSection] = [
        SnippetSection(
            title: "Datas e medidas",
            snippets: [
                "DUM (Data da Última Menstruação)",
                "Idade gestacional por USG",
                "Data provável do parto"
            ]
        ),
        SnippetSection(
            title: "Frases comuns – Obstétrica",
            snippets: [
                "Feto único, em situação longitudinal e apresentação cefálica, com BCF presentes.",
                "Placenta de implantação corporal posterior, grau 0/I de Grannum.",
                "Líquido amniótico em quantidade normal (ILA 12 cm)."
            ]
        ),
        SnippetSection(
            title: "Frases comuns – Tireoide",
            snippets: [
                "Glândula tireoide tópica, contornos regulares, dimensões e ecotextura preservadas.",
                "Vascularização ao Doppler colorido sem alterações."
            ]
        )
    ]

    var body: some View {
        VStack(spacing: Spacing.md) {
            header
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(sections) { section in
                        snippetSection(section)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(AppSurface.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("Inserir trecho")
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)

            Spacer()

            SecondaryButton(title: "Fechar", action: onDismiss)
        }
    }

    private func snippetSection(_ section: SnippetSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(section.title)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: Spacing.xs) {
                ForEach(section.snippets, id: \.self) { snippet in
                    snippetCard(snippet)
                }
            }
        }
    }

    private func snippetCard(_ snippet: String) -> some View {
        Button {
            onPick(snippet)
        } label: {
            HStack(spacing: Spacing.md) {
                Text(snippet)
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: Spacing.md)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)
            }
            .padding(Spacing.md)
            .background(AppSurface.card)
            .cornerRadius(Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Inserir trecho: \(snippet)")
    }
}

private struct SnippetSection: Identifiable {
    let id = UUID()
    let title: String
    let snippets: [String]
}

#Preview {
    PlusSheet(onPick: { _ in }, onDismiss: {})
}
