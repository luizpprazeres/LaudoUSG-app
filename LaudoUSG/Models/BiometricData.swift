import Foundation

struct ThyroidMeasurements: Codable, Equatable {
    var a: String?
    var b: String?
    var c: String?
}

struct ThyroidNodule: Codable, Equatable {
    var lobe: String
    var c1: String?
    var c2: String?
    var c3: String?
    var location: String?
    var echogenicity: String?
    var margin: String?
    var halo: String?
    var shape: String?
    var calcifications: String?
    var vascularization: String?
}

struct BiometricData: Codable, Equatable {
    var dbp: String?
    var cc: String?
    var ca: String?
    var cf: String?
    var weight: String?
    var weightVariation: String?
    var percentile: String?
    var gestAge: String?
    var gestAgeLMP: String?
    var gestAgeBiometry: String?

    var irRightUterine: String?
    var ipRightUterine: String?
    var irLeftUterine: String?
    var ipLeftUterine: String?
    var irUmbilical: String?
    var ipUmbilical: String?
    var irMCA: String?
    var ipMCA: String?
    var irDuctusVenosus: String?
    var ipDuctusVenosus: String?

    var tibia: String?
    var fibula: String?
    var humerus: String?
    var radius: String?
    var ulna: String?
    var cerebellum: String?
    var cisternaMagna: String?
    var binocularDistance: String?
    var ila: String?
    var gender: String?

    var thyroidRightLobe: ThyroidMeasurements?
    var thyroidLeftLobe: ThyroidMeasurements?
    var thyroidIsthmus: ThyroidMeasurements?
    var thyroidNodules: [ThyroidNodule]?
}

struct AnalyzeImageResponse: Decodable {
    let success: Bool
    let data: BiometricData?
    let model: String?
    let empty: Bool?
    let message: String?
    let error: String?
}

struct AnalyzeImageRequest: Encodable {
    let imageBase64: String
    let category: String
    let gemelar: Bool?
    let modules: [String]?
}
