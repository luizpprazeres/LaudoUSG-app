import SwiftUI

enum ReportCategory: String, CaseIterable, Identifiable, Codable {
    case abdomenTotal = "ABDOMEN_TOTAL"
    case abdomenTotalDoppler = "ABDOMEN_TOTAL_DOPPLER"
    case abdomenSuperior = "ABDOMEN_SUPERIOR"
    case viasUrinarias = "VIAS_URINARIAS"
    case tireoide = "TIREOIDE"
    case paratireoide = "PARATIREOIDE"
    case cervical = "CERVICAL"
    case glandulasSalivares = "GLANDULAS_SALIVARES"
    case mamaria = "MAMARIA"
    case pelveFeminina = "PELVE_FEMININA"
    case obstetrica = "OBSTETRICA"
    case dopplerObstetrico = "DOPPLER_OBSTETRICO"
    case morfologico = "MORFOLOGICO"
    case musculoesqueletico = "MUSCULOESQUELETICO"
    case musculoesqueleticoV2 = "MUSCULOESQUELETICO_V2"
    case musculoesqueleticoRaras = "MUSCULOESQUELETICO_RARAS"
    case escrotal = "ESCROTAL"
    case regiaoInguinal = "REGIAO_INGUINAL"
    case paredeAbdominal = "PAREDE_ABDOMINAL"
    case partesMoles = "PARTES_MOLES"
    case prostataTransretal = "PROSTATA_TRANSRETAL"
    case prostataSuprapubica = "PROSTATA_SUPRAPUBICA"
    case transfontanela = "TRANSFONTANELA"
    case dopplerCarotidas = "DOPPLER_CAROTIDAS"
    case dopplerVenosoMmii = "DOPPLER_VENOSO_MMII"
    case dopplerVenosoMmiiMedidas = "DOPPLER_VENOSO_MMII_MEDIDAS"
    case dopplerArterialMmii = "DOPPLER_ARTERIAL_MMII"
    case dopplerFistulaAv = "DOPPLER_FISTULA_AV"
    case dopplerRenal = "DOPPLER_RENAL"
    case ocular = "OCULAR"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .abdomenTotal: return "Abdome Total"
        case .abdomenTotalDoppler: return "Abdome Total c/ Doppler"
        case .abdomenSuperior: return "Abdome Superior"
        case .viasUrinarias: return "Vias Urinárias"
        case .tireoide: return "Tireoide"
        case .paratireoide: return "Paratireoides"
        case .cervical: return "Cervical"
        case .glandulasSalivares: return "Glândulas Salivares"
        case .mamaria: return "Mamária"
        case .pelveFeminina: return "Pelve Feminina"
        case .obstetrica: return "Obstétrica"
        case .dopplerObstetrico: return "Doppler Obstétrico"
        case .morfologico: return "Morfológico"
        case .musculoesqueletico: return "Musculoesquelético"
        case .musculoesqueleticoV2: return "Musculoesquelético v2"
        case .musculoesqueleticoRaras: return "Musculo raras"
        case .escrotal: return "Escrotal"
        case .regiaoInguinal: return "Região Inguinal"
        case .paredeAbdominal: return "Parede Abdominal"
        case .partesMoles: return "Partes Moles"
        case .prostataTransretal: return "Próstata Transretal"
        case .prostataSuprapubica: return "Próstata Suprapúbica"
        case .transfontanela: return "Transfontanela"
        case .dopplerCarotidas: return "Doppler Carótidas"
        case .dopplerVenosoMmii: return "Doppler Venoso MMII"
        case .dopplerVenosoMmiiMedidas: return "Doppler Venoso MMII (medidas)"
        case .dopplerArterialMmii: return "Doppler Arterial MMII"
        case .dopplerFistulaAv: return "Doppler Fístula AV"
        case .dopplerRenal: return "Doppler Renal"
        case .ocular: return "Ocular"
        }
    }

    var subtitle: String {
        switch self {
        case .abdomenTotal: return "Fígado, vias biliares, pâncreas, rins, baço"
        case .abdomenTotalDoppler: return "Abdome total com avaliação hemodinâmica"
        case .abdomenSuperior: return "Fígado, vias biliares, pâncreas, baço"
        case .viasUrinarias: return "Rins, ureteres, bexiga"
        case .tireoide: return "Tireoide com Doppler quando indicado"
        case .paratireoide: return "Glândulas paratireoides"
        case .cervical: return "Região cervical não-tireoidiana"
        case .glandulasSalivares: return "Parótidas e submandibulares"
        case .mamaria: return "BI-RADS"
        case .pelveFeminina: return "Útero, ovários e anexos"
        case .obstetrica: return "USG obstétrico"
        case .dopplerObstetrico: return "Hemodinâmica fetal"
        case .morfologico: return "Anatomia fetal completa"
        case .musculoesqueletico: return "Articulações e partes moles"
        case .musculoesqueleticoV2: return "Musculoesquelético v2"
        case .musculoesqueleticoRaras: return "Indicações raras"
        case .escrotal: return "Testículos, epidídimos"
        case .regiaoInguinal: return "Canal inguinal e hérnias"
        case .paredeAbdominal: return "Hérnias, coleções"
        case .partesMoles: return "Lesões superficiais"
        case .prostataTransretal: return "Próstata via transretal"
        case .prostataSuprapubica: return "Próstata via suprapúbica"
        case .transfontanela: return "Neonatal"
        case .dopplerCarotidas: return "Carótidas e vertebrais"
        case .dopplerVenosoMmii: return "TVP/insuficiência"
        case .dopplerVenosoMmiiMedidas: return "Mapeamento venoso pré-op"
        case .dopplerArterialMmii: return "Doença arterial periférica"
        case .dopplerFistulaAv: return "FAV para hemodiálise"
        case .dopplerRenal: return "Artérias renais"
        case .ocular: return "Globo ocular e órbita"
        }
    }

    var tintHex: String {
        switch self {
        case .abdomenTotal, .abdomenTotalDoppler, .abdomenSuperior: return "059669"
        case .viasUrinarias: return "06B6D4"
        case .tireoide, .paratireoide, .cervical, .glandulasSalivares: return "0EA5E9"
        case .mamaria: return "F43F5E"
        case .pelveFeminina: return "A855F7"
        case .obstetrica: return "EC4899"
        case .dopplerObstetrico: return "F97316"
        case .morfologico: return "8B5CF6"
        case .musculoesqueletico, .musculoesqueleticoV2, .musculoesqueleticoRaras: return "84CC16"
        case .escrotal, .regiaoInguinal, .paredeAbdominal, .partesMoles, .prostataTransretal, .prostataSuprapubica: return "10B981"
        case .transfontanela, .ocular: return "6366F1"
        case .dopplerCarotidas, .dopplerVenosoMmii, .dopplerVenosoMmiiMedidas, .dopplerArterialMmii, .dopplerFistulaAv, .dopplerRenal: return "F59E0B"
        }
    }

    var tint: Color { Color(hex: tintHex) }

    var iconSystemName: String {
        switch self {
        case .abdomenTotal, .abdomenTotalDoppler, .abdomenSuperior: return "circle.hexagongrid"
        case .viasUrinarias: return "drop"
        case .tireoide, .paratireoide: return "shield.lefthalf.filled"
        case .cervical, .glandulasSalivares: return "person.crop.circle.badge.checkmark"
        case .mamaria: return "heart.text.square"
        case .pelveFeminina: return "figure.dress"
        case .obstetrica, .dopplerObstetrico, .morfologico: return "figure.and.child.holdinghands"
        case .musculoesqueletico, .musculoesqueleticoV2, .musculoesqueleticoRaras: return "figure.run"
        case .escrotal, .regiaoInguinal, .paredeAbdominal, .partesMoles: return "circle.dashed"
        case .prostataTransretal, .prostataSuprapubica: return "circle.grid.cross"
        case .transfontanela: return "brain.head.profile"
        case .ocular: return "eye"
        case .dopplerCarotidas, .dopplerVenosoMmii, .dopplerVenosoMmiiMedidas, .dopplerArterialMmii, .dopplerFistulaAv, .dopplerRenal: return "waveform.path.ecg"
        }
    }

    static let priority: [ReportCategory] = [
        .abdomenTotal,
        .tireoide,
        .mamaria,
        .pelveFeminina,
        .obstetrica,
        .dopplerObstetrico,
        .morfologico,
        .viasUrinarias,
        .musculoesqueleticoV2,
        .dopplerCarotidas,
        .dopplerVenosoMmii,
        .abdomenSuperior,
        .escrotal,
    ]
}
