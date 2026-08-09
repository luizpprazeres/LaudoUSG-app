import Foundation

/// Chaves de experimento do app — coisas que existem no código mas NÃO devem
/// aparecer para o usuário final até serem promovidas.
enum AppExperiments {
    private static let testCategoryKey = "experiments.testCategory"

    /// Mostra a categoria TESTE no seletor.
    ///
    /// - Em build de desenvolvimento (DEBUG): sempre ligada.
    /// - Em build de distribuição: só se alguém ligar explicitamente via
    ///   `UserDefaults` (`experiments.testCategory`), pra dar pra testar em
    ///   TestFlight sem republicar.
    ///
    /// O backend já restringe a categoria TESTE por `TESTE_ALLOWED_USER_ID`,
    /// então isto aqui é a segunda tranca — a que impede o item de sequer
    /// aparecer na lista de outro usuário.
    static var showTestCategory: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: testCategoryKey)
        #endif
    }

    static func setShowTestCategory(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: testCategoryKey)
    }
}
