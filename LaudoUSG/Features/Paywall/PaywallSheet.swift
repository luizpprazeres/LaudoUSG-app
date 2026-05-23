import SwiftUI
import StoreKit

@MainActor
struct PaywallSheet: View {
    let onSuccess: () -> Void
    let onDismiss: () -> Void

    @State private var iap = IAPService.shared
    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var purchaseError: String?
    @State private var didStart: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppSurface.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        header
                        periodToggle
                        planCards
                        ctaButton
                        if let purchaseError {
                            errorBanner(purchaseError)
                        }
                        footer
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.lg)
                }
                if iap.isLoadingProducts && iap.products.isEmpty {
                    loadingOverlay
                }
            }
            .navigationTitle("Escolha seu plano")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar", action: onDismiss)
                        .foregroundStyle(BrandColor.primary)
                }
            }
            .task {
                guard !didStart else { return }
                didStart = true
                iap.start()
                await iap.loadProducts()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("3 dias grátis pra testar")
                .font(TextStyle.h2)
                .foregroundStyle(AppSurface.textPrimary)
            Text("Cancele a qualquer momento antes do fim do trial.")
                .font(TextStyle.bodyLarge)
                .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private var periodToggle: some View {
        HStack(spacing: 0) {
            periodButton(.monthly, label: "Mensal")
            periodButton(.yearly, label: "Anual −16%")
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(AppSurface.card)
        )
    }

    private func periodButton(_ period: SubscriptionPeriod, label: String) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.18)) { selectedPeriod = period }
        } label: {
            Text(label)
                .font(TextStyle.bodyMedium)
                .foregroundStyle(selectedPeriod == period ? .white : AppSurface.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(selectedPeriod == period ? BrandColor.primary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var planCards: some View {
        VStack(spacing: Spacing.sm) {
            planCard(tier: .essencial)
            planCard(tier: .pro)
        }
    }

    private func planCard(tier: SubscriptionTier) -> some View {
        let product = productFor(tier: tier, period: selectedPeriod)
        let isSelected = selectedTier == tier
        let isRecommended = tier == .pro

        return Button {
            Haptics.tap()
            withAnimation(.easeOut(duration: 0.18)) { selectedTier = tier }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(tier == .essencial ? "Essencial" : "PRO")
                        .font(TextStyle.subtitle)
                        .foregroundStyle(AppSurface.textPrimary)
                    if isRecommended {
                        Text("RECOMENDADO")
                            .font(TextStyle.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(BrandColor.primary)
                            )
                    }
                    Spacer()
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? BrandColor.primary : AppSurface.textMuted)
                }
                priceLine(product: product)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ForEach(featuresFor(tier: tier), id: \.self) { feature in
                        featureRow(feature)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(AppSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(isSelected ? BrandColor.primary : AppSurface.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func priceLine(product: Product?) -> some View {
        Group {
            if let product {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Text(product.displayPrice)
                        .font(TextStyle.h3)
                        .foregroundStyle(AppSurface.textPrimary)
                    Text(selectedPeriod == .monthly ? "/mês" : "/ano")
                        .font(TextStyle.bodyMedium)
                        .foregroundStyle(AppSurface.textSecondary)
                }
            } else {
                Text("—")
                    .font(TextStyle.h3)
                    .foregroundStyle(AppSurface.textMuted)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(BrandColor.primary)
                .frame(width: 16, height: 16)
            Text(text)
                .font(TextStyle.body)
                .foregroundStyle(AppSurface.textSecondary)
        }
    }

    private var ctaButton: some View {
        Button {
            Task { await startPurchase() }
        } label: {
            HStack {
                if iap.purchaseInProgress {
                    ProgressView().tint(.white)
                } else {
                    Text("Iniciar 3 dias grátis")
                        .font(TextStyle.bodyLargeSemibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(BrandColor.primary)
            )
        }
        .disabled(iap.purchaseInProgress || productFor(tier: selectedTier, period: selectedPeriod) == nil)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(TextStyle.body)
            .foregroundStyle(SemanticColor.errorText)
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(SemanticColor.errorText.opacity(0.1))
            )
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                Task { await restorePurchases() }
            } label: {
                Text("Restaurar compras")
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(BrandColor.primary)
            }
            Text("Renovação automática após o trial. Cancele em Ajustes do iPhone → Sua conta → Assinaturas.")
                .font(TextStyle.caption)
                .foregroundStyle(AppSurface.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView("Carregando planos...")
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(AppSurface.card)
                )
        }
    }

    private func productFor(tier: SubscriptionTier, period: SubscriptionPeriod) -> Product? {
        let id: String
        switch (tier, period) {
        case (.essencial, .monthly): id = IAPProductID.essencialMonthly
        case (.essencial, .yearly): id = IAPProductID.essencialYearly
        case (.pro, .monthly): id = IAPProductID.proMonthly
        case (.pro, .yearly): id = IAPProductID.proYearly
        }
        return iap.products.first { $0.id == id }
    }

    private func featuresFor(tier: SubscriptionTier) -> [String] {
        switch tier {
        case .essencial:
            return [
                "Geração ilimitada de laudos",
                "Todas as categorias de USG",
                "Histórico + Sala do Auxiliar",
                "Análise de imagem por IA"
            ]
        case .pro:
            return [
                "Tudo do Essencial",
                "Consultor IA (diagnósticos diferenciais)",
                "Suporte prioritário",
                "Novas features em primeira mão"
            ]
        }
    }

    private func startPurchase() async {
        purchaseError = nil
        guard let product = productFor(tier: selectedTier, period: selectedPeriod) else {
            purchaseError = "Produto não disponível. Tente novamente em alguns segundos."
            return
        }
        do {
            _ = try await iap.purchase(product)
            onSuccess()
        } catch IAPError.userCancelled {
            // não mostra erro pra cancelamento
        } catch let error as IAPError {
            purchaseError = error.errorDescription
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        purchaseError = nil
        do {
            try await iap.restorePurchases()
            onSuccess()
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}
