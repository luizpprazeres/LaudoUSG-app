import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct ImageAnalysisSheet: View {
    let category: ReportCategory
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [AnalysisImage] = []
    @State private var isCameraPresented = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                intro
                actions
                selectedImages
                analyzeButton
                if let errorMessage {
                    errorCard(errorMessage)
                }
            }
            .padding(Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Analisar imagem")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fechar", action: onDismiss)
                    .foregroundStyle(BrandColor.primary)
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            Task { await loadPhotos(newItems) }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $isCameraPresented) {
            CameraPicker { image in
                addCameraImage(image)
            }
            .ignoresSafeArea()
        }
        #endif
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(category.label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(category.tint)
                .textCase(.uppercase)
            Text("Envie até 3 imagens com biometria ou Doppler.")
                .font(TextStyle.h3)
                .foregroundStyle(AppSurface.textPrimary)
            Text("O app extrai as medidas e insere o texto nos achados.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.sm) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: max(1, 3 - images.count),
                matching: .images
            ) {
                ImageAnalysisActionButton(title: "Galeria", icon: "photo.on.rectangle")
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(images.count >= 3 || isAnalyzing)

            #if canImport(UIKit)
            Button {
                Haptics.tap()
                isCameraPresented = true
            } label: {
                ImageAnalysisActionButton(title: "Câmera", icon: "camera")
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(images.count >= 3 || isAnalyzing || !UIImagePickerController.isSourceTypeAvailable(.camera))
            #endif
        }
    }

    private var selectedImages: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Imagens")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(images.count)/3")
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textMuted)
            }

            if images.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Spacing.sm)], spacing: Spacing.sm) {
                    ForEach(images) { image in
                        imageTile(image)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppSurface.textMuted)
            Text("Nenhuma imagem selecionada.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var analyzeButton: some View {
        PrimaryButton(
            title: isAnalyzing ? "Analisando…" : "Analisar e inserir",
            icon: "sparkles",
            isLoading: isAnalyzing,
            isDisabled: images.isEmpty || isAnalyzing
        ) {
            analyze()
        }
    }

    private func imageTile(_ image: AnalysisImage) -> some View {
        ZStack(alignment: .topTrailing) {
            #if canImport(UIKit)
            Image(uiImage: image.preview)
                .resizable()
                .scaledToFill()
                .frame(height: 104)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            #else
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppSurface.muted)
                .frame(height: 104)
            #endif

            Button {
                Haptics.tap()
                images.removeAll { $0.id == image.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.black.opacity(0.55)))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(Spacing.xxs)
            .accessibilityLabel("Remover imagem")
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.errorText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(SemanticColor.errorText)
            Spacer(minLength: 0)
            Button {
                errorMessage = nil
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

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        errorMessage = nil
        for item in items.prefix(max(0, 3 - images.count)) {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    addImageData(data)
                }
            } catch {
                errorMessage = "Falha ao carregar uma imagem."
            }
        }
        selectedItems = []
    }

    private func addImageData(_ data: Data) {
        #if canImport(UIKit)
        guard images.count < 3, let uiImage = UIImage(data: data), let jpegData = uiImage.compressedForUpload() else {
            errorMessage = "Não consegui ler a imagem selecionada."
            return
        }
        images.append(AnalysisImage(data: jpegData, preview: uiImage))
        Haptics.tap()
        #endif
    }

    #if canImport(UIKit)
    private func addCameraImage(_ image: UIImage) {
        guard images.count < 3, let data = image.compressedForUpload() else {
            errorMessage = "Não consegui ler a imagem da câmera."
            return
        }
        images.append(AnalysisImage(data: data, preview: image))
        Haptics.tap()
    }
    #endif

    private func analyze() {
        guard !images.isEmpty else { return }
        isAnalyzing = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let result = try await ImageAnalysisService.analyze(images: images.map(\.data), category: category)
                let text = ImageAnalysisService.format(result, category: category)
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ImageAnalysisError.emptyResult(nil)
                }
                Haptics.success()
                onInsert(text)
                onDismiss()
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

private struct ImageAnalysisActionButton: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(TextStyle.bodySemibold)
        }
        .foregroundStyle(AppSurface.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }
}

#if canImport(UIKit)
private struct AnalysisImage: Identifiable {
    let id = UUID()
    let data: Data
    let preview: UIImage
}
#else
private struct AnalysisImage: Identifiable {
    let id = UUID()
    let data: Data
}
#endif

#Preview {
    NavigationStack {
        ImageAnalysisSheet(
            category: .obstetrica,
            onInsert: { _ in },
            onDismiss: {}
        )
    }
}
