import Foundation

/// Nível de plano derivado de uma assinatura ativa. `pro` > `essential`.
enum PlanTier: Int, Comparable, Sendable {
    case essential = 1
    case pro = 2
    static func < (lhs: PlanTier, rhs: PlanTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Como o backend projeta este tier no campo `plan` do perfil (`hasPro` aceita `clinic`/`pro`).
    var backendPlan: String { self == .pro ? "clinic" : "essencial" }
}

/// Foto de uma transação StoreKit com só o que decide o acesso. Sem tipos do
/// StoreKit de propósito: `Transaction` não é construível em teste, e é aqui
/// que mora a regra de POSSE (appAccountToken == usuário logado).
struct IAPTransactionSnapshot: Equatable, Sendable {
    let productID: String
    let appAccountToken: UUID?
    let expirationDate: Date?
    let revocationDate: Date?
    let isUpgraded: Bool

    init(
        productID: String,
        appAccountToken: UUID?,
        expirationDate: Date? = nil,
        revocationDate: Date? = nil,
        isUpgraded: Bool = false
    ) {
        self.productID = productID
        self.appAccountToken = appAccountToken
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
    }
}

enum IAPEntitlementResolver {
    /// Produtos que dão acesso AO USUÁRIO LOGADO neste aparelho.
    ///
    /// Uma assinatura da conta Apple só conta se foi comprada COM esta conta
    /// LaudoUSG (o `appAccountToken` fixado na compra é o id do usuário). Sem
    /// isso, trocar de conta no mesmo iPhone herdaria o plano do médico
    /// anterior — e uma compra sem token (legado) não prova posse alguma.
    static func activeProductIDs(
        _ snapshots: [IAPTransactionSnapshot],
        userID: UUID?,
        now: Date = Date()
    ) -> Set<String> {
        guard let userID else { return [] }
        var active: Set<String> = []
        for snapshot in snapshots where isEntitling(snapshot, now: now) {
            guard let token = snapshot.appAccountToken, token == userID else { continue }
            active.insert(snapshot.productID)
        }
        return active
    }

    /// Há alguma assinatura vigente na conta Apple que pertence a OUTRA conta
    /// LaudoUSG (ou a nenhuma)? Serve para o "Restaurar compras" explicar por
    /// que não restaurou, em vez de dizer "nenhuma assinatura".
    static func hasEntitlementForAnotherAccount(
        _ snapshots: [IAPTransactionSnapshot],
        userID: UUID?,
        now: Date = Date()
    ) -> Bool {
        snapshots.contains { isEntitling($0, now: now) && $0.appAccountToken != userID }
    }

    static func isEntitling(_ snapshot: IAPTransactionSnapshot, now: Date) -> Bool {
        if snapshot.revocationDate != nil { return false }
        if snapshot.isUpgraded { return false }
        guard tier(forProductID: snapshot.productID) != nil,
              let expiration = snapshot.expirationDate, expiration > now else { return false }
        return true
    }

    static func tier(forProductID id: String) -> PlanTier? {
        switch id {
        case "com.laudousg.LaudoUSG.pro.monthly", "com.laudousg.LaudoUSG.pro.yearly": return .pro
        case "com.laudousg.LaudoUSG.essential.monthly", "com.laudousg.LaudoUSG.essential.yearly": return .essential
        default: return nil
        }
    }

    /// Maior nível entre os produtos ativos (ou nil).
    static func tier(for productIDs: Set<String>) -> PlanTier? {
        productIDs.compactMap(tier(forProductID:)).max()
    }
}

/// O que o backend respondeu ao receber o JWS de uma transação — e o que isso
/// implica para o `finish()`: SÓ `accepted` finaliza. Tudo o mais deixa a
/// transação pendente no StoreKit para reentrega (próximo login/restore/abertura).
enum IAPSyncOutcome: Equatable, Sendable {
    /// 2xx — registrada (ou já estava). `plan` é o plano efetivo devolvido.
    case accepted(plan: String?)
    /// 4xx definitivo (JWS inválido, produto desconhecido, posse de outra conta).
    case rejected(code: String)
    /// 5xx, rede, sessão expirada, ou 4xx com `retryable: true`.
    case retryLater(reason: String)

    var shouldFinishTransaction: Bool {
        if case .accepted = self { return true }
        return false
    }

    private struct ErrorBody: Decodable {
        let error: String?
        let retryable: Bool?
    }

    static func classify(_ error: Error) -> IAPSyncOutcome {
        guard let apiError = error as? APIError else {
            return .retryLater(reason: "unknown")
        }
        switch apiError {
        case .http(let status, let body):
            return classify(status: status, body: body)
        case .unauthorized:
            return .retryLater(reason: "unauthorized")
        case .transport:
            return .retryLater(reason: "transport")
        case .invalidResponse:
            return .retryLater(reason: "invalid_response")
        case .decoding:
            return .retryLater(reason: "decoding")
        }
    }

    static func classify(status: Int, body: String?) -> IAPSyncOutcome {
        let parsed = body?.data(using: .utf8).flatMap { try? JSONDecoder().decode(ErrorBody.self, from: $0) }
        let code = parsed?.error ?? "http_\(status)"
        if parsed?.retryable == true || status >= 500 {
            return .retryLater(reason: code)
        }
        return .rejected(code: code)
    }
}
