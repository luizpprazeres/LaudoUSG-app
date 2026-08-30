import XCTest
@testable import LaudoUSG

final class PreEclampsiaFmfGoldenTests: XCTestCase {
    private static let toleranciaRelativa = 1e-9

    func testTodosOs342CasosGolden() throws {
        let golden = try carregarGolden()
        XCTAssertEqual(golden.versao, PreEclampsiaCalculator.versaoParametros)
        XCTAssertEqual(golden.casos.count, 342)
        XCTAssertEqual(golden.casos.filter { $0.esperado.erroDeDominio == true }.count, 11)

        for caso in golden.casos {
            if caso.esperado.erroDeDominio == true {
                XCTAssertThrowsError(
                    try calcular(caso),
                    "\(caso.id): deveria lançar PeErroDeDominio"
                ) { erro in
                    XCTAssertTrue(
                        erro is PeErroDeDominio,
                        "\(caso.id): lançou \(type(of: erro)), não PeErroDeDominio"
                    )
                }
                continue
            }

            let resultado: PreEclampsiaCalculator.Resultado
            do {
                resultado = try calcular(caso)
            } catch {
                XCTFail("\(caso.id): lançou erro inesperado: \(error)")
                continue
            }

            comparar(resultado.priorMean, caso.esperado.priorMean, caso.id, "priorMean")
            comparar(resultado.riscos[37], caso.esperado.risco37, caso.id, "risco37")
            comparar(resultado.riscos[34], caso.esperado.risco34, caso.id, "risco34")
            comparar(resultado.riscos[32], caso.esperado.risco32, caso.id, "risco32")

            let momPam = resultado.marcadores.first { $0.nome == .map }?.mom
            let momUta = resultado.marcadores.first { $0.nome == .utaPi }?.mom
            comparar(momPam, caso.esperado.momPam, caso.id, "momPam")
            comparar(momUta, caso.esperado.momUtaPi, caso.id, "momUtaPi")
        }
    }

    func testPAMAceitaUmaOuQuatroAfericoes() throws {
        let unica = try PreEclampsiaCalculator.pamDeAfericoes([
            .init(sistolica: 117, diastolica: 84),
        ])
        XCTAssertEqual(unica.pamMmHg, 95, accuracy: 1e-12)
        XCTAssertEqual(unica.afericoes, 1)
        XCTAssertFalse(unica.protocoloCompleto)

        let protocolo = try PreEclampsiaCalculator.pamDeAfericoes([
            .init(sistolica: 117, diastolica: 84),
            .init(sistolica: 117, diastolica: 84),
            .init(sistolica: 117, diastolica: 84),
            .init(sistolica: 117, diastolica: 84),
        ])
        XCTAssertEqual(protocolo.pamMmHg, 95, accuracy: 1e-12)
        XCTAssertEqual(protocolo.afericoes, 4)
        XCTAssertTrue(protocolo.protocoloCompleto)
    }

    func testCCNUsaFormulaFMF() throws {
        let dias = try PreEclampsiaCalculator.gaDiasPorCCN(55)
        let esperado = 23.53 + 8.052 * sqrt(1.037 * 55)
        XCTAssertEqual(dias, esperado, accuracy: 1e-12)
    }

    private func calcular(_ caso: GoldenCaso) throws -> PreEclampsiaCalculator.Resultado {
        let g = caso.entrada.g
        return try PreEclampsiaCalculator.calcular(
            .init(
                idade: g.idade,
                peso: g.peso,
                altura: g.altura,
                gaDias: g.gaDias,
                etnia: try XCTUnwrap(.init(rawValue: g.etnia), "\(caso.id): etnia inválida"),
                paridade: try XCTUnwrap(.init(rawValue: g.paridade), "\(caso.id): paridade inválida"),
                intervaloAnos: g.intervaloAnos,
                igPartoAnterior: g.igPartoAnterior,
                zEscorePesoAnterior: g.zEscorePesoAnterior,
                histFamiliarPE: g.histFamiliarPE,
                fiv: g.fiv,
                hipertensaoCronica: g.hipertensaoCronica,
                diabetes: g.diabetes,
                lesSaf: g.lesSaf,
                fumante: g.fumante
            ),
            medidas: .init(
                pamMmHg: caso.entrada.med.pamMmHg,
                utaPiMedio: caso.entrada.med.utaPiMedio
            )
        )
    }

    private func comparar(
        _ obtido: Double?,
        _ esperado: Double?,
        _ caso: String,
        _ campo: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let esperado else {
            XCTAssertNil(obtido, "\(caso).\(campo): deveria ser nil", file: file, line: line)
            return
        }
        guard let obtido else {
            XCTFail("\(caso).\(campo): ausente", file: file, line: line)
            return
        }
        let denominador = max(abs(esperado), Double.leastNonzeroMagnitude)
        let erroRelativo = abs(obtido - esperado) / denominador
        XCTAssertLessThan(
            erroRelativo,
            Self.toleranciaRelativa,
            "\(caso).\(campo): obtido=\(obtido), esperado=\(esperado), erro relativo=\(erroRelativo)",
            file: file,
            line: line
        )
    }

    private func carregarGolden() throws -> GoldenRaiz {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "golden", withExtension: "json"),
            "golden.json não foi copiado para o bundle de testes"
        )
        return try JSONDecoder().decode(GoldenRaiz.self, from: Data(contentsOf: url))
    }
}

private struct GoldenRaiz: Decodable {
    let versao: String
    let casos: [GoldenCaso]
}

private struct GoldenCaso: Decodable {
    let id: String
    let entrada: GoldenEntrada
    let esperado: GoldenEsperado
}

private struct GoldenEntrada: Decodable {
    let g: GoldenGestante
    let med: GoldenMedidas
}

private struct GoldenGestante: Decodable {
    let idade: Double
    let peso: Double
    let altura: Double
    let gaDias: Double
    let etnia: String
    let paridade: String
    let intervaloAnos: Double?
    let igPartoAnterior: Double?
    let zEscorePesoAnterior: Double?
    let histFamiliarPE: Bool
    let fiv: Bool
    let hipertensaoCronica: Bool
    let diabetes: Bool
    let lesSaf: Bool
    let fumante: Bool
}

private struct GoldenMedidas: Decodable {
    let pamMmHg: Double?
    let utaPiMedio: Double?
}

private struct GoldenEsperado: Decodable {
    let priorMean: Double?
    let risco37: Double?
    let risco34: Double?
    let risco32: Double?
    let momPam: Double?
    let momUtaPi: Double?
    let erroDeDominio: Bool?
}
