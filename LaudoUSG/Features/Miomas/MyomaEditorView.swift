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
                MyomaSchematicView(findings: $myomas)

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
                    MyomaRow(myoma: $m) {
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
            .disabled(sending || myomas.isEmpty)
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
    @Binding var myoma: MyomaFinding
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(myoma.family.color).frame(width: 22, height: 22)
                    .overlay(Text("\(myoma.figo)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                Text(FigoCategory.all[myoma.figo].titulo)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.red.opacity(0.8))
                }
            }

            // FIGO
            Picker("FIGO", selection: $myoma.figo) {
                ForEach(FigoCategory.all) { c in
                    Text("FIGO \(c.figo) — \(c.titulo)").tag(c.figo)
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

#Preview {
    NavigationStack { MyomaEditorScreen() }
}
