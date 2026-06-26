import SwiftUI
import StoreKit

/// Tela de assinatura nativa (In-App Purchase). Exibe os planos reais do StoreKit
/// com preço em BRL, trial, compra via Apple e restauração. Cumpre 3.1.1: a compra
/// de recursos pagos acontece via IAP dentro do app.
@MainActor
struct PaywallSheet: View {
    let store: StoreManager
    /// Chamado após compra/restauração bem-sucedida (para fechar e atualizar a UI).
    let onSuccess: () -> Void
    let onDismiss: () -> Void

    @State private var selectedID: String?
    @State private var inFlightMessage: String?

    private let termsURL = URL(string: "https://laudousg.com/terms")!
    private let privacyURL = URL(string: "https://laudousg.com/privacy")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurface.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        header
                        benefits
                        plans
                        if let inFlightMessage {
                            Text(inFlightMessage)
                                .font(TextStyle.caption)
                                .foregroundStyle(SemanticColor.errorText)
                        }
                        subscribeButton
                        secondaryActions
                        legalFooter
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.lg)
                }
            }
            .navigationTitle("Planos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar", action: onDismiss)
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            if selectedID == nil {
                // Pré-seleciona o Profissional anual (melhor valor) se disponível.
                selectedID = store.proYearlyProduct?.id ?? store.products.first?.id
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(BrandColor.primary)
            Text("Desbloqueie todo o LaudoUSG")
                .font(TextStyle.h2)
                .foregroundStyle(AppSurface.textPrimary)
            Text("7 dias grátis, depois renova automaticamente. Cancele quando quiser.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            benefitRow("Laudos com IA a partir do seu ditado")
            benefitRow("Consultor IA para revisar e tirar dúvidas")
            benefitRow("Até 800 laudos/mês (Essencial) ou ilimitado (Profissional)")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(AppSurface.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).stroke(AppSurface.border, lineWidth: 1))
    }

    // MARK: - Planos

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            VStack(spacing: Spacing.sm) {
                if store.isLoadingProducts {
                    ProgressView().tint(BrandColor.primary)
                    Text("Carregando planos…")
                        .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
                } else {
                    Text("Não foi possível carregar os planos.")
                        .font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
                    Button("Tentar novamente") { Task { await store.loadProducts() } }
                        .font(TextStyle.bodyMedium).foregroundStyle(BrandColor.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(store.products, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selectedID == product.id
        return Button {
            Haptics.tap()
            selectedID = product.id
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? BrandColor.primary : AppSurface.textMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(planTitle(product))
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                    if let trial = trialLabel(product) {
                        Text(trial)
                            .font(TextStyle.caption)
                            .foregroundStyle(BrandColor.primary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(TextStyle.bodyLargeSemibold)
                        .foregroundStyle(AppSurface.textPrimary)
                    Text(periodLabel(product))
                        .font(TextStyle.caption)
                        .foregroundStyle(AppSurface.textSecondary)
                }
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(AppSurface.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(isSelected ? BrandColor.primary : AppSurface.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ações

    private var subscribeButton: some View {
        Button {
            guard let id = selectedID, let product = store.product(id: id) else { return }
            Task {
                inFlightMessage = nil
                let ok = await store.purchase(product)
                if ok {
                    Haptics.success()
                    onSuccess()
                } else if let err = store.lastErrorMessage {
                    inFlightMessage = err
                }
            }
        } label: {
            HStack {
                if store.isPurchasing { ProgressView().tint(.white) }
                Text(store.isPurchasing ? "Processando…" : "Assinar")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(BrandColor.primary))
        }
        .disabled(selectedID == nil || store.isPurchasing || store.products.isEmpty)
        .opacity((selectedID == nil || store.products.isEmpty) ? 0.5 : 1)
    }

    private var secondaryActions: some View {
        VStack(spacing: Spacing.sm) {
            Button("Restaurar compras") {
                Task {
                    await store.restore()
                    if store.hasActiveSubscription { Haptics.success(); onSuccess() }
                    else { inFlightMessage = store.lastErrorMessage ?? "Nenhuma assinatura para restaurar." }
                }
            }
            .font(TextStyle.bodyMedium)
            .foregroundStyle(BrandColor.primary)

            // Compatibilidade multiplataforma (3.1.3b): quem assinou na web atualiza o acesso.
            // Ação secundária e discreta — não substitui "Assinar".
            Button("Já assino — atualizar acesso") {
                Haptics.tap()
                onSuccess()
            }
            .font(TextStyle.caption)
            .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private var legalFooter: some View {
        VStack(spacing: Spacing.xs) {
            Text("A assinatura renova automaticamente pelo mesmo período, salvo cancelamento até 24h antes do fim do ciclo. Gerencie ou cancele em Ajustes › Apple ID › Assinaturas.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.sm) {
                Link("Termos de Uso", destination: termsURL)
                Text("·").foregroundStyle(AppSurface.textMuted)
                Link("Privacidade", destination: privacyURL)
            }
            .font(TextStyle.caption)
            .foregroundStyle(BrandColor.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Helpers

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BrandColor.primary)
                .frame(width: 20, height: 20)
            Text(text).font(TextStyle.body).foregroundStyle(AppSurface.textSecondary)
        }
    }

    private func planTitle(_ product: Product) -> String {
        // Usa o nome localizado do StoreKit; fallback por id.
        if !product.displayName.isEmpty { return product.displayName }
        switch product.id {
        case StoreManager.essentialMonthly: return "Essencial Mensal"
        case StoreManager.essentialYearly:  return "Essencial Anual"
        case StoreManager.proMonthly:       return "Profissional Mensal"
        case StoreManager.proYearly:        return "Profissional Anual"
        default: return product.id
        }
    }

    private func periodLabel(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        switch period.unit {
        case .day:   return period.value == 1 ? "por dia" : "a cada \(period.value) dias"
        case .week:  return "por semana"
        case .month: return period.value == 1 ? "por mês" : "a cada \(period.value) meses"
        case .year:  return "por ano"
        @unknown default: return ""
        }
    }

    private func trialLabel(_ product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        if p.unit == .week { return "\(p.value * 7) dias grátis" }
        if p.unit == .day { return "\(p.value) dias grátis" }
        if p.unit == .month { return "\(p.value) \(p.value == 1 ? "mês" : "meses") grátis" }
        return "Período grátis"
    }
}
