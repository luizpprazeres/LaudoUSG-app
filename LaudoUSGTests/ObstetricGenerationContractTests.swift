import XCTest
@testable import LaudoUSG

final class ObstetricGenerationContractTests: XCTestCase {
    func testCategoriasObstetricasChegamExatamenteComoSelecionadas() throws {
        let casos: [(ReportCategory, String)] = [
            (.obstetrica, "OBSTETRICA"),
            (.morfologico, "MORFOLOGICO"),
            (.dopplerObstetrico, "DOPPLER_OBSTETRICO"),
        ]

        for (categoria, codigoEsperado) in casos {
            let request = GenerateRequest(
                rawInput: "Entrada clínica do exame selecionado.",
                categoryHint: categoria
            )
            let json = try jsonDoRequest(request)
            XCTAssertEqual(
                json["category_hint"] as? String,
                codigoEsperado,
                "A seleção \(categoria.label) não pode ser reinterpretada pelo cliente iOS."
            )
        }
    }

    func testMorfoDosTresTrimestresMantemCategoriaMorfologica() throws {
        let ditados = [
            "Morfológico do primeiro trimestre, CCN 64 mm e TN 1,5 mm.",
            "Morfológico do segundo trimestre, 22 semanas e 3 dias.",
            "Morfológico do terceiro trimestre, biometria e anatomia fetal.",
        ]

        for ditado in ditados {
            let request = GenerateRequest(rawInput: ditado, categoryHint: .morfologico)
            let json = try jsonDoRequest(request)
            XCTAssertEqual(json["category_hint"] as? String, "MORFOLOGICO")
            XCTAssertEqual(json["raw_input"] as? String, ditado)
        }
    }

    func testComplementosNaoTrocamCategoriaMorfologicaNoCliente() throws {
        let ditados = [
            "Morfológico do segundo trimestre com cervicometria transvaginal; colo 2,8 cm.",
            "Morfológico do segundo trimestre com Doppler; IP umbilical 1,0.",
            "Morfológico do terceiro trimestre com percentil de peso e crescimento fetal.",
        ]

        for ditado in ditados {
            let request = GenerateRequest(rawInput: ditado, categoryHint: .morfologico)
            let json = try jsonDoRequest(request)
            XCTAssertEqual(
                json["category_hint"] as? String,
                "MORFOLOGICO",
                "Cervicometria, Doppler e crescimento são complementos; não categorias substitutas."
            )
        }
    }

    func testDopplerIsoladoPermaneceDopplerObstetrico() throws {
        let request = GenerateRequest(
            rawInput: "Doppler obstétrico isolado. IP uterina direita 0,8 e esquerda 0,9.",
            categoryHint: .dopplerObstetrico
        )
        let json = try jsonDoRequest(request)
        XCTAssertEqual(json["category_hint"] as? String, "DOPPLER_OBSTETRICO")
    }

    private func jsonDoRequest(_ request: GenerateRequest) throws -> [String: Any] {
        let data = try JSONEncoder.api.encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
