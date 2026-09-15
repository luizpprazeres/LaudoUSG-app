import Foundation
import StoreKit
import Observation
import os

/// Camada única de In-App Purchase (StoreKit 2).
///
/// Regras que este objeto garante — e que o backend confere de novo:
///
/// 1. **Posse.** Toda compra sai com `appAccountToken` = id do usuário LaudoUSG
///    logado. O entitlement local só conta transações cujo token é o do usuário
///    vinculado (`bind(userID:)`); trocar de conta (`clearAccount()`) zera o
///    acesso, mesmo que a conta Apple continue assinante.
/// 2. **`finish()` só depois do backend aceitar.** O JWS vai para
///    `/api/iap/validate-receipt`; se o servidor não confirmar (rede, 5xx, 4xx),
///    a transação fica pendente no StoreKit e é reentregue — no próximo login,
///    restore ou abertura (`syncWithBackend`). O acesso local (StoreKit) não
///    depende disso: quem pagou à Apple usa o app.
/// 3. **Ressincronização idempotente** em login e restore: reenvia as
///    transações vigentes do usuário; o backend converge para o mesmo estado.
///
/// NÃO substitui o `AppState`: ele combina este entitlement com o `plan` do
/// backend (web) — vale o maior.
@Observable
@MainActor
final class StoreManager {
    /// Product IDs criados no App Store Connect (grupo "LaudoUSG Planos").
    nonisolated static let essentialMonthly = "com.laudousg.LaudoUSG.essential.monthly"
    nonisolated static let essentialYearly  = "com.laudousg.LaudoUSG.essential.yearly"
    nonisolated static let proMonthly       = "com.laudousg.LaudoUSG.pro.monthly"
    nonisolated static let proYearly        = "com.laudousg.LaudoUSG.pro.yearly"
    nonisolated static let allProductIDs: [String] = [essentialMonthly, essentialYearly, proMonthly, proYearly]

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    /// Elegibilidade à oferta introdutória (trial de 7 dias) por produto.
    /// Ausente = ainda não consultado. Quem já usou o trial não é elegível e a
    /// UI não pode prometer "7 dias grátis".
    private(set) var introOfferEligibility: [String: Bool] = [:]
    /// Usuário LaudoUSG dono das transações que contam neste aparelho.
    private(set) var boundUserID: UUID?
    /// Última sincronização com o backend (para a UI explicar pendências).
    private(set) var lastSyncOutcome: IAPSyncOutcome?

    var isLoadingProducts = false
    var isPurchasing = false
    var isSyncing = false
    var lastErrorMessage: String?

    private var updatesListener: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.laudousg.LaudoUSG", category: "StoreKit")

    init() {
        // Transações que chegam fora do fluxo de compra (renovação, Ask to Buy,
        // compra em outro device). Sem conta vinculada, ficam pendentes no
        // StoreKit e o dono sincroniza ao entrar.
        updatesListener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(update: result)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Conta

    /// Vincula as transações ao usuário logado. Recalcula o entitlement local.
    func bind(userID: UUID) async {
        if boundUserID != userID {
            boundUserID = userID
            lastSyncOutcome = nil
        }
        await refreshEntitlements()
    }

    /// Ao sair da conta: nenhum acesso por IAP até o próximo `bind`.
    func clearAccount() {
        boundUserID = nil
        purchasedProductIDs = []
        lastSyncOutcome = nil
        lastErrorMessage = nil
    }

    // MARK: - Entitlement derivado

    /// Maior nível de plano ativo via IAP para o usuário vinculado (ou nil).
    var entitlementTier: PlanTier? { IAPEntitlementResolver.tier(for: purchasedProductIDs) }

    var hasActiveSubscription: Bool { entitlementTier != nil }

    // MARK: - Produtos (agrupados para a UI)

    func product(id: String) -> Product? { products.first { $0.id == id } }

    var essentialMonthlyProduct: Product? { product(id: Self.essentialMonthly) }
    var essentialYearlyProduct: Product?  { product(id: Self.essentialYearly) }
    var proMonthlyProduct: Product?       { product(id: Self.proMonthly) }
    var proYearlyProduct: Product?        { product(id: Self.proYearly) }

    /// `true`/`false` quando já consultado; nil enquanto desconhecido.
    func isEligibleForIntroOffer(_ product: Product) -> Bool? {
        introOfferEligibility[product.id]
    }

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
            await refreshIntroOfferEligibility()
        } catch {
            logger.error("Falha ao carregar produtos: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "Não foi possível carregar os planos. Verifique a conexão e tente novamente."
        }
    }

    /// Consulta à App Store se ESTA conta Apple ainda tem direito ao trial.
    func refreshIntroOfferEligibility() async {
        var eligibility: [String: Bool] = [:]
        for product in products {
            guard let subscription = product.subscription, subscription.introductoryOffer != nil else {
                eligibility[product.id] = false
                continue
            }
            eligibility[product.id] = await subscription.isEligibleForIntroOffer
        }
        introOfferEligibility = eligibility
    }

    /// Recalcula o entitlement a partir das transações verificadas e da posse.
    func refreshEntitlements() async {
        let snapshots = await currentSnapshots()
        purchasedProductIDs = IAPEntitlementResolver.activeProductIDs(snapshots, userID: boundUserID)
    }

    private func currentSnapshots() async -> [IAPTransactionSnapshot] {
        var snapshots: [IAPTransactionSnapshot] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            snapshots.append(Self.snapshot(of: transaction))
        }
        return snapshots
    }

    nonisolated private static func snapshot(of transaction: Transaction) -> IAPTransactionSnapshot {
        IAPTransactionSnapshot(
            productID: transaction.productID,
            appAccountToken: transaction.appAccountToken,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            isUpgraded: transaction.isUpgraded
        )
    }

    // MARK: - Compra

    enum PurchaseOutcome: Equatable {
        /// Compra concluída e registrada no backend.
        case success
        /// Compra concluída na App Store; o backend ainda não confirmou (acesso
        /// local liberado; a sincronização repete no próximo login/abertura).
        case successPendingSync(String)
        /// Ask to Buy / aprovação pendente. A transação chega por `Transaction.updates`.
        case pending
        case cancelled
        case failed(String)
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        guard let userID = boundUserID else {
            return .failed("Entre na sua conta para assinar.")
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase(options: [.appAccountToken(userID)])
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "Não foi possível validar a compra com a App Store."
                    return .failed(lastErrorMessage!)
                }
                let outcome = await submit(verification, transaction: transaction)
                await refreshEntitlements()
                switch outcome {
                case .accepted:
                    return .success
                case .rejected(let code):
                    logger.error("Backend recusou a transação \(transaction.id): \(code, privacy: .public)")
                    return .failed("A App Store confirmou a compra, mas não foi possível vinculá-la à conta LaudoUSG. Use Restaurar compras na conta usada para assinar ou procure o suporte. Não compre novamente.")
                case .retryLater(let reason):
                    logger.notice("Backend indisponível para a transação \(transaction.id): \(reason, privacy: .public)")
                    return .successPendingSync("Compra confirmada pela App Store. Sem conexão com o servidor agora; sincronizamos automaticamente.")
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed("A compra não pôde ser concluída.")
            }
        } catch {
            logger.error("Compra falhou: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "A compra falhou. Tente novamente."
            return .failed(lastErrorMessage!)
        }
    }

    // MARK: - Restauração / sincronização

    enum RestoreOutcome: Equatable {
        case restored
        case restoredPendingSync
        case noneFound
        /// A conta Apple tem assinatura vigente, mas comprada com OUTRA conta LaudoUSG.
        case boundToAnotherAccount
        case failed(String)
    }

    /// Sincroniza com a App Store (UI do sistema), recalcula e reenvia ao backend.
    func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("AppStore.sync falhou: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "Não foi possível restaurar as compras."
            return .failed(lastErrorMessage!)
        }
        await refreshEntitlements()
        let sync = await syncWithBackend()
        if hasActiveSubscription {
            if case .accepted = sync { return .restored }
            return .restoredPendingSync
        }
        let snapshots = await currentSnapshots()
        if IAPEntitlementResolver.hasEntitlementForAnotherAccount(snapshots, userID: boundUserID) {
            return .boundToAnotherAccount
        }
        return .noneFound
    }

    /// Reenvia ao backend (idempotente) as transações do usuário vinculado:
    /// primeiro as NÃO finalizadas (compra cuja confirmação falhou ou chegou
    /// com o app fechado), depois as vigentes. Finaliza só o que for aceito.
    /// Retorna o último resultado, ou nil se não havia o que enviar.
    @discardableResult
    func syncWithBackend() async -> IAPSyncOutcome? {
        guard let userID = boundUserID else { return nil }
        isSyncing = true
        defer { isSyncing = false }

        var sent: Set<UInt64> = []
        var last: IAPSyncOutcome?

        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result, transaction.appAccountToken == userID else { continue }
            guard sent.insert(transaction.id).inserted else { continue }
            last = await submit(result, transaction: transaction)
        }
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.appAccountToken == userID else { continue }
            guard sent.insert(transaction.id).inserted else { continue }
            last = await submit(result, transaction: transaction)
        }

        await refreshEntitlements()
        lastSyncOutcome = last
        return last
    }

    private func handle(update result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        guard let userID = boundUserID, transaction.appAccountToken == userID else {
            // Sem conta vinculada, ou de outra conta LaudoUSG: fica pendente no
            // StoreKit; o dono sincroniza (e finaliza) ao entrar.
            logger.notice("Transação \(transaction.id) aguardando o dono entrar")
            return
        }
        _ = await submit(result, transaction: transaction)
        await refreshEntitlements()
    }

    /// Entrega o JWS ao backend. `finish()` SÓ se o backend aceitou — senão a
    /// transação continua pendente para reentrega.
    private func submit(_ verification: VerificationResult<Transaction>, transaction: Transaction) async -> IAPSyncOutcome {
        guard transaction.appAccountToken == boundUserID, boundUserID != nil else {
            return .retryLater(reason: "account_changed")
        }
        let outcome = await IAPBackendSync.submit(jws: verification.jwsRepresentation)
        switch outcome {
        case .accepted:
            await transaction.finish()
        case .rejected(let code):
            logger.error("Transação \(transaction.id) recusada pelo backend (\(code, privacy: .public)); não finalizada")
        case .retryLater(let reason):
            logger.notice("Transação \(transaction.id) aguardando backend (\(reason, privacy: .public)); não finalizada")
        }
        lastSyncOutcome = outcome
        return outcome
    }
}

/// POST do JWS para o backend. Separado para a classificação da resposta ser
/// testável (`IAPSyncOutcome.classify`).
enum IAPBackendSync {
    private struct Response: Decodable {
        let ok: Bool?
        let plan: String?
    }

    static func submit(jws: String) async -> IAPSyncOutcome {
        guard let body = try? JSONSerialization.data(withJSONObject: ["signedTransactionJwt": jws]) else {
            return .retryLater(reason: "encode")
        }
        do {
            let data = try await APIClient.shared.postRawJSON("/api/iap/validate-receipt", body: body)
            guard let decoded = try? JSONDecoder().decode(Response.self, from: data), decoded.ok == true else {
                return .retryLater(reason: "invalid_confirmation")
            }
            return .accepted(plan: decoded.plan)
        } catch {
            return IAPSyncOutcome.classify(error)
        }
    }
}
