import Foundation

/// Chaves de experimento do app — coisas que existem no código mas NÃO devem
/// aparecer para o usuário final até serem promovidas.
enum AppExperiments {
    private static let testCategoryKey = "experiments.testCategory"
    private static let developerToolsKey = "experiments.developerTools"

    /// Mostra a categoria TESTE no seletor.
    ///
    /// Hoje nenhuma categoria é experimental (a TESTE saiu em 09/08, virou o
    /// modo experimental — ver `UserPreferences.experimentalModel`). A chave
    /// fica porque a próxima categoria escondida vai precisar dela.
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

    // MARK: - Ferramentas de desenvolvedor

    /// Destrava a seção "Desenvolvedor" em Ajustes.
    ///
    /// Fica atrás de um gesto escondido de propósito: em build de distribuição
    /// nenhum usuário deve tropeçar nela, mas precisa ser alcançável sem
    /// recompilar — senão testar em TestFlight exigiria uma build só pra isso.
    /// O destravamento é 7 toques na versão, em Ajustes → Sobre o app.
    ///
    /// Segunda tranca, no servidor: o modo experimental é restrito a
    /// `TESTE_ALLOWED_USER_ID`. Destravar aqui não dá acesso a mais nada —
    /// outro usuário que descubra o gesto recebe 403 ao gerar.
    static var developerToolsUnlocked: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: developerToolsKey)
        #endif
    }

    static func setDeveloperToolsUnlocked(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: developerToolsKey)
    }

    /// Quantos toques na versão destravam. Alto o bastante para não acontecer
    /// por acidente, baixo o bastante para não irritar quem sabe.
    static let developerUnlockTapCount = 7
}
