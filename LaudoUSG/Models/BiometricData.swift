import Foundation

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
