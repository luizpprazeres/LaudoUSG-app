import SwiftUI

/// Editor manual de miomas (Step 2) — CRUD com preview ao vivo do esquema +
/// envio pra Sala. FIGO / localização / tamanho / ecotextura.
struct MyomaEditorScreen: View {
    var reportId: String?
    @State private var myomas: [MyomaFinding]
    @State private var sending = false
    @State private var sendResult: String?

    /// Abre com os miomas PARSEADOS do laudo (auto-import). Se vazio, 1 em branco.
    init(reportId: String? = nil, initialFindings: [MyomaFinding] = []) {
        self.reportId = reportId
        _myomas = State(initialValue: initialFindings.isEmpty ? [MyomaFinding()] : initialFindings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MyomaSheetPreview(findings: myomas)

                HStack {
                    Text("Nódulos (\(myomas.count))").font(TextStyle.bodyLargeMedium)
                    Spacer()
                    Button {
                        withAnimation { myomas.append(MyomaFinding()) }
                    } label: {
                        Label("Adicionar", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "0F9B6E"))
                    }
                }

                ForEach($myomas) { $m in
                    MyomaRow(numero: (myomas.firstIndex { $0.id == m.id } ?? 0) + 1, myoma: $m) {
                        withAnimation { myomas.removeAll { $0.id == m.id } }
                    }
                }

                sendButton.padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Editor de miomas (FIGO)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sendButton: some View {
        VStack(spacing: 6) {
            Button {
                Task { await send() }
            } label: {
                HStack {
                    if sending { ProgressView().controlSize(.small) }
                    Image(systemName: "paperplane.fill")
                    Text(sending ? "Enviando…" : "Enviar p/ Sala")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "0F9B6E")))
            }
            .disabled(sending || myomas.isEmpty || myomas.contains { $0.figo == nil })
            if myomas.contains(where: { $0.figo == nil }) {
                Text("Confirme a categoria FIGO de todos os nódulos antes de enviar.")
                    .font(.footnote)
                    .foregroundStyle(SemanticColor.warningText)
            }
            if let r = sendResult {
                Text(r).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    @MainActor
    private func send() async {
        sending = true; sendResult = nil
        defer { sending = false }
        let ok = await MyomaSchemaSender.send(
            findings: myomas, examLabel: "Pelve — miomas (FIGO)", reportId: reportId
        )
        sendResult = ok ? "Enviado pra Sala ✓" : "Falha ao enviar. Tente de novo."
    }
}

/// Linha editável de um mioma.
private struct MyomaRow: View {
    /// Posição na descrição do laudo (M1, M2…), a mesma da folha A4.
    var numero: Int
    @Binding var myoma: MyomaFinding
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("M\(numero)")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 7).frame(height: 22)
                    .background(Capsule().fill(myoma.family?.color ?? Color.secondary))
                Text(myoma.figo.flatMap { value in FigoCategory.all.first(where: { $0.figo == value })?.titulo } ?? "Classificação pendente")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                }
            }

            // FIGO
            Picker("FIGO", selection: $myoma.figo) {
                Text("Selecione a categoria FIGO").tag(Int?.none)
                ForEach(FigoCategory.all) { c in
                    Text("FIGO \(c.figo) — \(c.titulo)").tag(Int?.some(c.figo))
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)

            HStack(spacing: 12) {
                // Localização
                Picker("Local", selection: $myoma.localizacao) {
                    ForEach(MyomaLocation.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu).tint(.primary)

                Spacer()

                // Tamanho (maior eixo, mm)
                HStack(spacing: 4) {
                    TextField("mm", value: $myoma.sizeMaxMm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                    Text("mm").font(.footnote).foregroundStyle(.secondary)
                }
            }

            // Ecotextura (opcional)
            Picker("Ecotextura", selection: $myoma.ecotextura) {
                Text("Ecotextura —").tag(MyomaEcho?.none)
                ForEach(MyomaEcho.allCases) { Text($0.rawValue).tag(MyomaEcho?.some($0)) }
            }
            .pickerStyle(.menu).tint(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}

/// Prévia da folha A4 (as três vistas + legenda M1, M2…), refeita quando os miomas mudam, e o PDF para compartilhar.
private struct MyomaSheetPreview: View {
    var findings: [MyomaFinding]
    @State private var imagem: UIImage?
    @State private var pdf: URL?

    private var itens: [MyomaSheetItem] { findings.map(MyomaSheetItem.init) }

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if let imagem {
                    Image(uiImage: imagem).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Color.white.aspectRatio(MyomaSheetRenderer.pageSize.width / MyomaSheetRenderer.pageSize.height, contentMode: .fit)
                        .overlay(ProgressView())
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .accessibilityLabel("Folha A4 com o esquema dos miomas")

            if let pdf {
                ShareLink(item: pdf) {
                    Label("Compartilhar PDF", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .task(id: itens) {
            try? await Task.sleep(for: .milliseconds(250))   // espera o médico parar de digitar
            guard !Task.isCancelled else { return }
            let atual = itens
            imagem = MyomaSheetRenderer.render(atual, scale: 0.4)
            if let data = MyomaSheetRenderer.renderPDF(atual) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mapa de miomas.pdf")
                if (try? data.write(to: url, options: .atomic)) != nil { pdf = url }
            }
        }
    }
}

#Preview {
    NavigationStack { MyomaEditorScreen() }
}
