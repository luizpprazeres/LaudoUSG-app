import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class SalaPairingViewModel {
    var pairing: SalaPairing?
    var isLoading: Bool = false
    var error: String?
    var didCopyCode: Bool = false
    var didCopyURL: Bool = false

    func generate() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            pairing = try await SalaService.generatePairing()
            Haptics.success()
        } catch let err as APIError {
            error = err.errorDescription
            Haptics.error()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func revoke() async {
        do {
            _ = try await SalaService.revoke()
            pairing = nil
            Haptics.warning()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}

struct SalaPairingSheet: View {
    let onDismiss: () -> Void
    @State private var vm = SalaPairingViewModel()
    @State private var now: Date = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if vm.isLoading && vm.pairing == nil {
                        loadingState
                    } else if let pairing = vm.pairing {
                        successCard(pairing)
                        instructionsCard
                        actionButtons(pairing)
                    } else if let error = vm.error {
                        errorState(error)
                    } else {
                        introCard
                        Button {
                            Haptics.press()
                            Task { await vm.generate() }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "rectangle.connected.to.line.below")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Gerar código de pareamento")
                                    .font(TextStyle.bodySemibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                                    .fill(BrandColor.primary)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
            }
            .background(AppSurface.background.ignoresSafeArea())
            .navigationTitle("Sala do Auxiliar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar", action: onDismiss)
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(ticker) { now = $0 }
    }

    private var introCard: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(BrandColor.primary)
            Text("Sessão de turno com o auxiliar")
                .font(TextStyle.subtitle)
                .foregroundStyle(AppSurface.textPrimary)
                .multilineTextAlignment(.center)
            Text("Gere a sessão no início do turno. O auxiliar digita o código UMA VEZ em sala.laudousg.com e fica conectado pelo resto do dia. Cada laudo que você enviar aparece automaticamente lá.")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private func successCard(_ pairing: SalaPairing) -> some View {
        VStack(spacing: Spacing.md) {
            Text("Código da sala")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)

            Text(pairing.formattedCode)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .monospaced()
                .foregroundStyle(BrandColor.primary)
                .accessibilityLabel("Código \(pairing.code.map { String($0) }.joined(separator: " "))")

            HStack(spacing: Spacing.xs) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .medium))
                Text(remainingLabel(for: pairing))
                    .font(TextStyle.captionMedium)
            }
            .foregroundStyle(AppSurface.textSecondary)
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .fill(BrandColor.primaryTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
                .stroke(BrandColor.primaryBorder, lineWidth: 1)
        )
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Como funciona")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            instructionRow(number: "1", text: "O auxiliar abre sala.laudousg.com uma vez (em qualquer navegador)")
            instructionRow(number: "2", text: "Digita o código e deixa a aba aberta o turno inteiro")
            instructionRow(number: "3", text: "Cada laudo que você enviar via 'Enviar p/ Sala' aparece lá em segundos")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(number)
                .font(TextStyle.captionMedium)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(BrandColor.primary))
            Text(text)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }

    private func actionButtons(_ pairing: SalaPairing) -> some View {
        VStack(spacing: Spacing.xs) {
            Button {
                copy(pairing.code)
                vm.didCopyCode = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    vm.didCopyCode = false
                }
            } label: {
                actionLabel(
                    icon: vm.didCopyCode ? "checkmark" : "doc.on.doc",
                    title: vm.didCopyCode ? "Código copiado" : "Copiar código"
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                copy(pairing.salaShortUrl)
                vm.didCopyURL = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    vm.didCopyURL = false
                }
            } label: {
                actionLabel(
                    icon: vm.didCopyURL ? "checkmark" : "link",
                    title: vm.didCopyURL ? "URL copiada" : "Copiar URL (sala.laudousg.com)"
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                Haptics.warning()
                Task { await vm.revoke() }
            } label: {
                actionLabel(
                    icon: "xmark.circle",
                    title: "Revogar sala",
                    isDestructive: true
                )
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, Spacing.xs)
        }
    }

    private func actionLabel(icon: String, title: String, isDestructive: Bool = false) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(TextStyle.bodyMedium)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(isDestructive ? SemanticColor.errorText : AppSurface.textPrimary)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(isDestructive ? SemanticColor.errorBorder : AppSurface.border, lineWidth: 1)
        )
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(BrandColor.primary)
            Text("Gerando código…")
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(SemanticColor.errorText)
            Text(message)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar de novo") {
                Task { await vm.generate() }
            }
            .foregroundStyle(BrandColor.primary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func remainingLabel(for pairing: SalaPairing) -> String {
        let remaining = pairing.expiresAt.timeIntervalSince(now)
        if remaining <= 0 { return "Expirado — gere outro" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "Válido por mais \(hours)h \(minutes)min"
        }
        return "Válido por mais \(minutes)min"
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        Haptics.success()
        #endif
    }
}

#Preview {
    SalaPairingSheet(onDismiss: {})
}
