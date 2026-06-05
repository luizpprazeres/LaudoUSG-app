import SwiftUI

enum UterusView: String, CaseIterable {
    case longitudinal = "Longitudinal"
    case transversal = "Transversal"
}

/// Esquema visual de miomas (FIGO 0–8) com toggle entre as 2 visões.
struct MyomaSchematicView: View {
    var findings: [MyomaFinding] = MyomaFinding.exemplos
    @State private var view: UterusView = .longitudinal

    var body: some View {
        VStack(spacing: 14) {
            Picker("Visão", selection: $view) {
                ForEach(UterusView.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Group {
                if view == .longitudinal {
                    SagittalCanvasView(findings: findings)
                } else {
                    AxialCanvasView(findings: findings)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "E3DDD1"), lineWidth: 1)
            )
        }
    }
}

/// Tela com o esquema + legenda FIGO + envio pra Sala (debug / validação).
struct MyomaSchematicScreen: View {
    var findings: [MyomaFinding] = MyomaFinding.exemplos
    var reportId: String? = nil

    @State private var sending = false
    @State private var sendResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MyomaSchematicView(findings: findings)

                sendButton

                Text("Classificação FIGO (leiomioma)")
                    .font(TextStyle.bodyLargeMedium)
                    .padding(.top, 2)

                ForEach([FigoFamily.submucoso, .intramural, .subseroso, .outros], id: \.titulo) { fam in
                    Text(fam.titulo.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(fam.color)
                        .padding(.top, 6)
                    ForEach(FigoCategory.all.filter { $0.family == fam }, id: \.id) { c in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(c.figo)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(c.family.color))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.titulo).font(.system(size: 14, weight: .semibold))
                                Text(c.descricao).font(.system(size: 12.5)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Esquema de miomas (FIGO)")
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
            .disabled(sending)
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
            findings: findings, examLabel: "Pelve — miomas (FIGO)", reportId: reportId
        )
        sendResult = ok ? "Enviado pra Sala ✓" : "Falha ao enviar. Tente de novo."
    }
}

#Preview {
    NavigationStack { MyomaSchematicScreen() }
}
