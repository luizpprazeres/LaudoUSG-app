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
    case cervicometria = "CERVICOMETRIA"
    case musculoesqueletico = "MUSCULOESQUELETICO_V2"
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
    case dopplerVenosoMmss = "DOPPLER_VENOSO_MMSS"
    case dopplerArterialMmss = "DOPPLER_ARTERIAL_MMSS"
    case dopplerFistulaAv = "DOPPLER_FISTULA_AV"
    case dopplerRenal = "DOPPLER_RENAL"
    case torax = "TORAX"
    case quadrilInfantil = "QUADRIL_INFANTIL"
    case ocular = "OCULAR"
    /// Coringa: escreve com as regras gerais da casa, sem template de categoria.
    ///
    /// Serve para (a) exames que não têm categoria própria na lista — região
    /// perineal, por exemplo — e (b) quem não quer parar para escolher categoria.
    /// No backend é writer puro (`isFreeWriterCategory`), com o modelo normal.
    case livre = "LIVRE"

    var id: String { rawValue }

    /// Categorias aprovadas para iniciar um exame novo. Códigos legados seguem
    /// no enum para decodificar laudos já salvos, mesmo quando não são oferecidos.
    static var selectable: [ReportCategory] {
        allCases.filter {
            !$0.isExperimental
                && (!$0.isPendingClinicalActivation || PendingClinicalModelContracts.isRolloutEnabled)
        }
    }

    var isExperimental: Bool {
        self == .musculoesqueleticoRaras
    }

    /// Modelos clínicos com fluxo estruturado próprio. A propriedade permanece
    /// para encaminhá-los ao workspace correto e decodificar o histórico.
    var isPendingClinicalActivation: Bool {
        switch self {
        case .abdomenTotalDoppler, .dopplerVenosoMmss, .dopplerArterialMmss,
             .torax, .quadrilInfantil:
            return true
        default:
            return false
        }
    }

    var label: String {
        switch self {
        case .abdomenTotal: return "Abdome total"
        case .abdomenTotalDoppler: return "Abdome total com Doppler"
        case .abdomenSuperior: return "Abdome superior"
        case .viasUrinarias: return "Vias urinárias"
        case .tireoide: return "Tireoide"
        case .paratireoide: return "Paratireoides"
        case .cervical: return "Cervical"
        case .glandulasSalivares: return "Glândulas salivares"
        case .mamaria: return "Mamas e axilas"
        case .pelveFeminina: return "Pelve feminina"
        case .obstetrica: return "Obstétrica"
        case .dopplerObstetrico: return "Doppler obstétrico"
        case .morfologico: return "Morfológico"
        case .cervicometria: return "Cervicometria"
        case .musculoesqueletico: return "Musculoesquelético"
        case .musculoesqueleticoRaras: return "Musculoesquelético — raras"
        case .escrotal: return "Escrotal"
        case .regiaoInguinal: return "Região inguinal"
        case .paredeAbdominal: return "Parede abdominal"
        case .partesMoles: return "Partes moles"
        case .prostataTransretal: return "Próstata transretal"
        case .prostataSuprapubica: return "Próstata suprapúbica"
        case .transfontanela: return "Transfontanela"
        case .dopplerCarotidas: return "Doppler de carótidas e vertebrais"
        case .dopplerVenosoMmii: return "Doppler venoso de membros inferiores"
        case .dopplerVenosoMmiiMedidas: return "Doppler venoso de membros inferiores — completo"
        case .dopplerArterialMmii: return "Doppler arterial de membros inferiores"
        case .dopplerVenosoMmss: return "Doppler venoso de membros superiores"
        case .dopplerArterialMmss: return "Doppler arterial de membros superiores"
        case .dopplerFistulaAv: return "Doppler de fístula arteriovenosa"
        case .dopplerRenal: return "Doppler renal"
        case .torax: return "Ultrassonografia de tórax"
        case .quadrilInfantil: return "Quadril infantil"
        case .ocular: return "Ocular"
        case .livre: return "Laudo livre"
        }
    }

    /// Converte o código persistido em texto de interface. Categorias antigas
    /// ou recém-criadas também recebem um fallback legível, sem sublinhados.
    static func displayLabel(for code: String?) -> String {
        guard let normalized = code?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else { return "Categoria não informada" }
        if let category = ReportCategory(rawValue: normalized) { return category.label }
        if normalized == "ABDOMEN_TOTAL__PROSTATA_SUPRAPUBICA" {
            return "Abdome total + Próstata suprapúbica"
        }
        if normalized == "MAMARIA__PELVE_FEMININA" {
            return "Mamas e axilas + Pelve feminina"
        }

        let acronyms: Set<String> = ["AV", "MMII", "MMSS", "USG", "BI", "RADS"]
        return normalized.split(separator: "_").enumerated().map { index, token in
            let upper = token.uppercased()
            if acronyms.contains(upper) { return upper }
            let lower = token.lowercased()
            return index == 0 ? lower.prefix(1).uppercased() + String(lower.dropFirst()) : lower
        }.joined(separator: " ")
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
        case .mamaria: return "Mamas, axilas e BI-RADS"
        case .pelveFeminina: return "Útero, ovários e anexos"
        case .obstetrica: return "USG obstétrico"
        case .dopplerObstetrico: return "Hemodinâmica fetal"
        case .morfologico: return "Anatomia fetal completa"
        case .cervicometria: return "Colo uterino"
        case .musculoesqueletico: return "Articulações e partes moles"
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
        case .dopplerVenosoMmss: return "Trombose, cateteres e refluxo quando testado"
        case .dopplerArterialMmss: return "Estenoses e módulo de desfiladeiro torácico"
        case .dopplerFistulaAv: return "FAV para hemodiálise"
        case .dopplerRenal: return "Artérias renais"
        case .torax: return "Pulmões, pleuras e derrames"
        case .quadrilInfantil: return "Técnica de Graf · alerta fora de 0–6 meses"
        case .ocular: return "Globo ocular e órbita"
        case .livre: return "Qualquer exame, com as regras gerais da casa"
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
        case .morfologico, .cervicometria: return "8B5CF6"
        case .musculoesqueletico, .musculoesqueleticoRaras: return "84CC16"
        case .escrotal, .regiaoInguinal, .paredeAbdominal, .partesMoles, .prostataTransretal, .prostataSuprapubica: return "10B981"
        case .transfontanela, .quadrilInfantil, .ocular: return "6366F1"
        case .dopplerCarotidas, .dopplerVenosoMmii, .dopplerVenosoMmiiMedidas,
             .dopplerArterialMmii, .dopplerVenosoMmss, .dopplerArterialMmss,
             .dopplerFistulaAv, .dopplerRenal: return "F59E0B"
        case .torax: return "0EA5E9"
        case .livre: return "64748B"
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
        case .pelveFeminina: return "figure.stand"
        case .obstetrica, .dopplerObstetrico, .morfologico, .cervicometria: return "figure.and.child.holdinghands"
        case .musculoesqueletico, .musculoesqueleticoRaras: return "figure.run"
        case .escrotal, .regiaoInguinal, .paredeAbdominal, .partesMoles: return "circle.dashed"
        case .prostataTransretal, .prostataSuprapubica: return "circle.grid.cross"
        case .transfontanela: return "brain.head.profile"
        case .quadrilInfantil: return "figure.child"
        case .torax: return "lungs"
        case .ocular: return "eye"
        case .dopplerCarotidas, .dopplerVenosoMmii, .dopplerVenosoMmiiMedidas,
             .dopplerArterialMmii, .dopplerVenosoMmss, .dopplerArterialMmss,
             .dopplerFistulaAv, .dopplerRenal: return "waveform.path.ecg"
        case .livre: return "text.badge.plus"
        }
    }

    /// Linearts compartilhados com Web e Android. Categorias sem asset próprio
    /// continuam usando o SF Symbol existente.
    var lineartAssetName: String? {
        switch self {
        case .paredeAbdominal: return "CategoryParedeAbdominal"
        case .prostataTransretal: return "CategoryProstataTransretal"
        case .escrotal: return "CategoryEscrotal"
        case .regiaoInguinal: return "CategoryRegiaoInguinal"
        case .paratireoide: return "CategoryParatireoide"
        case .glandulasSalivares: return "CategoryGlandulasSalivares"
        case .dopplerVenosoMmii: return "CategoryDopplerVenosoMmii"
        case .dopplerVenosoMmiiMedidas: return "CategoryDopplerVenosoMmiiMedidas"
        case .dopplerArterialMmii: return "CategoryDopplerArterialMmii"
        case .dopplerFistulaAv: return "CategoryDopplerFistulaAv"
        case .dopplerRenal: return "CategoryDopplerRenal"
        case .transfontanela: return "CategoryTransfontanela"
        case .ocular: return "CategoryOcular"
        case .livre: return "CategoryLivre"
        default: return nil
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
        .cervicometria,
        .viasUrinarias,
        .musculoesqueletico,
        .dopplerCarotidas,
        .dopplerVenosoMmii,
        .dopplerArterialMmii,
        .dopplerRenal,
        .abdomenSuperior,
        .escrotal,
        .cervical,
        .glandulasSalivares,
    ]
}
