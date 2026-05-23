import Foundation
import StoreKit
import os

enum IAPError: Error, LocalizedError {
    case productNotFound
    case userCancelled
    case pending
    case unverified
    case backendValidationFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Produto não encontrado na App Store."
        case .userCancelled: return "Compra cancelada."
        case .pending: return "Compra aguardando aprovação."
        case .unverified: return "Transação não verificada pela Apple."
        case .backendValidationFailed(let msg): return "Falha na validação no servidor: \(msg)"
        case .unknown: return "Erro inesperado na compra."
        }
    }
}

enum IAPProductID {
    static let essencialMonthly = "laudousg.essencial.monthly"
    static let essencialYearly = "laudousg.essencial.yearly"
    static let proMonthly = "laudousg.pro.monthly"
    static let proYearly = "laudousg.pro.yearly"

    static let all: [String] = [essencialMonthly, essencialYearly, proMonthly, proYearly]

    static func tier(for id: String) -> SubscriptionTier? {
        if id.hasPrefix("laudousg.essencial.") { return .essencial }
        if id.hasPrefix("laudousg.pro.") { return .pro }
        return nil
    }

    static func period(for id: String) -> SubscriptionPeriod? {
        if id.hasSuffix(".monthly") { return .monthly }
        if id.hasSuffix(".yearly") { return .yearly }
        return nil
    }
}

enum SubscriptionTier: String, Sendable {
    case essencial
    case pro
}

enum SubscriptionPeriod: String, Sendable {
    case monthly
    case yearly
}

@Observable
@MainActor
final class IAPService {
    static let shared = IAPService()

    var products: [Product] = []
    var isLoadingProducts: Bool = false
    var purchaseInProgress: Bool = false
    var lastError: String?

    private static let logger = Logger(subsystem: "com.laudousg.LaudoUSG", category: "iap")
    private var transactionListener: Task<Void, Never>?

    private init() {}

    func start() {
        guard transactionListener == nil else { return }
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    func stop() {
        transactionListener?.cancel()
        transactionListener = nil
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let storeProducts = try await Product.products(for: IAPProductID.all)
            products = storeProducts.sorted { lhs, rhs in
                lhs.price < rhs.price
            }
            Self.logger.info("Loaded \(self.products.count, privacy: .public) products")
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Failed loading products: \(error.localizedDescription, privacy: .public)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        lastError = nil

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            try await validateOnBackend(jws: verification.jwsRepresentation)
            await transaction.finish()
            Self.logger.info("Purchase succeeded: \(product.id, privacy: .public)")
            return transaction
        case .userCancelled:
            throw IAPError.userCancelled
        case .pending:
            throw IAPError.pending
        @unknown default:
            throw IAPError.unknown
        }
    }

    func restorePurchases() async throws {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        lastError = nil

        try await AppStore.sync()
        var restored = 0
        for await result in Transaction.currentEntitlements {
            do {
                _ = try checkVerified(result)
                try await validateOnBackend(jws: result.jwsRepresentation)
                restored += 1
            } catch {
                Self.logger.error("Restore failed for one entitlement: \(error.localizedDescription, privacy: .public)")
            }
        }
        Self.logger.info("Restore complete — \(restored, privacy: .public) entitlements validated")
    }

    func currentActiveProductId() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil,
                   transaction.expirationDate.map({ $0 > Date() }) ?? false {
                    return transaction.productID
                }
            }
        }
        return nil
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            try await validateOnBackend(jws: result.jwsRepresentation)
            await transaction.finish()
            Self.logger.info("Transaction update handled: \(transaction.productID, privacy: .public)")
        } catch {
            Self.logger.error("Transaction update failure: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw IAPError.unverified
        }
    }

    private func validateOnBackend(jws: String) async throws {
        let payload = ["signedTransactionJwt": jws]
        let body = try JSONSerialization.data(withJSONObject: payload)
        do {
            _ = try await APIClient.shared.postRawJSON("/api/iap/validate-receipt", body: body)
        } catch {
            let msg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            Self.logger.error("Backend validation failed: \(msg, privacy: .public)")
            throw IAPError.backendValidationFailed(msg)
        }
    }
}
