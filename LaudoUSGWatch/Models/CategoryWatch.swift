import Foundation

enum CategoryWatch: String, CaseIterable, Identifiable, Codable {
    case obstetrica = "OBSTETRICA"
    case pelveFeminina = "PELVE_FEMININA"
    case tireoide = "TIREOIDE"
    case mamaria = "MAMARIA"
    case dopplerObstetrico = "DOPPLER_OBSTETRICO"
    case abdomenTotal = "ABDOMEN_TOTAL"
    case morfologico = "MORFOLOGICO"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .obstetrica: return "Obstétrica"
        case .pelveFeminina: return "Pelve Feminina"
        case .tireoide: return "Tireoide"
        case .mamaria: return "Mamária"
        case .dopplerObstetrico: return "Doppler Obstétrico"
        case .abdomenTotal: return "Abdome Total"
        case .morfologico: return "Morfológico"
        }
    }

    var symbol: String {
        switch self {
        case .obstetrica, .dopplerObstetrico, .morfologico:
            return "figure.and.child.holdinghands"
        case .pelveFeminina:
            return "figure.stand"
        case .tireoide:
            return "shield.lefthalf.filled"
        case .mamaria:
            return "heart.text.square"
        case .abdomenTotal:
            return "circle.hexagongrid"
        }
    }
}
