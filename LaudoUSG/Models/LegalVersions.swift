import Foundation

enum LegalVersions {
    static let termsOfUse = "2.0"
    static let privacyPolicy = "2.0"
    static let medicalDisclaimer = "2.0"
}

enum LegalTexts {
    /// Footer obrigatório em ReportDetail (Apple Store compliance + CFM 2.314/2022).
    /// Não deve ser dispensável — sempre visível ao usuário ao consultar um laudo gerado.
    static let reportFooterDisclaimer: String = """
    Laudo elaborado com apoio de inteligência artificial.

    O texto gerado é MINUTA AUTOMATIZADA e pode conter erros, omissões ou conclusões \
    inadequadas. Revise integralmente, valide clinicamente e edite antes de assinar ou entregar.

    Você, médico, mantém responsabilidade profissional pelo laudo final. Não use esta saída \
    sem revisão médica completa.

    Em conformidade com a Resolução CFM 2.314/2022 (Telemedicina) e demais normas vigentes \
    do Conselho Federal de Medicina.
    """

    /// Versão curta para telas com pouco espaço (Login footer, Generate).
    static let shortDisclaimer = "Conteúdo gerado por IA. Revise antes de assinar."

    /// Versão ainda mais curta — quando contexto já deixa claro que é IA.
    static let microDisclaimer = "Revise antes de assinar."
}
