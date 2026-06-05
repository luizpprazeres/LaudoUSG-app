import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GenerateView: View {
    @Environment(AppState.self) private var app
    @State private var vm = GenerateViewModel()
    @State private var path: [AppDestination] = []
    @State private var didCopyLaudo: Bool = false
    @State private var isEditingLaudo: Bool = false  // toggle visualização (com highlight) vs edição (TextEditor)
    @State private var isSanityExpanded: Bool = false // acordeão de pontos a revisar
    @State private var watchInbox = WatchAudioInbox.shared
    @Namespace private var tabNamespace

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .history: HistoryView()
                    case .reportDetail(let id): ReportDetailView(reportId: id)
                    case .analytics: AnalyticsView()
                    case .library:
                        PlaceholderView(
                            title: "Biblioteca",
                            icon: "books.vertical.fill",
                            message: "Frases e protocolos favoritos entram em sprints futuros."
                        )
                        .navigationTitle("Biblioteca")
                    case .settings: SettingsView()
                    case .about:
                        AboutAppView()
                    }
                }
        }
        .task { vm.prewarmMic() }   // pré-aquece o token Deepgram (início instantâneo)
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            AppSurface.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if let error = vm.lastError {
                    errorCard(error)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.xs)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
                if let warning = vm.lastWarning {
                    warningBanner(warning)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.xs)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
                tabSwitcher
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                if vm.activeTab == .achados {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            shortcutsBar
                            achadosEditor
                            Color.clear.frame(height: 120)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                    }
                } else {
                    laudoEditor
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                    if !vm.sanityIssues.isEmpty {
                        sanityCard
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, 96)
                    } else {
                        Color.clear.frame(height: 96)
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: vm.lastError)
            .animation(.easeOut(duration: 0.2), value: vm.lastWarning)

            bottomToolbar
        }
        .sheet(isPresented: Binding(get: { vm.isCategorySheetPresented }, set: { vm.isCategorySheetPresented = $0 })) {
            CategorySheet(
                selection: Binding(get: { vm.category }, set: { if let new = $0 { vm.category = new } }),
                onDismiss: { vm.isCategorySheetPresented = false }
            )
        }
        .sheet(isPresented: Binding(get: { vm.isMenuSheetPresented }, set: { vm.isMenuSheetPresented = $0 })) {
            MenuSheet(
                onTapHistorico: { navigate(to: .history) },
                onTapAnalytics: { navigate(to: .analytics) },
                onTapBiblioteca: { navigate(to: .library) },
                onTapPreferencias: { navigate(to: .settings) },
                onTapSobre: { navigate(to: .about) },
                onLogout: {
                    vm.isMenuSheetPresented = false
                    app.signOut()
                }
            )
        }
        .sheet(isPresented: Binding(get: { vm.isPlusSheetPresented }, set: { vm.isPlusSheetPresented = $0 })) {
            PlusSheet(
                categoryHint: vm.category,
                onInsert: { vm.insertSnippet($0) },
                onDismiss: { vm.isPlusSheetPresented = false },
                onOpenConsultor: vm.canOpenConsultor ? {
                    vm.isPlusSheetPresented = false
                    if app.profile?.hasPro == true {
                        vm.isConsultorSheetPresented = true
                    } else {
                        vm.isPaywallPresented = true
                    }
                } : nil,
                reportText: vm.displayedOutput.isEmpty ? nil : vm.displayedOutput
            )
        }
        .sheet(isPresented: Binding(get: { vm.isConsultorSheetPresented }, set: { vm.isConsultorSheetPresented = $0 })) {
            ConsultorSheet(
                vm: ConsultorViewModel(
                    report: vm.displayedOutput,
                    findings: vm.inputText,
                    category: vm.category,
                    reportId: vm.lastReportId
                ),
                onDismiss: { vm.isConsultorSheetPresented = false }
            )
        }
        .sheet(isPresented: Binding(get: { vm.isMiomaEditorPresented }, set: { vm.isMiomaEditorPresented = $0 })) {
            NavigationStack {
                MyomaEditorScreen(
                    reportId: vm.lastReportId,
                    initialFindings: MyomaFindingsParser.parse(vm.editedLaudoText)
                )
            }
        }
        .sheet(isPresented: Binding(get: { vm.isWatchDitadosPresented }, set: { vm.isWatchDitadosPresented = $0 })) {
            WatchDitadosSheet(
                inbox: WatchAudioInbox.shared,
                onInsert: { vm.insertTranscript($0) },
                onDismiss: { vm.isWatchDitadosPresented = false }
            )
        }
        .sheet(isPresented: Binding(get: { vm.isPaywallPresented }, set: { vm.isPaywallPresented = $0 })) {
            PaywallSheet(
                onSuccess: {
                    vm.isPaywallPresented = false
                    Task { await app.refreshProfile() }
                },
                onDismiss: { vm.isPaywallPresented = false }
            )
        }
        .sheet(isPresented: Binding(get: { vm.isIGCalculatorPresented }, set: { vm.isIGCalculatorPresented = $0 })) {
            NavigationStack {
                IGCalculatorSheet(
                    onInsert: { snippet in
                        vm.insertSnippet(snippet)
                        vm.isIGCalculatorPresented = false
                    },
                    onDismiss: { vm.isIGCalculatorPresented = false }
                )
            }
        }
        .sheet(isPresented: Binding(get: { vm.isHadlockCalculatorPresented }, set: { vm.isHadlockCalculatorPresented = $0 })) {
            NavigationStack {
                HadlockCalculatorSheet(
                    onInsert: { snippet in
                        vm.insertSnippet(snippet)
                        vm.isHadlockCalculatorPresented = false
                    },
                    onDismiss: { vm.isHadlockCalculatorPresented = false },
                    sexHint: SexDetector.detect(vm.inputText)
                )
            }
        }
        .sheet(isPresented: Binding(get: { vm.isDopplerCalculatorPresented }, set: { vm.isDopplerCalculatorPresented = $0 })) {
            NavigationStack {
                DopplerCalculatorSheet(
                    onInsert: { snippet in
                        vm.insertSnippet(snippet)
                        vm.isDopplerCalculatorPresented = false
                    },
                    onDismiss: { vm.isDopplerCalculatorPresented = false },
                    prefillFrom: vm.inputText
                )
            }
        }
        .sheet(isPresented: Binding(get: { vm.isSalaSheetPresented }, set: { vm.isSalaSheetPresented = $0 })) {
            SalaPairingSheet(onDismiss: { vm.isSalaSheetPresented = false })
        }
        .overlay {
            if vm.isRecordingOverlayPresented {
                RecordingOverlay(
                    isPresented: Binding(get: { vm.isRecordingOverlayPresented }, set: { vm.isRecordingOverlayPresented = $0 }),
                    deepgram: vm.deepgram,
                    onCancel: { vm.cancelRecording() },
                    onStop: { vm.finishRecording() }
                )
                .transition(.opacity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                Haptics.tap()
                vm.isMenuSheetPresented = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppSurface.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Menu")

            BrandLogo(size: .small)

            Spacer()

            categoryChip
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(AppSurface.background)
    }

    private var categoryChip: some View {
        Button {
            Haptics.tap()
            vm.isCategorySheetPresented = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(vm.category.tint)
                    .frame(width: 10, height: 10)
                    .shadow(color: vm.category.tint.opacity(0.7), radius: 5, x: 0, y: 0)
                Text(vm.category.label)
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppSurface.textMuted)
            }
            .padding(.horizontal, Spacing.sm)
            .frame(height: 36)
            .frame(maxWidth: 200, alignment: .trailing)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Categoria \(vm.category.label). Toque para trocar.")
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton(tab: .achados, label: "Achados")
            tabButton(tab: .laudo, label: "Laudo")
        }
        .padding(4)
        .background(
            Capsule()
                .fill(AppSurface.muted)
        )
        .overlay(
            Capsule()
                .stroke(AppSurface.border, lineWidth: 1)
        )
        .frame(maxWidth: 280)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(tab: GenerateTab, label: String) -> some View {
        let isActive = vm.activeTab == tab
        let isLaudoWithBadge = tab == .laudo && vm.hasLaudoOutput && !isActive
        return Button {
            Haptics.tap()
            withAnimation(.laudousgSmooth) { vm.activeTab = tab }
        } label: {
            ZStack {
                if isActive {
                    Capsule()
                        .fill(BrandColor.primary)
                        .scaleEffect(x: 1, y: 1.05)
                        .smoothMorph(id: "tabPill", in: tabNamespace)
                }
                HStack(spacing: Spacing.xxs) {
                    Text(label)
                        .font(isActive ? TextStyle.bodySemibold : TextStyle.bodyMedium)
                    if isLaudoWithBadge {
                        Circle()
                            .fill(BrandColor.primary)
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(isActive ? .white : BrandColor.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .scaleEffect(x: 1, y: isActive ? 1 : 0.96)
            .opacity(isActive ? 1 : 0.7)
            .animation(.laudousgSmooth, value: isActive)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var shortcutsBar: some View {
        Group {
            if !vm.shortcuts.isEmpty {
                FlowLayout(spacing: Spacing.sm, alignment: .leading) {
                    ForEach(vm.shortcuts) { shortcut in
                        shortcutLink(shortcut)
                    }
                }
            }
        }
    }

    private func shortcutLink(_ shortcut: GenerateShortcut) -> some View {
        Button {
            Haptics.tap()
            vm.runShortcut(shortcut)
        } label: {
            Text(shortcut.label)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .underline(true, pattern: .solid)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Atalho: \(shortcut.label)")
    }

    private var achadosEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(get: { vm.inputText }, set: { vm.inputText = $0 }))
                .font(TextStyle.bodyLarge)
                .scrollContentBackground(.hidden)
                .background(AppSurface.background)
                .foregroundStyle(AppSurface.textPrimary)
                .frame(minHeight: 300)
                .padding(.horizontal, -4)

            if vm.inputText.isEmpty {
                Text("Dite ou digite os achados.")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.top, Spacing.xs)
                    .allowsHitTesting(false)
            }

            if !watchInbox.pending.isEmpty {
                HStack {
                    Button {
                        Haptics.tap()
                        vm.isWatchDitadosPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(watchInbox.pending.count) ditado\(watchInbox.pending.count == 1 ? "" : "s") do Watch")
                                .font(TextStyle.captionMedium)
                        }
                        .foregroundStyle(BrandColor.primary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(Capsule().fill(BrandColor.primaryTint))
                        .overlay(Capsule().stroke(BrandColor.primary.opacity(0.3), lineWidth: 1))
                    }
                    .accessibilityLabel("Ditados gravados no Apple Watch")
                    Spacer()
                }
                .offset(y: -36)
            }

            if !vm.inputText.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        Haptics.tap()
                        vm.inputText = ""
                    } label: {
                        Text("Limpar")
                            .font(TextStyle.captionMedium)
                            .foregroundStyle(BrandColor.primary)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxs)
                            .background(Capsule().fill(BrandColor.primaryTint))
                    }
                    .accessibilityLabel("Limpar achados")
                }
                .offset(y: -36)
            }
        }
    }

    private var laudoEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            laudoToolbar
            if vm.phase.isBusy && vm.streamedOutput.isEmpty && !vm.currentStatusMessage.isEmpty {
                VStack(alignment: .leading) {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(vm.currentStatusMessage)
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(AppSurface.textSecondary)
                            .id(vm.currentStatusMessage)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    .padding(.top, Spacing.xs)
                    .padding(.leading, Spacing.xs)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: vm.currentStatusMessage)
            } else if vm.phase.isBusy && !vm.displayedOutput.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Renderiza laudo durante streaming com placeholders ____ em
                        // destaque roxo (efeito hidrocor — "ponto a revisar" visualmente
                        // marcado, fica profissional + fácil de identificar).
                        Text(vm.displayedOutput.laudoHighlighted)
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(AppSurface.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.disabled)
                            .padding(.top, Spacing.xs)
                            .padding(.leading, Spacing.xs)
                        TypingCursor()
                            .padding(.leading, Spacing.xs)
                    }
                }
                .scrollIndicators(.hidden)
                .background(AppSurface.background)
                .frame(maxHeight: .infinity)
            } else if vm.editedLaudoText.isEmpty {
                // Estado inicial — laudo ainda não gerado
                Text("O laudo gerado aparece aqui.")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.top, Spacing.xs)
                    .padding(.leading, Spacing.xs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if isEditingLaudo {
                // Modo edição — TextEditor padrão (sem highlight, mas editável)
                TextEditor(text: Binding(get: { vm.editedLaudoText }, set: { vm.laudoTextChanged($0) }))
                    .font(TextStyle.bodyLarge)
                    .scrollContentBackground(.hidden)
                    .background(AppSurface.background)
                    .foregroundStyle(AppSurface.textPrimary)
                    .frame(maxHeight: .infinity)
            } else {
                // Modo visualização — Text(AttributedString) com linhas que contêm ____ destacadas em roxo
                ScrollView {
                    Text(vm.editedLaudoText.laudoHighlighted)
                        .font(TextStyle.bodyLarge)
                        .foregroundStyle(AppSurface.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.xs)
                        .padding(.leading, Spacing.xs)
                        .textSelection(.enabled) // permite copiar com seleção
                }
                .scrollIndicators(.hidden)
                .background(AppSurface.background)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        // Auto-volta pra visualização quando uma nova geração inicia
        .onChange(of: vm.phase.isBusy) { _, newValue in
            if newValue { isEditingLaudo = false }
        }
    }

    private struct TypingCursor: View {
        @State private var visible = true

        var body: some View {
            Text("▌")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(BrandColor.primary)
                .opacity(visible ? 1 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                        visible = false
                    }
                }
        }
    }

    private var laudoToolbar: some View {
        HStack(spacing: Spacing.xs) {
            saveIndicator
            Spacer()
            if vm.hasLaudoOutput {
                // Botão toggle: visualização (com highlight roxo) ↔ edição (TextEditor)
                Button {
                    Haptics.tap()
                    isEditingLaudo.toggle()
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: isEditingLaudo ? "eye.fill" : "pencil")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isEditingLaudo ? "Visualizar" : "Editar")
                            .font(TextStyle.captionMedium)
                    }
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(AppSurface.card))
                    .overlay(Capsule().stroke(AppSurface.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    performCopyLaudo()
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: didCopyLaudo ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                        Text(didCopyLaudo ? "Copiado" : "Copiar")
                            .font(TextStyle.captionMedium)
                    }
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(AppSurface.card))
                    .overlay(Capsule().stroke(AppSurface.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Haptics.tap()
                    vm.isSalaSheetPresented = true
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Enviar p/ Sala")
                            .font(TextStyle.captionMedium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(BrandColor.primary))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Enviar laudo para Sala do Auxiliar")

                if vm.category == .pelveFeminina {
                    Button {
                        Haptics.tap()
                        vm.isMiomaEditorPresented = true
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Esquema de miomas")
                                .font(TextStyle.captionMedium)
                        }
                        .foregroundStyle(AppSurface.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .frame(minHeight: 30)
                        .background(Capsule().fill(AppSurface.card))
                        .overlay(Capsule().stroke(AppSurface.border, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Abrir esquema visual de miomas")
                }
            }
        }
    }

    private var saveIndicator: some View {
        HStack(spacing: Spacing.xxs) {
            Group {
                switch vm.saveStatus {
                case .idle:
                    if vm.hasLaudoOutput {
                        Image(systemName: "pencil")
                            .foregroundStyle(AppSurface.textMuted)
                        Text("Edite e o app salva.")
                    }
                case .saving:
                    ProgressView().controlSize(.mini)
                    Text("Salvando…")
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SemanticColor.successText)
                    Text("Salvo")
                case .failed(let err):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(SemanticColor.errorText)
                    Text(err).lineLimit(1)
                }
            }
            .id(saveStateKey)
            .transition(.opacity)
        }
        .font(TextStyle.caption)
        .foregroundStyle(AppSurface.textSecondary)
        .animation(.easeOut(duration: 0.15), value: saveStateKey)
    }

    private var saveStateKey: String {
        switch vm.saveStatus {
        case .idle: return "idle"
        case .saving: return "saving"
        case .saved: return "saved"
        case .failed(let err): return "failed-\(err.prefix(20))"
        }
    }

    private func performCopyLaudo() {
        #if canImport(UIKit)
        UIPasteboard.general.string = vm.editedLaudoText.strippedReviewMarkers
        Haptics.success()
        #endif
        withAnimation(.easeOut(duration: 0.15)) { didCopyLaudo = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.15)) { didCopyLaudo = false }
        }
    }

    private func warningBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(SemanticColor.warningText)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Aviso do gerador")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(SemanticColor.warningText)
                Text(message)
                    .font(TextStyle.body)
                    .foregroundStyle(SemanticColor.warningText)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.18)) { vm.lastWarning = nil }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(SemanticColor.warningText)
            }
            .accessibilityLabel("Dispensar aviso")
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(SemanticColor.warningBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(SemanticColor.warningBorder, lineWidth: 1)
        )
    }

    private var sanityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header com toggle expansível — discreto, mostra contagem
            Button {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSanityExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .foregroundStyle(SemanticColor.warningText)
                    Text("\(vm.sanityIssues.count) ponto\(vm.sanityIssues.count == 1 ? "" : "s") a revisar")
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(SemanticColor.warningText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SemanticColor.warningText)
                        .rotationEffect(.degrees(isSanityExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PressableButtonStyle())

            // Lista expansível
            if isSanityExpanded {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Divider().padding(.vertical, Spacing.xs)
                    ForEach(vm.sanityIssues) { issue in
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(systemName: issue.severity == "critical" ? "xmark.octagon.fill" : "exclamationmark.triangle")
                                .foregroundStyle(issue.severity == "critical" ? SemanticColor.errorText : SemanticColor.warningText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.message)
                                    .font(TextStyle.body)
                                    .foregroundStyle(AppSurface.textPrimary)
                                if let range = issue.range, !range.isEmpty {
                                    Text("Trecho: \(range)")
                                        .font(TextStyle.caption)
                                        .foregroundStyle(AppSurface.textMuted)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(SemanticColor.warningBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(SemanticColor.warningBorder, lineWidth: 1)
        )
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.errorText)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Algo deu errado")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(SemanticColor.errorText)
                Text(message)
                    .font(TextStyle.body)
                    .foregroundStyle(SemanticColor.errorText)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.18)) { vm.lastError = nil }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(SemanticColor.errorText)
            }
            .accessibilityLabel("Dispensar erro")
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(SemanticColor.errorBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(SemanticColor.errorBorder, lineWidth: 1)
        )
    }

    private var bottomToolbar: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                Haptics.tap()
                vm.isPlusSheetPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppSurface.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(AppSurface.card))
                    .overlay(Circle().stroke(AppSurface.border, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Adicionar ao laudo (calculadoras e frases)")

            PrimaryButton(
                title: vm.phaseLabel,
                icon: nil,
                isLoading: vm.phase.isBusy,
                isDisabled: !vm.canGenerate
            ) {
                Haptics.press()
                vm.generate(writingStyleId: app.defaultWritingStyleId)
            }

            Button {
                Haptics.tap()
                vm.startRecording()
            } label: {
                Image(systemName: vm.phase == .recording ? "mic.fill" : "mic")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(BrandColor.primary))
                    .brandShadow(.md)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Gravar áudio")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            AppSurface.background
                .opacity(0.98)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func navigate(to destination: AppDestination) {
        vm.isMenuSheetPresented = false
        path.append(destination)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    var alignment: HorizontalAlignment

    init(spacing: CGFloat = 8, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.alignment = alignment
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth.isFinite ? maxWidth : currentX, height: totalHeight), positions)
    }
}

#Preview {
    GenerateView()
        .environment(AppState())
}
