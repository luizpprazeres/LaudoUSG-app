import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct EditProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var crm = ""
    @State private var uf = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false
    @FocusState private var focused: Field?

    enum Field {
        case name
        case crm
        case uf
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                section(title: "Perfil") {
                    labeledField(
                        "Nome",
                        text: $name,
                        field: .name,
                        keyboard: .default,
                        capitalization: .words,
                        placeholder: "Seu nome"
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                    labeledField(
                        "CRM",
                        text: $crm,
                        field: .crm,
                        keyboard: .numberPad,
                        capitalization: .never,
                        placeholder: "12345"
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)

                    labeledField(
                        "UF",
                        text: $uf,
                        field: .uf,
                        keyboard: .default,
                        capitalization: .characters,
                        placeholder: "SP"
                    )
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.md)
                }

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                PrimaryButton(
                    title: "Salvar",
                    icon: nil,
                    isLoading: isSaving,
                    isDisabled: !isValid || isSaving
                ) {
                    save()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .background(AppSurface.background.ignoresSafeArea())
        .navigationTitle("Editar perfil")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancelar") {
                    Haptics.tap()
                    dismiss()
                }
                .foregroundStyle(BrandColor.primary)
            }
        }
        .alert("Perfil atualizado", isPresented: $didSave) {
            Button("OK") {
                dismiss()
            }
        }
        .onAppear {
            name = app.profile?.displayName ?? ""
            crm = app.profile?.crm ?? ""
            uf = app.profile?.uf ?? ""
        }
        .onChange(of: crm) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue { crm = filtered }
        }
        .onChange(of: uf) { _, newValue in
            let normalized = String(newValue.filter { $0.isLetter }.prefix(2)).uppercased()
            if normalized != newValue { uf = normalized }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !crm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            uf.trimmingCharacters(in: .whitespacesAndNewlines).count == 2
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

    private func labeledField(
        _ label: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType,
        capitalization: TextInputAutocapitalization,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            TextField(placeholder, text: text)
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textPrimary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(true)
                .focused($focused, equals: field)
                .submitLabel(field == .uf ? .done : .next)
                .onSubmit { moveFocus(after: field) }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(AppSurface.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(focused == field ? BrandColor.primary : AppSurface.border, lineWidth: 1)
                )
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SemanticColor.errorText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(SemanticColor.errorText)
            Spacer(minLength: 0)
        }
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

    private func moveFocus(after field: Field) {
        switch field {
        case .name:
            focused = .crm
        case .crm:
            focused = .uf
        case .uf:
            save()
        }
    }

    private func save() {
        guard isValid, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        focused = nil
        Task { @MainActor in
            do {
                try await ProfileService.updateProfile(name: name, crm: crm, uf: uf)
                app.updateProfile(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    crm: crm.trimmingCharacters(in: .whitespacesAndNewlines),
                    uf: uf.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                )
                Haptics.success()
                didSave = true
            } catch {
                Haptics.error()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
    }
    .environment(AppState())
}
