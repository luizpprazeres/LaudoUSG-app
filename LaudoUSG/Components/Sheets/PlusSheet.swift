import SwiftUI

@MainActor
struct PlusSheet: View {
    let categoryHint: ReportCategory?
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var path: [PlusDestination] = []
    @State private var phrases: [UserPhrase] = []
    @State private var isLoadingPhrases: Bool = false
    @State private var phrasesUsesFallback: Bool = false

    enum PlusDestination: Hashable {
        case gestationalAge
        case dopplerObstetrico
        case imageAnalysis(ReportCategory)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    calculatorsSection
                    imageAnalysisSection
                    phrasesSection
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .background(AppSurface.background.ignoresSafeArea())
            .navigationTitle("Adicionar ao laudo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar", action: onDismiss)
                        .foregroundStyle(BrandColor.primary)
                }
            }
            .navigationDestination(for: PlusDestination.self) { destination in
                switch destination {
                case .gestationalAge:
                    IGCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .dopplerObstetrico:
                    DopplerCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .imageAnalysis(let category):
                    ImageAnalysisSheet(
                        category: category,
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadPhrases() }
    }

    private var calculatorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Calculadoras")
            VStack(spacing: Spacing.xs) {
                calculatorRow(
                    title: "Idade gestacional",
                    subtitle: "Por DUM ou USG (ACOG)",
                    icon: "calendar",
                    tint: BrandColor.primary,
                    destination: .gestationalAge
                )
                calculatorRow(
                    title: "Doppler obstétrico",
                    subtitle: "Percentis Barcelona FMF",
                    icon: "waveform.path.ecg",
                    tint: Color(hex: "F97316"),
                    destination: .dopplerObstetrico
                )
                disabledCalculatorRow(
                    title: "Anemia fetal",
                    subtitle: "Em breve",
                    icon: "drop"
                )
            }
        }
    }

    private var imageAnalysisSection: some View {
        Group {
            if let categoryHint, ImageAnalysisService.canAnalyze(category: categoryHint) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    sectionTitle("Imagem")
                    calculatorRow(
                        title: "Analisar imagem de USG",
                        subtitle: "Extrai biometria e Doppler de 1 a 3 imagens",
                        icon: "camera.viewfinder",
                        tint: categoryHint.tint,
                        destination: .imageAnalysis(categoryHint)
                    )
                }
            }
        }
    }

    private var phrasesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                sectionTitle("Frases")
                Spacer()
                if phrasesUsesFallback {
                    Text("Frases padrão")
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textMuted)
                }
            }
            if isLoadingPhrases {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if !phrases.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(phrases) { phrase in
                        phraseCard(title: phrase.title, body: phrase.body) {
                            insert(phrase.body)
                        }
                    }
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(UserPhrasesService.fallbackPhrases) { phrase in
                        phraseCard(title: phrase.title, body: phrase.body) {
                            insert(phrase.body)
                        }
                    }
                }
            }
            if phrasesUsesFallback {
                Text("Cadastre suas frases em Preferências → Minhas frases para vê-las aqui.")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.top, Spacing.xxs)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(TextStyle.captionMedium)
            .foregroundStyle(AppSurface.textSecondary)
            .textCase(.uppercase)
    }

    private func calculatorRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        destination: PlusDestination
    ) -> some View {
        Button {
            Haptics.tap()
            path.append(destination)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(TextStyle.bodyLargeMedium)
                        .foregroundStyle(AppSurface.textPrimary)
                    Text(subtitle)
                        .font(TextStyle.footnote)
                        .foregroundStyle(AppSurface.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSurface.textMuted)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(title), \(subtitle)")
    }

    private func disabledCalculatorRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppSurface.textMuted)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(AppSurface.muted)
                )
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(TextStyle.bodyLargeMedium)
                    .foregroundStyle(AppSurface.textMuted)
                Text(subtitle)
                    .font(TextStyle.footnote)
                    .foregroundStyle(AppSurface.textMuted)
            }
            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private func phraseCard(title: String, body: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(TextStyle.bodyMedium)
                        .foregroundStyle(AppSurface.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(body)
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: Spacing.md)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Inserir: \(title)")
    }

    private func insert(_ text: String) {
        Haptics.success()
        onInsert(text)
        onDismiss()
    }

    private func loadPhrases() async {
        isLoadingPhrases = true
        defer { isLoadingPhrases = false }
        do {
            let fetched = try await UserPhrasesService.fetch(categoryCode: categoryHint?.rawValue)
            phrases = fetched
            phrasesUsesFallback = fetched.isEmpty
        } catch {
            phrases = []
            phrasesUsesFallback = true
        }
    }
}

#Preview {
    PlusSheet(
        categoryHint: .obstetrica,
        onInsert: { _ in },
        onDismiss: {}
    )
}
