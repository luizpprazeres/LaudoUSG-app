import Foundation
import StoreKit
import Observation

/// Nível de plano derivado de uma assinatura ativa. `pro` > `essential`.
enum PlanTier: Int, Comparable, Sendable {
    case essential = 1
    case pro = 2
    static func < (lhs: PlanTier, rhs: PlanTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Mapeia para o campo `plan` usado pelo backend/gating (`hasPro`, `hasEssencialOrAbove`).
    var backendPlan: String { self == .pro ? "clinic" : "essential" }
}

/// Camada única de In-App Purchase (StoreKit 2). Carrega os produtos, mantém o
/// entitlement local atualizado (via `Transaction.currentEntitlements` + listener de
/// `Transaction.updates`) e expõe compra/restauração. NÃO substitui o `AppState`:
/// o `AppState` combina este entitlement com o `plan` vindo do backend (web).
@Observable
@MainActor
final class StoreManager {
    /// Product IDs criados no App Store Connect (grupo "LaudoUSG Planos").
    static let essentialMonthly = "com.laudousg.LaudoUSG.essential.monthly"
    static let essentialYearly  = "com.laudousg.LaudoUSG.essential.yearly"
    static let proMonthly       = "com.laudousg.LaudoUSG.pro.monthly"
    static let proYearly        = "com.laudousg.LaudoUSG.pro.yearly"
    static let allProductIDs: [String] = [essentialMonthly, essentialYearly, proMonthly, proYearly]

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    var isLoadingProducts = false
    var isPurchasing = false
    var lastErrorMessage: String?

    private var updatesListener: Task<Void, Never>?

    init() {
        // Listener de transações que chegam fora do fluxo de compra (renovação,
        // Ask to Buy, compra feita em outro device, etc.).
        updatesListener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Entitlement derivado

    /// Maior nível de plano ativo via IAP (ou nil se nenhum).
    var entitlementTier: PlanTier? {
        if purchasedProductIDs.contains(where: { $0.contains(".pro.") }) { return .pro }
        if purchasedProductIDs.contains(where: { $0.contains(".essential.") }) { return .essential }
        return nil
    }

    var hasActiveSubscription: Bool { entitlementTier != nil }

    // MARK: - Produtos (agrupados para a UI)

    func product(id: String) -> Product? { products.first { $0.id == id } }

    var essentialMonthlyProduct: Product? { product(id: Self.essentialMonthly) }
    var essentialYearlyProduct: Product?  { product(id: Self.essentialYearly) }
    var proMonthlyProduct: Product?       { product(id: Self.proMonthly) }
    var proYearlyProduct: Product?        { product(id: Self.proYearly) }

    // MARK: - Carregamento

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            // Ordem estável: Essencial antes de Pro, mensal antes de anual.
            products = loaded.sorted { lhs, rhs in
                let order = Self.allProductIDs
                return (order.firstIndex(of: lhs.id) ?? 0) < (order.firstIndex(of: rhs.id) ?? 0)
            }
        } catch {
            lastErrorMessage = "Não foi possível carregar os planos. Verifique a conexão e tente novamente."
        }
    }

    /// Recalcula o entitlement a partir das transações ativas verificadas.
    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Ignora o que já foi revogado/expirado.
            if transaction.revocationDate == nil,
               !(transaction.isUpgraded) {
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
    }

    // MARK: - Compra / Restauração

    /// Retorna true se a compra concluiu com sucesso e o entitlement foi liberado.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "Não foi possível validar a compra."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .pending:
                // Ex.: Ask to Buy (aprovação dos pais). Não é erro.
                lastErrorMessage = "Compra pendente de aprovação."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = "A compra falhou. Tente novamente."
            return false
        }
    }

    /// Restaura compras anteriores (sincroniza com a App Store). Mostra UI do sistema.
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "Não foi possível restaurar as compras."
        }
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}
