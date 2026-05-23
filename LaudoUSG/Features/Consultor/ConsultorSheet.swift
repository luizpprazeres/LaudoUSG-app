import SwiftUI
import PhotosUI

@MainActor
struct ConsultorSheet: View {
    @State var vm: ConsultorViewModel
    let onDismiss: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomAnchor

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurface.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    messagesScroll
                    inputBar
                }
            }
            .navigationTitle("Consultor IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar", action: onDismiss)
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .onChange(of: pickerItems) { _, newItems in
            Task { await loadPickerImages(newItems) }
        }
    }

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(vm.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if vm.isStreaming {
                        streamingIndicator
                            .id("streaming")
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: vm.messages.last?.text) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: ConsultorMessage) -> some View {
        if msg.role == .user {
            HStack {
                Spacer(minLength: Spacing.xl)
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    if !msg.imagesBase64.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.xs) {
                                ForEach(Array(msg.imagesBase64.enumerated()), id: \.offset) { _, base64 in
                                    imageThumbnail(base64: base64, size: 80)
                                }
                            }
                        }
                    }
                    if !msg.text.isEmpty {
                        Text(msg.text)
                            .font(TextStyle.bodyLarge)
                            .foregroundStyle(.white)
                            .padding(Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                    .fill(BrandColor.primary)
                            )
                    }
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    if msg.text.isEmpty {
                        streamingIndicator
                    } else {
                        MarkdownText(raw: msg.text)
                    }
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(AppSurface.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(AppSurface.border, lineWidth: 1)
                )
                Spacer(minLength: Spacing.xl)
            }
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { idx in
                Circle()
                    .fill(BrandColor.primary)
                    .frame(width: 6, height: 6)
                    .opacity(0.4)
                    .scaleEffect(0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(idx) * 0.18),
                        value: vm.isStreaming
                    )
            }
        }
        .padding(Spacing.sm)
    }

    private var inputBar: some View {
        VStack(spacing: Spacing.xs) {
            if !vm.pendingImagesBase64.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(Array(vm.pendingImagesBase64.enumerated()), id: \.offset) { idx, base64 in
                            ZStack(alignment: .topTrailing) {
                                imageThumbnail(base64: base64, size: 56)
                                Button {
                                    vm.removeImage(at: idx)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white, .black.opacity(0.7))
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            if let err = vm.lastError {
                Text(err)
                    .font(TextStyle.caption)
                    .foregroundStyle(SemanticColor.errorText)
                    .padding(.horizontal, Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: max(0, 5 - vm.pendingImagesBase64.count), matching: .images) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(vm.canAddImage ? BrandColor.primary : AppSurface.textMuted)
                        .frame(width: 40, height: 40)
                }
                .disabled(!vm.canAddImage)

                TextField("Pergunte ao consultor...", text: $vm.draftText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .font(TextStyle.bodyLarge)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .fill(AppSurface.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                            .stroke(AppSurface.border, lineWidth: 1)
                    )

                Button {
                    Haptics.tap()
                    isInputFocused = false
                    vm.send()
                } label: {
                    Image(systemName: vm.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(vm.canSend || vm.isStreaming ? BrandColor.primary : AppSurface.textMuted)
                }
                .disabled(!vm.canSend && !vm.isStreaming)
                .accessibilityLabel(vm.isStreaming ? "Interromper" : "Enviar")
                .onTapGesture {
                    if vm.isStreaming { vm.cancelStream() }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
        }
        .padding(.top, Spacing.xs)
        .background(AppSurface.background)
    }

    private func imageThumbnail(base64 dataURL: String, size: CGFloat) -> some View {
        let prefix = "base64,"
        let comps = dataURL.components(separatedBy: prefix)
        let raw = comps.count > 1 ? comps[1] : dataURL
        if let data = Data(base64Encoded: raw), let uiImage = UIImage(data: data) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            )
        }
        return AnyView(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(AppSurface.muted)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(AppSurface.textMuted)
                )
        )
    }

    private func loadPickerImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard vm.canAddImage else { break }
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.7) {
                    vm.attachImage(compressed)
                } else {
                    vm.attachImage(data)
                }
            }
        }
        pickerItems = []
    }
}
