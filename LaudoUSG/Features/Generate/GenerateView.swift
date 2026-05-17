import SwiftUI

struct GenerateView: View {
    @Environment(AppState.self) private var app
    @State private var vm = GenerateViewModel()
    @State private var path: [AppDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .history:
                        HistoryView()
                    case .reportDetail(let id):
                        ReportDetailView(reportId: id)
                    case .analytics:
                        PlaceholderView(
                            title: "Analytics",
                            icon: "chart.bar.fill",
                            message: "Métricas dos seus laudos entram no Sprint 3."
                        )
                        .navigationTitle("Analytics")
                    case .library:
                        PlaceholderView(
                            title: "Biblioteca",
                            icon: "books.vertical.fill",
                            message: "Frases e protocolos favoritos entram em sprints futuros."
                        )
                        .navigationTitle("Biblioteca")
                    case .settings:
                        SettingsView()
                    case .security:
                        PlaceholderView(
                            title: "Segurança",
                            icon: "lock.shield.fill",
                            message: "Sessões, 2FA e auditoria entram em sprints futuros."
                        )
                        .navigationTitle("Segurança")
                    }
                }
        }
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            AppSurface.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                categorySelector
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                if let error = vm.lastError {
                    errorCard(error)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.xs)
                }
                if let warning = vm.lastWarning {
                    warningBanner(warning)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.xs)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        editorArea
                        if !vm.streamedOutput.isEmpty {
                            outputArea
                            if !vm.sanityIssues.isEmpty {
                                sanityCard
                            }
                        }
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                }
            }

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
                onTapSeguranca: { navigate(to: .security) },
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
                onDismiss: { vm.isPlusSheetPresented = false }
            )
        }
        .overlay {
            if vm.isRecordingOverlayPresented {
                RecordingOverlay(
                    isPresented: Binding(get: { vm.isRecordingOverlayPresented }, set: { vm.isRecordingOverlayPresented = $0 }),
                    liveTranscript: vm.speech.currentTranscript,
                    onCancel: { vm.cancelRecording() },
                    onStop: { vm.finishRecording() }
                )
                .transition(.opacity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Button {
                vm.isMenuSheetPresented = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppSurface.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Menu")

            Spacer()

            BrandLogo(size: .small)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(AppSurface.background)
    }

    private var categorySelector: some View {
        Button {
            vm.isCategorySheetPresented = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: vm.category.iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(vm.category.tint)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(vm.category.tint.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Categoria")
                        .font(TextStyle.captionMedium)
                        .foregroundStyle(AppSurface.textSecondary)
                        .textCase(.uppercase)
                    Text(vm.category.label)
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
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
        .accessibilityLabel("Categoria atual: \(vm.category.label). Toque para trocar.")
    }

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(get: { vm.inputText }, set: { vm.inputText = $0 }))
                .font(TextStyle.bodyLarge)
                .scrollContentBackground(.hidden)
                .background(AppSurface.background)
                .foregroundStyle(AppSurface.textPrimary)
                .frame(minHeight: 320)
                .padding(.horizontal, -4)

            if vm.inputText.isEmpty {
                Text("Dite ou digite os achados. Comandos do médico têm prioridade máxima.")
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textMuted)
                    .padding(.top, Spacing.xs)
                    .allowsHitTesting(false)
            }

            if !vm.inputText.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        vm.inputText = ""
                    } label: {
                        Text("Limpar")
                            .font(TextStyle.captionMedium)
                            .foregroundStyle(BrandColor.primary)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxs)
                            .background(
                                Capsule().fill(BrandColor.primaryTint)
                            )
                    }
                    .accessibilityLabel("Limpar achados")
                }
                .offset(y: -36)
            }
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
            Button { vm.lastWarning = nil } label: {
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(SemanticColor.warningText)
                Text("Pontos a revisar")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(SemanticColor.warningText)
            }
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
                vm.lastError = nil
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

    private var outputArea: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Rectangle()
                    .fill(BrandColor.primary)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                Text("Laudo gerado")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(BrandColor.primary)
                    .textCase(.uppercase)
                Spacer()
                if vm.lastReportId != nil, !vm.phase.isBusy {
                    Button {
                        Haptics.tap()
                        openReportAfterGeneration()
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text("Abrir laudo")
                                .font(TextStyle.captionMedium)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(BrandColor.primary)
                    }
                }
            }
            .frame(height: 16)
            Text(vm.streamedOutput)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
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
                icon: vm.phase.isBusy ? nil : "sparkles",
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

    private func openReportAfterGeneration() {
        guard let reportId = vm.lastReportId else { return }
        path.append(.reportDetail(id: reportId))
    }
}

#Preview {
    GenerateView()
        .environment(AppState())
}
