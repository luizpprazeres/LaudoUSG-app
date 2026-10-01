import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ClinicalModelWorkspace: View {
    let category: ReportCategory
    let writingStyleId: String

    @State private var state: ClinicalModelWorkspaceState
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var isSalaPresented = false
    @State private var copied = false

    init(category: ReportCategory, writingStyleId: String) {
        self.category = category
        self.writingStyleId = writingStyleId
        let key = "clinical-model-draft.\(category.rawValue)"
        let restored = UserDefaults.standard.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(ClinicalModelWorkspaceState.self, from: $0) }
            .map(\.draftForPersistence)
        let draft = ClinicalModelDraft.empty(for: category)!
        _state = State(initialValue: restored ?? .init(draft: draft))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                editor
                issuesSection
                if let preview = state.previewText {
                    Section("Prévia determinística") {
                        Text(preview)
                            .font(.system(.footnote, design: .serif))
                            .textSelection(.enabled)
                    }
                }
                workflowSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: state) { _, newValue in persist(newValue) }
        .sheet(isPresented: $isSalaPresented) {
            SalaPairingSheet(onDismiss: { isSalaPresented = false })
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandLogo(size: .small)
            VStack(alignment: .leading, spacing: 1) {
                Text(category.label).font(.headline)
                Text("Modelo clínico estruturado").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.canCopyOrSendToSala ? "Revisado" : "Rascunho")
                .font(.caption.weight(.semibold))
                .foregroundStyle(state.canCopyOrSendToSala ? .green : .orange)
        }
        .padding()
        .background(.background)
    }

    @ViewBuilder
    private var editor: some View {
        switch state.draft {
        case .abdomen(let value):
            AbdomenClinicalEditor(value: value) { state.replaceDraft(.abdomen($0)) }
        case .venous(let value):
            VenousClinicalEditor(value: value) { state.replaceDraft(.venous($0)) }
        case .arterial(let value):
            ArterialClinicalEditor(value: value) { state.replaceDraft(.arterial($0)) }
        case .thorax(let value):
            ThoraxClinicalEditor(value: value) { state.replaceDraft(.thorax($0)) }
        case .hip(let value):
            HipClinicalEditor(value: value) { state.replaceDraft(.hip($0)) }
        }
    }

    @ViewBuilder
    private var issuesSection: some View {
        if !state.blockingIssues.isEmpty || !state.warnings.isEmpty || errorMessage != nil {
            Section("Pendências") {
                ForEach(Array(state.blockingIssues.enumerated()), id: \.offset) { _, issue in
                    Label(issue.message, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
                ForEach(Array(state.warnings.enumerated()), id: \.offset) { _, issue in
                    Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
    }

    private var workflowSection: some View {
        Section("Revisão") {
            Button("Gerar prévia") {
                run { _ = try state.preparePreview() }
            }
            .disabled(isBusy || !state.blockingIssues.isEmpty)

            Button("Salvar esta versão") {
                runAsync {
                    guard state.previewText != nil else {
                        throw ClinicalModelWorkflowError.remoteMismatch
                    }
                    let report = try await ClinicalReportService.create(
                        draft: state.draft,
                        writingStyleId: writingStyleId
                    )
                    try state.acceptCreatedReport(report)
                }
            }
            .disabled(isBusy || state.previewText == nil || state.remoteReport != nil)

            Button("Revisei o laudo e libero para uso") {
                runAsync {
                    guard let report = state.remoteReport else {
                        throw ClinicalModelWorkflowError.remoteMismatch
                    }
                    let response = try await ClinicalReportService.review(
                        reportId: report.id,
                        expectedRevision: report.contentRevision,
                        expectedText: report.generatedOutput
                    )
                    try state.acceptReview(response)
                }
            }
            .disabled(isBusy || state.remoteReport?.reviewState != .pending)

            HStack {
                Button(copied ? "Copiado" : "Copiar") {
                    guard state.canCopyOrSendToSala,
                          let text = state.remoteReport?.generatedOutput else { return }
                    #if canImport(UIKit)
                    UIPasteboard.general.string = text
                    #endif
                    copied = true
                }
                Spacer()
                Button("Sala do Auxiliar") { isSalaPresented = true }
            }
            .disabled(!state.canCopyOrSendToSala)

            if isBusy { ProgressView().frame(maxWidth: .infinity) }
            Text("Qualquer edição invalida a revisão anterior e exige nova confirmação da versão exata.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func run(_ operation: () throws -> Void) {
        errorMessage = nil
        do { try operation() } catch { errorMessage = error.localizedDescription }
    }

    private func runAsync(_ operation: @escaping @MainActor () async throws -> Void) {
        errorMessage = nil
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do { try await operation() } catch { errorMessage = error.localizedDescription }
        }
    }

    private func persist(_ value: ClinicalModelWorkspaceState) {
        let key = "clinical-model-draft.\(category.rawValue)"
        guard let data = try? JSONEncoder().encode(value.draftForPersistence) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct AbdomenClinicalEditor: View {
    let value: AbdomenTotalDopplerDraft
    let onChange: (AbdomenTotalDopplerDraft) -> Void

    var body: some View {
        Section("Abdome e veia porta") {
            Picker("Documentação fotográfica", selection: Binding(
                get: { value.documentationPhoto },
                set: { var copy = value; copy.documentationPhoto = $0; onChange(copy) }
            )) {
                Text("Incluir frase configurada").tag(AbdomenTotalDopplerDraft.DocumentationPhoto.include)
                Text("Omitir frase").tag(AbdomenTotalDopplerDraft.DocumentationPhoto.omit)
            }
            TextEditor(text: binding(\.abdomenReport))
                .frame(minHeight: 110)
            TextField("Calibre da veia porta (cm)", text: numberBinding(
                get: { value.portalVein.caliberCm },
                set: { var copy = value; copy.portalVein.caliberCm = $0; onChange(copy) }
            ))
            .keyboardType(.decimalPad)
            TextField("Velocidade da veia porta (cm/s)", text: numberBinding(
                get: { value.portalVein.velocityCms },
                set: { var copy = value; copy.portalVein.velocityCms = $0; onChange(copy) }
            ))
            .keyboardType(.decimalPad)
            Picker("Fluxo portal", selection: Binding(
                get: { value.portalVein.flow },
                set: { var copy = value; copy.portalVein.flow = $0; onChange(copy) }
            )) {
                Text("Selecione").tag(AbdomenTotalDopplerDraft.FlowDirection?.none)
                Text("Hepatopetal").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.hepatopetal))
                Text("Hepatofugal").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.hepatofugal))
                Text("Ausente").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.absent))
                Text("Outro").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.other))
            }
            Picker("Situação portal", selection: Binding(
                get: { value.portalPathology.status },
                set: { var copy = value; copy.portalPathology.status = $0; onChange(copy) }
            )) {
                Text("Ausente").tag(AbdomenTotalDopplerDraft.PortalStatus.absent)
                Text("Suspeita").tag(AbdomenTotalDopplerDraft.PortalStatus.suspected)
                Text("Confirmada").tag(AbdomenTotalDopplerDraft.PortalStatus.confirmed)
            }
            if value.portalPathology.status != .absent {
                Picker("Tipo de alteração", selection: Binding(
                    get: { value.portalPathology.kind },
                    set: { var copy = value; copy.portalPathology.kind = $0; onChange(copy) }
                )) {
                    Text("Selecione").tag(AbdomenTotalDopplerDraft.PortalPathologyKind?.none)
                    Text("Hipertensão portal").tag(AbdomenTotalDopplerDraft.PortalPathologyKind?.some(.portalHypertension))
                    Text("Trombose portal").tag(AbdomenTotalDopplerDraft.PortalPathologyKind?.some(.portalThrombosis))
                    Text("Outra").tag(AbdomenTotalDopplerDraft.PortalPathologyKind?.some(.other))
                }
                TextField("Critérios e achados", text: optionalBinding(
                    get: { value.portalPathology.evidence },
                    set: { var copy = value; copy.portalPathology.evidence = $0; onChange(copy) }
                ))
                Toggle("Critérios confirmados pelo médico", isOn: Binding(
                    get: { value.portalPathology.physicianConfirmed },
                    set: { var copy = value; copy.portalPathology.physicianConfirmed = $0; onChange(copy) }
                ))
            }
            DisclosureGroup("Vasos opcionais") {
                optionalVessel("Veias hepáticas", value.hepaticVeins) {
                    var copy = value; copy.hepaticVeins = $0; onChange(copy)
                }
                optionalVessel("Veia esplênica", value.splenicVein) {
                    var copy = value; copy.splenicVein = $0; onChange(copy)
                }
                optionalVessel("Veia mesentérica superior", value.superiorMesentericVein) {
                    var copy = value; copy.superiorMesentericVein = $0; onChange(copy)
                }
                optionalVessel("Artéria hepática comum", value.commonHepaticArtery) {
                    var copy = value; copy.commonHepaticArtery = $0; onChange(copy)
                }
            }
        }
    }

    private func optionalVessel(
        _ label: String,
        _ vessel: AbdomenTotalDopplerDraft.OptionalVessel,
        change: @escaping (AbdomenTotalDopplerDraft.OptionalVessel) -> Void
    ) -> some View {
        VStack(alignment: .leading) {
            Toggle(label, isOn: Binding(get: { vessel.evaluated }, set: {
                var copy = vessel; copy.evaluated = $0
                if !$0 { copy.caliberCm = nil; copy.velocityCms = nil; copy.flow = nil }
                change(copy)
            }))
            if vessel.evaluated {
                TextField("Calibre (cm)", text: numberBinding(
                    get: { vessel.caliberCm },
                    set: { var copy = vessel; copy.caliberCm = $0; change(copy) }
                )).keyboardType(.decimalPad)
                TextField("Velocidade (cm/s)", text: numberBinding(
                    get: { vessel.velocityCms },
                    set: { var copy = vessel; copy.velocityCms = $0; change(copy) }
                )).keyboardType(.decimalPad)
                Picker("Fluxo", selection: Binding(
                    get: { vessel.flow },
                    set: { var copy = vessel; copy.flow = $0; change(copy) }
                )) {
                    Text("Selecione").tag(AbdomenTotalDopplerDraft.FlowDirection?.none)
                    Text("Hepatopetal").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.hepatopetal))
                    Text("Hepatofugal").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.hepatofugal))
                    Text("Ausente").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.absent))
                    Text("Outro").tag(AbdomenTotalDopplerDraft.FlowDirection?.some(.other))
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AbdomenTotalDopplerDraft, String>) -> Binding<String> {
        Binding(get: { value[keyPath: keyPath] }, set: {
            var copy = value; copy[keyPath: keyPath] = $0; onChange(copy)
        })
    }
}

private struct VenousClinicalEditor: View {
    let value: DopplerVenosoMmssDraft
    let onChange: (DopplerVenosoMmssDraft) -> Void

    var body: some View {
        Section("Escopo") {
            Picker("Indicação", selection: Binding(
                get: { value.indication },
                set: { var copy = value; copy.indication = $0; onChange(copy) }
            )) {
                Text("Eletiva").tag(DopplerVenosoMmssDraft.Indication.elective)
                Text("Pesquisa de trombose").tag(DopplerVenosoMmssDraft.Indication.thrombosisResearch)
                Text("Cateter").tag(DopplerVenosoMmssDraft.Indication.catheter)
            }
            Picker("Lateralidade", selection: Binding(
                get: { value.laterality },
                set: {
                    var copy = value; copy.laterality = $0
                    copy.right.examined = $0 != .left
                    copy.left.examined = $0 != .right
                    onChange(copy)
                }
            )) {
                Text("Direito").tag(ExamLaterality.right)
                Text("Esquerdo").tag(ExamLaterality.left)
                Text("Bilateral").tag(ExamLaterality.bilateral)
            }
        }
        venousSide("Direito", side: value.right) { var copy = value; copy.right = $0; onChange(copy) }
        venousSide("Esquerdo", side: value.left) { var copy = value; copy.left = $0; onChange(copy) }
    }

    private func venousSide(
        _ label: String,
        side: DopplerVenosoMmssDraft.Side,
        change: @escaping (DopplerVenosoMmssDraft.Side) -> Void
    ) -> some View {
        Section(label) {
            Toggle("Examinado", isOn: Binding(get: { side.examined }, set: {
                var copy = side; copy.examined = $0; change(copy)
            }))
            if side.examined {
                statusPicker("Sistema profundo", side.deepSystem) {
                    var copy = side; copy.deepSystem = $0; change(copy)
                }
                statusPicker("Sistema superficial", side.superficialSystem) {
                    var copy = side; copy.superficialSystem = $0; change(copy)
                }
                Picker("Jugular interna", selection: Binding(
                    get: { side.internalJugular },
                    set: { var copy = side; copy.internalJugular = $0; change(copy) }
                )) {
                    Text("Não avaliada").tag(DopplerVenosoMmssDraft.JugularStatus.notAssessed)
                    Text("Pérvia").tag(DopplerVenosoMmssDraft.JugularStatus.patent)
                    Text("Trombose").tag(DopplerVenosoMmssDraft.JugularStatus.thrombosis)
                }
                Toggle("Competência/refluxo testado", isOn: Binding(
                    get: { side.competenceTested },
                    set: {
                        var copy = side; copy.competenceTested = $0
                        if !$0 { copy.reflux = .notAssessed }
                        change(copy)
                    }
                ))
                if side.competenceTested {
                    Picker("Refluxo", selection: Binding(
                        get: { side.reflux },
                        set: { var copy = side; copy.reflux = $0; change(copy) }
                    )) {
                        Text("Ausente").tag(DopplerVenosoMmssDraft.Reflux.absent)
                        Text("Presente").tag(DopplerVenosoMmssDraft.Reflux.present)
                    }
                }
                Toggle("Cateter presente", isOn: Binding(
                    get: { side.catheter.present },
                    set: { var copy = side; copy.catheter.present = $0; change(copy) }
                ))
                if side.catheter.present {
                    TextField("Segmento do cateter", text: optionalBinding(
                        get: { side.catheter.segment },
                        set: { var copy = side; copy.catheter.segment = $0; change(copy) }
                    ))
                    Picker("Relação com o trombo", selection: Binding(
                        get: { side.catheter.relation },
                        set: { var copy = side; copy.catheter.relation = $0; change(copy) }
                    )) {
                        Text("Selecione").tag(DopplerVenosoMmssDraft.CatheterRelation?.none)
                        Text("Adjacente").tag(DopplerVenosoMmssDraft.CatheterRelation?.some(.adjacent))
                        Text("Ao redor do cateter").tag(DopplerVenosoMmssDraft.CatheterRelation?.some(.aroundCatheter))
                        Text("Oclusiva").tag(DopplerVenosoMmssDraft.CatheterRelation?.some(.occlusive))
                    }
                }
                if side.deepSystem == .thrombosis || side.superficialSystem == .thrombosis || side.internalJugular == .thrombosis {
                    Picker("Fase da trombose", selection: Binding(
                        get: { side.thrombosisPhase },
                        set: { var copy = side; copy.thrombosisPhase = $0; change(copy) }
                    )) {
                        Text("Não classificada").tag(DopplerVenosoMmssDraft.ThrombosisPhase.notApplicable)
                        Text("Aguda").tag(DopplerVenosoMmssDraft.ThrombosisPhase.acute)
                        Text("Subaguda").tag(DopplerVenosoMmssDraft.ThrombosisPhase.subacute)
                        Text("Crônica").tag(DopplerVenosoMmssDraft.ThrombosisPhase.chronic)
                        Text("Indeterminada").tag(DopplerVenosoMmssDraft.ThrombosisPhase.indeterminate)
                    }
                    if ![DopplerVenosoMmssDraft.ThrombosisPhase.notApplicable, .indeterminate].contains(side.thrombosisPhase) {
                        Toggle("Fase confirmada pelo médico", isOn: Binding(
                            get: { side.phaseConfirmed },
                            set: { var copy = side; copy.phaseConfirmed = $0; change(copy) }
                        ))
                    }
                }
            }
        }
    }

    private func statusPicker(
        _ label: String,
        _ selected: DopplerVenosoMmssDraft.SystemStatus,
        change: @escaping (DopplerVenosoMmssDraft.SystemStatus) -> Void
    ) -> some View {
        Picker(label, selection: Binding(get: { selected }, set: change)) {
            Text("Não avaliado").tag(DopplerVenosoMmssDraft.SystemStatus.notAssessed)
            Text("Pérvio").tag(DopplerVenosoMmssDraft.SystemStatus.patent)
            Text("Trombose").tag(DopplerVenosoMmssDraft.SystemStatus.thrombosis)
        }
    }
}

private struct ArterialClinicalEditor: View {
    let value: DopplerArterialMmssDraft
    let onChange: (DopplerArterialMmssDraft) -> Void

    var body: some View {
        Section("Escopo") {
            Picker("Lateralidade", selection: Binding(
                get: { value.laterality },
                set: {
                    var copy = value; copy.laterality = $0
                    copy.right.examined = $0 != .left
                    copy.left.examined = $0 != .right
                    onChange(copy)
                }
            )) {
                Text("Direito").tag(ExamLaterality.right)
                Text("Esquerdo").tag(ExamLaterality.left)
                Text("Bilateral").tag(ExamLaterality.bilateral)
            }
        }
        arterialSide("Direito", side: value.right) { var copy = value; copy.right = $0; onChange(copy) }
        arterialSide("Esquerdo", side: value.left) { var copy = value; copy.left = $0; onChange(copy) }
    }

    private func arterialSide(
        _ label: String,
        side: DopplerArterialMmssDraft.Side,
        change: @escaping (DopplerArterialMmssDraft.Side) -> Void
    ) -> some View {
        Section(label) {
            Toggle("Examinado", isOn: Binding(get: { side.examined }, set: {
                var copy = side; copy.examined = $0; change(copy)
            }))
            if side.examined {
                Picker("Resultado", selection: Binding(
                    get: { side.status },
                    set: {
                        var copy = side; copy.status = $0
                        if $0 != .stenosis {
                            copy.stenosisPercent = nil
                            copy.percentageDataSufficient = false
                            copy.percentageConfirmed = false
                        }
                        change(copy)
                    }
                )) {
                    Text("Normal").tag(DopplerArterialMmssDraft.ArterialStatus.normal)
                    Text("Estenose").tag(DopplerArterialMmssDraft.ArterialStatus.stenosis)
                    Text("Oclusão").tag(DopplerArterialMmssDraft.ArterialStatus.occlusion)
                    Text("Outra").tag(DopplerArterialMmssDraft.ArterialStatus.other)
                }
                if side.status != .normal {
                    TextField("Vaso afetado", text: optionalBinding(
                        get: { side.affectedVessel },
                        set: { var copy = side; copy.affectedVessel = $0; change(copy) }
                    ))
                    TextField("VPS no vaso afetado (cm/s)", text: numberBinding(
                        get: { side.affectedVessel.flatMap { side.psvCms[$0] } },
                        set: { newValue in
                            var copy = side
                            if let vessel = copy.affectedVessel, !vessel.isEmpty {
                                if let newValue { copy.psvCms[vessel] = newValue } else { copy.psvCms.removeValue(forKey: vessel) }
                            }
                            change(copy)
                        }
                    ))
                    .keyboardType(.decimalPad)
                    TextField("Padrão distal", text: optionalBinding(
                        get: { side.distalPattern },
                        set: { var copy = side; copy.distalPattern = $0; change(copy) }
                    ))
                    if side.status == .stenosis {
                        TextField("Percentual de estenose", text: numberBinding(
                            get: { side.stenosisPercent },
                            set: { var copy = side; copy.stenosisPercent = $0; change(copy) }
                        )).keyboardType(.decimalPad)
                        Toggle("Dados suficientes para percentual", isOn: Binding(
                            get: { side.percentageDataSufficient },
                            set: { var copy = side; copy.percentageDataSufficient = $0; change(copy) }
                        ))
                        Toggle("Percentual confirmado pelo médico", isOn: Binding(
                            get: { side.percentageConfirmed },
                            set: { var copy = side; copy.percentageConfirmed = $0; change(copy) }
                        ))
                    }
                }
                DisclosureGroup("Velocidades de pico sistólico") {
                    psvField("Artéria subclávia", side: side, change: change)
                    psvField("Artéria axilar", side: side, change: change)
                    psvField("Artéria braquial", side: side, change: change)
                    psvField("Artéria radial", side: side, change: change)
                    psvField("Artéria ulnar", side: side, change: change)
                }
                Toggle("Avaliar desfiladeiro torácico", isOn: Binding(
                    get: { side.thoracicOutlet.evaluated },
                    set: {
                        var copy = side; copy.thoracicOutlet.evaluated = $0
                        if !$0 {
                            copy.thoracicOutlet.maneuvers = nil
                            copy.thoracicOutlet.positions = nil
                            copy.thoracicOutlet.result = nil
                            copy.thoracicOutlet.physicianConfirmed = nil
                        }
                        change(copy)
                    }
                ))
                if side.thoracicOutlet.evaluated {
                    TextField("Manobras realizadas", text: optionalBinding(
                        get: { side.thoracicOutlet.maneuvers },
                        set: { var copy = side; copy.thoracicOutlet.maneuvers = $0; change(copy) }
                    ))
                    TextField("Posições avaliadas", text: optionalBinding(
                        get: { side.thoracicOutlet.positions },
                        set: { var copy = side; copy.thoracicOutlet.positions = $0; change(copy) }
                    ))
                    Picker("Resultado das manobras", selection: Binding(
                        get: { side.thoracicOutlet.result },
                        set: { var copy = side; copy.thoracicOutlet.result = $0; change(copy) }
                    )) {
                        Text("Selecione").tag(DopplerArterialMmssDraft.OutletResult?.none)
                        Text("Negativo").tag(DopplerArterialMmssDraft.OutletResult?.some(.negative))
                        Text("Positivo").tag(DopplerArterialMmssDraft.OutletResult?.some(.positive))
                        Text("Indeterminado").tag(DopplerArterialMmssDraft.OutletResult?.some(.indeterminate))
                    }
                    Toggle("Módulo confirmado pelo médico", isOn: Binding(
                        get: { side.thoracicOutlet.physicianConfirmed == true },
                        set: { var copy = side; copy.thoracicOutlet.physicianConfirmed = $0; change(copy) }
                    ))
                }
            }
        }
    }

    private func psvField(
        _ vessel: String,
        side: DopplerArterialMmssDraft.Side,
        change: @escaping (DopplerArterialMmssDraft.Side) -> Void
    ) -> some View {
        TextField("\(vessel) (cm/s)", text: numberBinding(
            get: { side.psvCms[vessel] },
            set: { newValue in
                var copy = side
                if let newValue { copy.psvCms[vessel] = newValue }
                else { copy.psvCms.removeValue(forKey: vessel) }
                change(copy)
            }
        )).keyboardType(.decimalPad)
    }
}

private struct ThoraxClinicalEditor: View {
    let value: ThoraxDraft
    let onChange: (ThoraxDraft) -> Void

    var body: some View {
        thoraxSide("Hemitórax direito", side: value.right) { var copy = value; copy.right = $0; onChange(copy) }
        thoraxSide("Hemitórax esquerdo", side: value.left) { var copy = value; copy.left = $0; onChange(copy) }
        Section("Complemento") {
            TextField("Limitação, se houver", text: optionalBinding(
                get: { value.limitation },
                set: { var copy = value; copy.limitation = $0; onChange(copy) }
            ))
            Toggle("Sugerir correlação clínica", isOn: Binding(
                get: { value.correlationSuggested },
                set: { var copy = value; copy.correlationSuggested = $0; onChange(copy) }
            ))
        }
    }

    private func thoraxSide(
        _ label: String,
        side: ThoraxDraft.Side,
        change: @escaping (ThoraxDraft.Side) -> Void
    ) -> some View {
        Section(label) {
            Picker("Linha pleural", selection: Binding(
                get: { side.pleuralLine },
                set: { var copy = side; copy.pleuralLine = $0; change(copy) }
            )) {
                Text("Regular").tag(ThoraxDraft.PleuralLine.regular)
                Text("Irregular").tag(ThoraxDraft.PleuralLine.irregular)
                Text("Não avaliada").tag(ThoraxDraft.PleuralLine.notAssessed)
            }
            Picker("Deslizamento", selection: Binding(
                get: { side.sliding },
                set: { var copy = side; copy.sliding = $0; change(copy) }
            )) {
                Text("Presente").tag(ThoraxDraft.Sliding.present)
                Text("Ausente").tag(ThoraxDraft.Sliding.absent)
                Text("Não avaliado").tag(ThoraxDraft.Sliding.notAssessed)
            }
            Stepper("Linhas B: \(side.linesB.count)", value: Binding(
                get: { side.linesB.count },
                set: {
                    var copy = side; copy.linesB.count = $0
                    copy.linesB.distribution = $0 == 0 ? .none : (copy.linesB.distribution == .none ? .focal : copy.linesB.distribution)
                    change(copy)
                }
            ), in: 0...99)
            if side.linesB.count > 0 {
                Picker("Distribuição das linhas B", selection: Binding(
                    get: { side.linesB.distribution },
                    set: { var copy = side; copy.linesB.distribution = $0; change(copy) }
                )) {
                    Text("Focal").tag(ThoraxDraft.BLineDistribution.focal)
                    Text("Multifocal").tag(ThoraxDraft.BLineDistribution.multifocal)
                    Text("Difusa").tag(ThoraxDraft.BLineDistribution.diffuse)
                }
            }
            Toggle("Derrame pleural", isOn: Binding(
                get: { side.effusion.present },
                set: {
                    var copy = side; copy.effusion.present = $0
                    if $0 && copy.effusion.context == nil {
                        copy.effusion.context = .init(adult: false, mechanicallyVentilated: false, supineTorso15Deg: false, endExpirationPosteriorAxillary: false, physicianConfirmed: false)
                    }
                    if !$0 { copy.effusion.separationMm = nil; copy.effusion.context = nil }
                    change(copy)
                }
            ))
            if side.effusion.present {
                TextField("Separação máxima (mm)", text: numberBinding(
                    get: { side.effusion.separationMm },
                    set: { var copy = side; copy.effusion.separationMm = $0; change(copy) }
                ))
                .keyboardType(.decimalPad)
                Text("O volume só será calculado quando todos os critérios de Balik forem confirmados.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let context = side.effusion.context {
                    Toggle("Paciente adulto", isOn: balikBinding(context, side: side, change: change, keyPath: \.adult))
                    Toggle("Em ventilação mecânica", isOn: balikBinding(context, side: side, change: change, keyPath: \.mechanicallyVentilated))
                    Toggle("Supino, tronco a 15°", isOn: balikBinding(context, side: side, change: change, keyPath: \.supineTorso15Deg))
                    Toggle("Fim da expiração, linha axilar posterior", isOn: balikBinding(context, side: side, change: change, keyPath: \.endExpirationPosteriorAxillary))
                    Toggle("Contexto confirmado pelo médico", isOn: balikBinding(context, side: side, change: change, keyPath: \.physicianConfirmed))
                }
            }
            findingPicker("Consolidação", selected: side.consolidation) {
                var copy = side; copy.consolidation = $0; change(copy)
            }
            findingPicker("Atelectasia", selected: side.atelectasis) {
                var copy = side; copy.atelectasis = $0; change(copy)
            }
            findingPicker("Pneumotórax", selected: side.pneumothorax) {
                var copy = side; copy.pneumothorax = $0; change(copy)
            }
        }
    }

    private func balikBinding(
        _ context: ThoraxDraft.BalikContext,
        side: ThoraxDraft.Side,
        change: @escaping (ThoraxDraft.Side) -> Void,
        keyPath: WritableKeyPath<ThoraxDraft.BalikContext, Bool>
    ) -> Binding<Bool> {
        Binding(get: { context[keyPath: keyPath] }, set: {
            var copy = side
            var updated = context
            updated[keyPath: keyPath] = $0
            copy.effusion.context = updated
            change(copy)
        })
    }

    private func findingPicker(
        _ label: String,
        selected: ThoraxDraft.FindingStatus,
        change: @escaping (ThoraxDraft.FindingStatus) -> Void
    ) -> some View {
        Picker(label, selection: Binding(get: { selected }, set: change)) {
            Text("Não identificada").tag(ThoraxDraft.FindingStatus.notSeen)
            Text("Suspeita").tag(ThoraxDraft.FindingStatus.suspected)
            Text("Confirmada").tag(ThoraxDraft.FindingStatus.confirmed)
        }
    }
}

private struct HipClinicalEditor: View {
    let value: QuadrilInfantilDraft
    let onChange: (QuadrilInfantilDraft) -> Void

    var body: some View {
        Section("Paciente") {
            TextField("Idade em dias", text: intBinding(
                get: { value.ageDays },
                set: { var copy = value; copy.ageDays = $0; updateSuggestions(&copy); onChange(copy) }
            ))
            .keyboardType(.numberPad)
        }
        hipSide("Quadril direito", laterality: .right, side: value.right) {
            var copy = value; copy.right = $0; updateSuggestions(&copy); onChange(copy)
        }
        hipSide("Quadril esquerdo", laterality: .left, side: value.left) {
            var copy = value; copy.left = $0; updateSuggestions(&copy); onChange(copy)
        }
        Section("Conduta") {
            TextField("Controle ou encaminhamento", text: optionalBinding(
                get: { value.recommendation },
                set: { var copy = value; copy.recommendation = $0; onChange(copy) }
            ))
            if value.recommendation?.isEmpty == false {
                Toggle("Conduta confirmada pelo médico", isOn: Binding(
                    get: { value.recommendationConfirmed },
                    set: { var copy = value; copy.recommendationConfirmed = $0; onChange(copy) }
                ))
            }
        }
    }

    private func hipSide(
        _ label: String,
        laterality: ExamLaterality,
        side: QuadrilInfantilDraft.Side,
        change: @escaping (QuadrilInfantilDraft.Side) -> Void
    ) -> some View {
        Section(label) {
            Toggle("Corte padrão adequado", isOn: Binding(
                get: { side.adequateStandardPlane },
                set: {
                    var copy = side; copy.adequateStandardPlane = $0
                    if !$0 { copy.grafClassification = nil; copy.classificationConfirmed = false }
                    change(copy)
                }
            ))
            TextField("Ângulo alfa", text: numberBinding(
                get: { side.alphaDeg },
                set: { var copy = side; copy.alphaDeg = $0; change(copy) }
            ))
            .keyboardType(.decimalPad)
            TextField("Ângulo beta", text: numberBinding(
                get: { side.betaDeg },
                set: { var copy = side; copy.betaDeg = $0; change(copy) }
            ))
            .keyboardType(.decimalPad)
            Picker("Teto ósseo", selection: Binding(
                get: { side.bonyRoof },
                set: { var copy = side; copy.bonyRoof = $0; change(copy) }
            )) {
                Text("Não avaliado").tag(QuadrilInfantilDraft.BonyRoof.notAssessed)
                Text("Normal").tag(QuadrilInfantilDraft.BonyRoof.normal)
                Text("Arredondado").tag(QuadrilInfantilDraft.BonyRoof.rounded)
                Text("Deficiente").tag(QuadrilInfantilDraft.BonyRoof.deficient)
            }
            Picker("Teto cartilaginoso", selection: Binding(
                get: { side.cartilaginousRoof },
                set: { var copy = side; copy.cartilaginousRoof = $0; change(copy) }
            )) {
                Text("Não avaliado").tag(QuadrilInfantilDraft.CartilaginousRoof.notAssessed)
                Text("Normal").tag(QuadrilInfantilDraft.CartilaginousRoof.normal)
                Text("Deslocado").tag(QuadrilInfantilDraft.CartilaginousRoof.displaced)
            }
            Picker("Cabeça femoral", selection: Binding(
                get: { side.femoralHead },
                set: { var copy = side; copy.femoralHead = $0; change(copy) }
            )) {
                Text("Não avaliada").tag(QuadrilInfantilDraft.FemoralHead.notAssessed)
                Text("Centrada").tag(QuadrilInfantilDraft.FemoralHead.centered)
                Text("Descentrada").tag(QuadrilInfantilDraft.FemoralHead.decentered)
                Text("Luxada").tag(QuadrilInfantilDraft.FemoralHead.dislocated)
            }
            Picker("Labrum", selection: Binding(
                get: { side.labrumPosition },
                set: { var copy = side; copy.labrumPosition = $0; change(copy) }
            )) {
                Text("Não avaliado").tag(QuadrilInfantilDraft.LabrumPosition.notAssessed)
                Text("Normal").tag(QuadrilInfantilDraft.LabrumPosition.normal)
                Text("Evertido").tag(QuadrilInfantilDraft.LabrumPosition.everted)
                Text("Interposto").tag(QuadrilInfantilDraft.LabrumPosition.interposed)
            }
            TextField("Cobertura da cabeça femoral (%)", text: numberBinding(
                get: { side.coveragePercent },
                set: { var copy = side; copy.coveragePercent = $0; change(copy) }
            ))
            .keyboardType(.decimalPad)
            if let suggestion = value.suggestedGrafClassification(for: laterality) {
                Toggle("Confirmar Graf \(suggestion.rawValue)", isOn: Binding(
                    get: { side.classificationConfirmed && side.grafClassification == suggestion },
                    set: {
                        var copy = side
                        copy.grafClassification = $0 ? suggestion : nil
                        copy.classificationConfirmed = $0
                        change(copy)
                    }
                ))
            }
        }
    }

    private func updateSuggestions(_ draft: inout QuadrilInfantilDraft) {
        for side in [ExamLaterality.right, .left] {
            guard let suggestion = draft.suggestedGrafClassification(for: side) else { continue }
            if side == .right, draft.right.classificationConfirmed { draft.right.grafClassification = suggestion }
            if side == .left, draft.left.classificationConfirmed { draft.left.grafClassification = suggestion }
        }
    }
}

private func optionalBinding(get: @escaping () -> String?, set: @escaping (String?) -> Void) -> Binding<String> {
    Binding(get: { get() ?? "" }, set: { set($0.isEmpty ? nil : $0) })
}

private func numberBinding(get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> Binding<String> {
    Binding(
        get: { get().map { String($0).replacingOccurrences(of: ".", with: ",") } ?? "" },
        set: { set(Double($0.replacingOccurrences(of: ",", with: "."))) }
    )
}

private func intBinding(get: @escaping () -> Int?, set: @escaping (Int?) -> Void) -> Binding<String> {
    Binding(get: { get().map(String.init) ?? "" }, set: { set(Int($0)) })
}
