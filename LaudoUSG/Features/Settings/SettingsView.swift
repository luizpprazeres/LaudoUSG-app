import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var theme: ThemeOption = .auto
    @State private var measurementPrecision: Int = 1
    @State private var isSavingStyle: Bool = false
    @State private var savingVariantCategory: String?
    @State private var saveMessage: String?
    @State private var isSalaSheetPresented: Bool = false

    enum ThemeOption: String, CaseIterable, Identifiable {
        case auto, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .auto: return "Sistema"
            case .light: return "Claro"
            case .dark: return "Escuro"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                section(title: "Geração de laudo") {
                    writingStyleRow
                    Divider().padding(.leading, Spacing.md)
                    pickerRow(
                        title: "Casas decimais (medidas)",
                        selection: $measurementPrecision,
                        options: [0, 1, 2],
                        label: { String($0) }
                    )
                    Divider().padding(.leading, Spacing.md)
                    NavigationLink {
                        MyPhrasesView()
                    } label: {
                        navRowLabel("Minhas frases")
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                if !variantCategories.isEmpty {
                    section(title: "Modelos de laudo") {
                        ForEach(Array(variantCategories.enumerated()), id: \.element.categoryCode) { index, group in
                            if index > 0 {
                                Divider().padding(.leading, Spacing.md)
                            }
                            variantRow(categoryCode: group.categoryCode, variants: group.variants)
                        }
                    }
                }

                PreferencesSection()

                section(title: "Sala do Auxiliar") {
                    Button {
                        Haptics.tap()
                        isSalaSheetPresented = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "person.crop.rectangle.stack")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(BrandColor.primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                        .fill(BrandColor.primaryTint)
                                )
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Sessão de turno")
                                    .font(TextStyle.bodyLargeMedium)
                                    .foregroundStyle(AppSurface.textPrimary)
                                Text("Gere o código que o auxiliar usa pra entrar em sala.laudousg.com")
                                    .font(TextStyle.caption)
                                    .foregroundStyle(AppSurface.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppSurface.textMuted)
                        }
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 64)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                section(title: "Aparência") {
                    pickerRow(
                        title: "Tema",
                        selection: $theme,
                        options: ThemeOption.allCases,
                        label: { $0.label }
                    )
                }

                section(title: "Conta") {
                    infoRow(label: "Email", value: app.profile?.email ?? "—")
                    Divider().padding(.leading, Spacing.md)
                    infoRow(label: "Plano", value: app.profile?.planLabel ?? "Gratuito")
                    Divider().padding(.leading, Spacing.md)
                    Button {
                        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        navRowLabel("Gerenciar assinatura")
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                section(title: "Perfil") {
                    NavigationLink(destination: EditProfileView()) {
                        navRowLabel("Editar perfil")
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                section(title: "Sobre") {
                    NavigationLink(destination: AboutAppView()) {
                        navRowLabel("Sobre o LaudoUSG")
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                section(title: "Protótipos (debug)") {
                    NavigationLink(destination: DeepgramTestView()) {
                        navRowLabel("Transcrição ao vivo (Deepgram)")
                    }
                    .buttonStyle(PressableButtonStyle())
                    NavigationLink(destination: MyomaEditorScreen()) {
                        navRowLabel("Esquema de miomas (FIGO)")
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                section(title: "Zona de risco") {
                    NavigationLink(destination: DeleteAccountView()) {
                        HStack {
                            Text("Excluir minha conta")
                                .font(TextStyle.bodyLargeMedium)
                                .foregroundStyle(SemanticColor.errorAccent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SemanticColor.errorAccent.opacity(0.6))
                        }
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(TextStyle.caption)
                        .foregroundStyle(saveMessage.contains("Erro") ? SemanticColor.errorText : SemanticColor.successText)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Preferências")
        .navigationBarTitleDisplayMode(.large)
        .task { await app.refreshReportPreferences() }
        .sheet(isPresented: $isSalaSheetPresented) {
            SalaPairingSheet(onDismiss: { isSalaSheetPresented = false })
        }
    }

    private func navRowLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppSurface.textMuted)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
    }

    private var writingStyleRow: some View {
        HStack {
            Text("Estilo de laudo")
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
            if isSavingStyle {
                ProgressView().controlSize(.small)
            }
            Menu {
                ForEach(stylesOrFallback) { style in
                    Button(style.label) {
                        Task { await selectStyle(style.id) }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text(currentStyleLabel)
                        .foregroundStyle(BrandColor.primary)
                        .font(TextStyle.bodyMedium)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
    }

    private var currentStyleLabel: String {
        stylesOrFallback.first(where: { $0.id == app.defaultWritingStyleId })?.label
            ?? "Tradicional"
    }

    private var stylesOrFallback: [WritingStyleRecord] {
        // Fallback (só se a busca falhar): o estilo padrão Clássico, com o id real.
        app.availableStyles.isEmpty
            ? [
                WritingStyleRecord(
                    id: GenerateRequest.defaultWritingStyleId,
                    code: "CLASSICO_COMPLETO",
                    name: "Clássico completo",
                    description: nil,
                    active: true
                )
            ]
            : app.availableStyles
    }

    /// Categorias com mais de uma variante de máscara NO ESTILO ATUAL do
    /// usuário. O catálogo repete a mesma variant_key por estilo de escrita
    /// e o backend aplica a chave ao estilo da request — oferecer variante
    /// de outro estilo gravaria preferência que falha com BUNDLE_VARIANT_EMPTY.
    private var variantCategories: [(categoryCode: String, variants: [ReportTemplateVariantRecord])] {
        let currentStyleVariants = app.availableVariants.filter {
            $0.writingStyleId == app.defaultWritingStyleId
        }
        let grouped = Dictionary(grouping: currentStyleVariants, by: \.categoryCode)
        return grouped.compactMap { categoryCode, variants in
            var seen: Set<String> = []
            let deduped = variants.filter { seen.insert($0.variantKey).inserted }
            guard deduped.count > 1 else { return nil }
            return (categoryCode, deduped.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }
        .sorted { categoryLabel($0.categoryCode).localizedStandardCompare(categoryLabel($1.categoryCode)) == .orderedAscending }
    }

    private func categoryLabel(_ code: String) -> String {
        ReportCategory(rawValue: code)?.label ?? code
    }

    private func variantRow(categoryCode: String, variants: [ReportTemplateVariantRecord]) -> some View {
        let currentKey = app.reportPreferences.first(where: { $0.categoryCode == categoryCode })?.variantKey
        let currentLabel = variants.first(where: { $0.variantKey == currentKey })?.name ?? "Automático"
        return HStack {
            Text(categoryLabel(categoryCode))
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
            if savingVariantCategory == categoryCode {
                ProgressView().controlSize(.small)
            }
            Menu {
                Button("Automático") {
                    Task { await selectVariant(categoryCode: categoryCode, variant: nil) }
                }
                ForEach(variants) { variant in
                    Button(variant.name) {
                        Task { await selectVariant(categoryCode: categoryCode, variant: variant) }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Text(currentLabel)
                        .foregroundStyle(BrandColor.primary)
                        .font(TextStyle.bodyMedium)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
    }

    private func selectVariant(categoryCode: String, variant: ReportTemplateVariantRecord?) async {
        guard savingVariantCategory == nil else { return }
        savingVariantCategory = categoryCode
        saveMessage = nil
        do {
            try await ProfileService.updateReportPreference(
                categoryCode: categoryCode,
                variantId: variant?.id
            )
            app.setReportPreference(categoryCode: categoryCode, variant: variant)
            saveMessage = "Modelo de laudo atualizado."
        } catch {
            saveMessage = "Erro ao atualizar modelo: \(error.localizedDescription)"
        }
        savingVariantCategory = nil
    }

    private func selectStyle(_ id: String) async {
        isSavingStyle = true
        saveMessage = nil
        do {
            try await ProfileService.updateDefaultWritingStyle(id)
            app.defaultWritingStyleId = id
            saveMessage = "Estilo atualizado."
        } catch {
            saveMessage = "Erro ao atualizar estilo: \(error.localizedDescription)"
        }
        isSavingStyle = false
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
        }
    }

    private func pickerRow<T: Hashable>(
        title: String,
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) -> some View {
        HStack {
            Text(title)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(BrandColor.primary)
            .labelsHidden()
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(TextStyle.bodyLargeMedium)
                .foregroundStyle(AppSurface.textPrimary)
            Spacer()
            Text(value)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppState())
}
