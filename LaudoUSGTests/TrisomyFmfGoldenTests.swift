import XCTest
@testable import LaudoUSG

final class TrisomyFmfGoldenTests: XCTestCase {
    private static let toleranciaRelativa = 1e-9

    func testTodosOs286CasosGolden() throws {
        let golden = try carregarGolden()
        XCTAssertEqual(golden.versao, TrisomyCalculator.versaoParametros)
        XCTAssertEqual(golden.casos.count, 286)
        XCTAssertEqual(golden.total, 286)
        XCTAssertEqual(golden.recusas, 14)
        XCTAssertEqual(golden.casos.filter { $0.esperado.erroDeDominio }.count, 14)

        for caso in golden.casos {
            if caso.esperado.erroDeDominio {
                XCTAssertThrowsError(
                    try calcular(caso),
                    "\(caso.id): deveria lançar TrisomyErroDeDominio"
                ) { erro in
                    guard let dominio = erro as? TrisomyErroDeDominio else {
                        XCTFail("\(caso.id): lançou \(type(of: erro)), não TrisomyErroDeDominio")
                        return
                    }
                    if let mensagem = caso.esperado.mensagem {
                        XCTAssertEqual(dominio.mensagem, mensagem, "\(caso.id): mensagem divergente")
                    }
                }
                continue
            }

            let resultado: TrisomyCalculator.Resultado
            do {
                resultado = try calcular(caso)
            } catch {
                XCTFail("\(caso.id): lançou erro inesperado: \(error)")
                continue
            }

            let esperado = caso.esperado
            comparar(resultado.basal.t21.probability, esperado.basal?.t21, caso.id, "basal.t21")
            comparar(resultado.basal.t18.probability, esperado.basal?.t18, caso.id, "basal.t18")
            comparar(resultado.basal.t13.probability, esperado.basal?.t13, caso.id, "basal.t13")
            comparar(resultado.t21.probability, esperado.t21, caso.id, "t21")
            comparar(resultado.t18.probability, esperado.t18, caso.id, "t18")
            comparar(resultado.t13.probability, esperado.t13, caso.id, "t13")
            comparar(resultado.t18t13.probability, esperado.t18t13, caso.id, "t18t13")

            XCTAssertEqual(resultado.gaDays, esperado.gaDays, "\(caso.id): gaDays")
            XCTAssertEqual(resultado.gaWeeks, esperado.gaWeeks, "\(caso.id): gaWeeks")
            XCTAssertEqual(resultado.gaDaysRemainder, esperado.gaDaysRemainder, "\(caso.id): gaDaysRemainder")
            XCTAssertEqual(resultado.t21.category.rawValue, esperado.categoriaT21, "\(caso.id): categoriaT21")
            XCTAssertEqual(resultado.t18t13.category.rawValue, esperado.categoriaT18t13, "\(caso.id): categoriaT18t13")
            XCTAssertEqual(resultado.markersUsed, esperado.markersUsed ?? [], "\(caso.id): markersUsed")
            XCTAssertEqual(resultado.warnings.count, esperado.warnings ?? 0, "\(caso.id): warnings")
        }
    }

    func testMarcadoresAusentesComplementamOsUsados() throws {
        let resultado = try TrisomyCalculator.calcular(
            .init(maternalAge: 30, crl: 60, nt: 1.8, fhr: 160, dvPI: 1.1)
        )
        XCTAssertEqual(resultado.markersUsed, ["Idade materna", "TN", "FCF", "Ducto venoso"])
        XCTAssertEqual(resultado.markersMissing, ["Free β-hCG", "PAPP-A", "Tricúspide", "Osso nasal"])
        XCTAssertEqual(resultado.displayCapRatio, 10000)
        XCTAssertEqual(resultado.displayFloorRatio, 2)
        XCTAssertFalse(resultado.insertBloco.isEmpty)
    }

    func testFormatoDeExibicaoComoNoAppDaFMF() {
        XCTAssertEqual(TrisomyCalculator.formatarRazao(1.0 / 20000), "< 1 em 10.000")
        XCTAssertEqual(TrisomyCalculator.formatarRazao(1.0 / 3287), "1 em 3.300")
        XCTAssertEqual(TrisomyCalculator.formatarRazao(1.0 / 552), "1 em 550")
        XCTAssertEqual(TrisomyCalculator.formatarRazao(1.0 / 63.4), "1 em 63")
        XCTAssertEqual(TrisomyCalculator.formatarRazao(0.9), "1 em 2")
    }

    private func calcular(_ caso: GoldenCaso) throws -> TrisomyCalculator.Resultado {
        let entrada = caso.entrada
        return try TrisomyCalculator.calcular(
            .init(
                maternalAge: entrada.maternalAge ?? .nan,
                crl: entrada.crl,
                nt: entrada.nt,
                fhr: entrada.fhr,
                gaDaysDated: entrada.gaDaysDated,
                freeBetaHcgMoM: entrada.freeBetaHcgMoM,
                pappaMoM: entrada.pappaMoM,
                isMoMCorrected: entrada.isMoMCorrected ?? false,
                dvPI: entrada.dvPI,
                tricuspidRegurgitation: entrada.tricuspidRegurgitation,
                nasalBoneAbsent: entrada.nasalBoneAbsent,
                smoking: entrada.smoking ?? false,
                ethnicity: entrada.ethnicity.flatMap { TrisomyCalculator.Etnia(rawValue: $0) } ?? .branca,
                weight: entrada.weight,
                previousT21: entrada.previousT21 ?? false,
                previousT18: entrada.previousT18 ?? false,
                previousT13: entrada.previousT13 ?? false
            )
        )
    }

    private func comparar(_ obtido: Double?, _ esperado: Double?, _ id: String, _ campo: String) {
        guard let esperado else {
            XCTFail("\(id): golden sem \(campo)")
            return
        }
        guard let obtido else {
            XCTFail("\(id): \(campo) ausente no resultado")
            return
        }
        let erroRelativo = abs(obtido - esperado) / max(abs(esperado), Double.leastNormalMagnitude)
        XCTAssertLessThanOrEqual(
            erroRelativo,
            Self.toleranciaRelativa,
            "\(id): \(campo) obtido=\(obtido) esperado=\(esperado) (erro relativo \(erroRelativo))"
        )
    }

    private func carregarGolden() throws -> GoldenRaiz {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "golden-trissomias", withExtension: "json"),
            "golden-trissomias.json não foi copiado para o bundle de testes"
        )
        return try JSONDecoder().decode(GoldenRaiz.self, from: Data(contentsOf: url))
    }
}

private struct GoldenRaiz: Decodable {
    let versao: String
    let total: Int
    let recusas: Int
    let casos: [GoldenCaso]
}

private struct GoldenCaso: Decodable {
    let id: String
    let entrada: GoldenEntrada
    let esperado: GoldenEsperado
}

private struct GoldenEntrada: Decodable {
    /// `null` no JSON (NaN no TS) deve ser tratado como inválido → recusa.
    let maternalAge: Double?
    let crl: Double
    let nt: Double
    let fhr: Double?
    let gaDaysDated: Double?
    let freeBetaHcgMoM: Double?
    let pappaMoM: Double?
    let isMoMCorrected: Bool?
    let dvPI: Double?
    let tricuspidRegurgitation: Bool?
    let nasalBoneAbsent: Bool?
    let smoking: Bool?
    let ethnicity: String?
    let weight: Double?
    let previousT21: Bool?
    let previousT18: Bool?
    let previousT13: Bool?
}

private struct GoldenBasal: Decodable {
    let t21: Double
    let t18: Double
    let t13: Double
}

private struct GoldenEsperado: Decodable {
    let erroDeDominio: Bool
    let mensagem: String?
    let gaDays: Int?
    let gaWeeks: Int?
    let gaDaysRemainder: Int?
    let basal: GoldenBasal?
    let t21: Double?
    let t18: Double?
    let t13: Double?
    let t18t13: Double?
    let categoriaT21: String?
    let categoriaT18t13: String?
    let markersUsed: [String]?
    let warnings: Int?
}
