import SwiftUI
import Observation
import UIKit

@Observable
@MainActor
private final class ComputerCompanionViewModel {
    private static let storageKey = "laudousg.workspace-companion.session.v1"

    var code = ""
    var session: WorkspaceCompanionSession?
    var kind: WorkspaceCompanionInputKind = .text
    var text = ""
    var isWorking = false
    var didSend = false
    var errorMessage: String?

    init() {
        restoreSession()
    }

    var canConnect: Bool {
        code.count == 6 && !isWorking
    }

    var canSend: Bool {
        session?.isActive == true
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isWorking
    }

    func updateCode(_ value: String) {
        let normalized = String(
            value
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
                .prefix(6)
        )
        if code != normalized { code = normalized }
        errorMessage = nil
    }

    func connect() async {
        guard canConnect else {
            errorMessage = "Digite o código de 6 caracteres mostrado no computador."
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let paired = try await WorkspaceCompanionService.pair(code: code)
            session = paired
            persist(paired)
            Haptics.success()
        } catch {
            errorMessage = connectionMessage(for: error)
            Haptics.error()
        }
    }

    func send(categoryCode: String) async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let session, session.isActive else {
            disconnect()
            errorMessage = "A conexão terminou. Gere outro código no computador."
            return
        }
        guard !content.isEmpty else {
            errorMessage = "Digite o texto ou as medidas antes de enviar."
            return
        }

        isWorking = true
        didSend = false
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await WorkspaceCompanionService.send(
                sessionId: session.id,
                kind: kind,
                text: content,
                categoryCode: categoryCode
            )
            text = ""
            didSend = true
            Haptics.success()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.8))
                self?.didSend = false
            }
        } catch {
            if case APIError.http(let status, _) = error, status == 404 || status == 409 {
                disconnect()
                errorMessage = "A conexão foi encerrada no computador. Faça um novo pareamento."
            } else {
                errorMessage = "Não foi possível enviar. Verifique a conexão e tente novamente."
            }
            Haptics.error()
        }
    }

    func disconnect() {
        session = nil
        code = ""
        text = ""
        didSend = false
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        Haptics.tap()
    }

    private func connectionMessage(for error: Error) -> String {
        if case APIError.http(let status, _) = error, status == 400 || status == 404 {
            return "Código inválido, expirado ou vinculado a outra conta."
        }
        return "Não foi possível conectar. Verifique a internet e tente novamente."
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode(WorkspaceCompanionSession.self, from: data),
              stored.isActive else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            return
        }
        session = stored
    }

    private func persist(_ session: WorkspaceCompanionSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

struct ComputerCompanionScreen: View {
    let category: ReportCategory

    @State private var vm = ComputerCompanionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let session = vm.session, session.isActive {
                    connectedContent(session)
                } else {
                    pairingContent
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppSurface.background.ignoresSafeArea())
    }

    private var pairingContent: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(BrandColor.primary)

                Text("Use o iPhone como entrada do laudo")
                    .font(TextStyle.subtitle)
                    .foregroundStyle(AppSurface.textPrimary)
                    .multilineTextAlignment(.center)

                Text("No computador, abra Celular e toque em Parear. A conexão ficará ativa durante o seu turno, por até 10 horas.")
                    .font(TextStyle.body)
                    .foregroundStyle(AppSurface.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Spacing.md)

            PairingCodeField(text: $vm.code)
                .onChange(of: vm.code) { _, value in vm.updateCode(value) }
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(BrandColor.primaryTint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(BrandColor.primaryBorder, lineWidth: 1)
                )
                .accessibilityLabel("Código de pareamento")

            errorView

            PrimaryButton(
                title: "Conectar",
                icon: "link",
                isLoading: vm.isWorking,
                isDisabled: !vm.canConnect
            ) {
                Task { await vm.connect() }
            }
        }
    }

    private func connectedContent(_ session: WorkspaceCompanionSession) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Computador conectado")
                        .font(TextStyle.bodySemibold)
                        .foregroundStyle(AppSurface.textPrimary)

                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(session.remainingLabel)
                            .font(TextStyle.caption)
                            .foregroundStyle(AppSurface.textSecondary)
                    }
                }

                Spacer()

                Button("Desconectar") { vm.disconnect() }
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(AppSurface.textSecondary)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(BrandColor.primaryTint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(BrandColor.primaryBorder, lineWidth: 1)
            )

            HStack(spacing: Spacing.xs) {
                ForEach(WorkspaceCompanionInputKind.allCases) { option in
                    kindButton(option)
                }
            }

            ZStack(alignment: .topLeading) {
                if vm.text.isEmpty {
                    Text(vm.kind.placeholder)
                        .font(TextStyle.bodyLarge)
                        .foregroundStyle(AppSurface.textMuted)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $vm.text)
                    .font(TextStyle.bodyLarge)
                    .foregroundStyle(AppSurface.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xs)
                    .frame(minHeight: 150)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )

            Text("Chega como uma sugestão no laudo aberto e só entra no texto depois da confirmação no computador.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            errorView

            PrimaryButton(
                title: vm.didSend ? "Enviado" : "Enviar ao computador",
                icon: vm.didSend ? "checkmark" : "paperplane.fill",
                isLoading: vm.isWorking,
                isDisabled: !vm.canSend
            ) {
                Task { await vm.send(categoryCode: category.rawValue) }
            }
        }
    }

    private func kindButton(_ option: WorkspaceCompanionInputKind) -> some View {
        let isSelected = vm.kind == option
        return Button {
            Haptics.tap()
            vm.kind = option
        } label: {
            Text(option.label)
                .font(TextStyle.bodySemibold)
                .foregroundStyle(isSelected ? Color.white : AppSurface.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isSelected ? BrandColor.primary : AppSurface.card)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? BrandColor.primary : AppSurface.border, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = vm.errorMessage {
            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(error)
            }
            .font(TextStyle.footnote)
            .foregroundStyle(SemanticColor.errorText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(SemanticColor.errorBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(SemanticColor.errorBorder, lineWidth: 1)
            )
        }
    }
}

private struct PairingCodeField: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.textAlignment = .center
        field.font = .systemFont(ofSize: 20, weight: .semibold)
        field.textColor = UIColor(AppSurface.textPrimary)
        field.tintColor = UIColor(BrandColor.primary)
        field.backgroundColor = .clear
        field.keyboardType = .asciiCapable
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .done
        field.clearButtonMode = .never
        field.adjustsFontForContentSizeCategory = true
        field.attributedPlaceholder = NSAttributedString(
            string: "DIGITE O CÓDIGO",
            attributes: [
                .foregroundColor: UIColor(AppSurface.textSecondary),
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
        )
        field.addTarget(context.coordinator, action: #selector(Coordinator.didChange(_:)), for: .editingChanged)
        field.accessibilityLabel = "Código de pareamento"
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text { field.text = text }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func didChange(_ field: UITextField) {
            let normalized = Self.normalize(field.text ?? "")
            if field.text != normalized { field.text = normalized }
            if text.wrappedValue != normalized { text.wrappedValue = normalized }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        private static func normalize(_ value: String) -> String {
            String(
                value
                    .uppercased()
                    .filter { $0.isLetter || $0.isNumber }
                    .prefix(6)
            )
        }
    }
}

#Preview {
    NavigationStack {
        ComputerCompanionScreen(category: .abdomenTotal)
    }
}
