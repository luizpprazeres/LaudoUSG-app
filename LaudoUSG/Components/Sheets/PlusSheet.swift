import SwiftUI

@MainActor
struct PlusSheet: View {
    let categoryHint: ReportCategory?
    let onInsert: (String) -> Void
    let onDismiss: () -> Void
    var onOpenConsultor: (() -> Void)? = nil

    @State private var path: [PlusDestination] = []
    @State private var phrases: [UserPhrase] = []
    @State private var isLoadingPhrases: Bool = false
    @State private var phrasesUsesFallback: Bool = false

    enum PlusDestination: Hashable {
        case gestationalAge
        case dopplerObstetrico
        case hadlock
        case ila4q
        case anemiaMCAPSV
        case afc
        case ductoVenoso
        case birads
        case tirads
        case preEclampsia
        case imageAnalysis(ReportCategory)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    calculatorsSection
                    imageAnalysisSection
                    consultorSection
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
                case .hadlock:
                    HadlockCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .ila4q:
                    ILA4QCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .anemiaMCAPSV:
                    AnemiaMCAPSVCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .afc:
                    AFCCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .ductoVenoso:
                    DuctoVenosoCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .birads:
                    BIRADSCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .tirads:
                    TIRADSCalculatorSheet(
                        onInsert: { insert($0) },
                        onDismiss: onDismiss
                    )
                case .preEclampsia:
                    PreEclampsiaCalculatorSheet(
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
                if showsObstetricCalcs {
                    calculatorRow(
                        title: "Idade gestacional",
                        subtitle: "Por DUM ou USG (ACOG)",
                        icon: "calendar",
                        tint: BrandColor.primary,
                        destination: .gestationalAge
                    )
                    calculatorRow(
                        title: "Peso fetal (Hadlock)",
                        subtitle: "EFW por biometria DBP+CC+CA+CF",
                        icon: "scalemass",
                        tint: Color(hex: "0EA5E9"),
                        destination: .hadlock
                    )
                    calculatorRow(
                        title: "ILA 4 quadrantes",
                        subtitle: "Phelan — soma dos bolsões",
                        icon: "drop.fill",
                        tint: Color(hex: "06B6D4"),
                        destination: .ila4q
                    )
                }
                if showsDopplerCalcs {
                    calculatorRow(
                        title: "Doppler obstétrico",
                        subtitle: "Percentis Barcelona FMF",
                        icon: "waveform.path.ecg",
                        tint: Color(hex: "F97316"),
                        destination: .dopplerObstetrico
                    )
                    calculatorRow(
                        title: "Anemia fetal (MCA-PSV)",
                        subtitle: "MoM via curva de Mari",
                        icon: "drop",
                        tint: Color(hex: "DC2626"),
                        destination: .anemiaMCAPSV
                    )
                    calculatorRow(
                        title: "Ducto venoso (Z-score)",
                        subtitle: "Hecher 2001 — IP + onda A",
                        icon: "waveform",
                        tint: Color(hex: "F59E0B"),
                        destination: .ductoVenoso
                    )
                }
                if showsObstetricCalcs {
                    calculatorRow(
                        title: "Risco de pré-eclâmpsia (1T)",
                        subtitle: "FMF simplificado — fatores + MAP + uterinas",
                        icon: "exclamationmark.triangle",
                        tint: Color(hex: "F43F5E"),
                        destination: .preEclampsia
                    )
                }
                if showsMamaCalcs {
                    calculatorRow(
                        title: "BI-RADS",
                        subtitle: "Categorias 0-6 ACR — recomendação",
                        icon: "heart.text.square",
                        tint: Color(hex: "F43F5E"),
                        destination: .birads
                    )
                }
                if showsTireoideCalcs {
                    calculatorRow(
                        title: "TI-RADS",
                        subtitle: "ACR — pontuação por 5 features",
                        icon: "shield.lefthalf.filled",
                        tint: Color(hex: "0EA5E9"),
                        destination: .tirads
                    )
                }
                if showsAFC {
                    calculatorRow(
                        title: "Folículos antrais (AFC)",
                        subtitle: "Reserva ovariana — D + E",
                        icon: "circle.grid.3x3",
                        tint: Color(hex: "A855F7"),
                        destination: .afc
                    )
                }
            }
        }
    }

    private var showsObstetricCalcs: Bool {
        guard let c = categoryHint else { return true }
        return c == .obstetrica || c == .dopplerObstetrico || c == .morfologico
    }

    private var showsDopplerCalcs: Bool {
        guard let c = categoryHint else { return true }
        return c == .dopplerObstetrico || c == .obstetrica || c == .morfologico
    }

    private var showsMamaCalcs: Bool {
        guard let c = categoryHint else { return true }
        return c == .mamaria
    }

    private var showsTireoideCalcs: Bool {
        guard let c = categoryHint else { return true }
        return c == .tireoide
    }

    private var showsAFC: Bool {
        guard let c = categoryHint else { return true }
        return c == .pelveFeminina
    }

    private var consultorSection: some View {
        Group {
            if let onOpenConsultor {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    sectionTitle("IA")
                    Button {
                        Haptics.tap()
                        onOpenConsultor()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: "8B5CF6"))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                        .fill(Color(hex: "8B5CF6").opacity(0.12))
                                )
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Consultor IA")
                                    .font(TextStyle.bodyLargeMedium)
                                    .foregroundStyle(AppSurface.textPrimary)
                                Text("Diagnósticos diferenciais e conduta com IA")
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
                    .accessibilityLabel("Abrir Consultor IA")
                }
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
