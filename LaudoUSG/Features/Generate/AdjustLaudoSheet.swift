import SwiftUI

/// "Ajustar laudo" — edição incremental por linguagem natural. O médico descreve o
/// ajuste (ex.: "muda a frase do líquido, ILA 10,4") e o servidor reescreve SÓ o que
/// foi pedido (diff-guard). accepted=false → mostra o motivo + opção de aplicar mesmo
/// assim. (v1: campo de texto; ditado por voz é refinamento futuro.)
struct AdjustLaudoSheet: View {
    @Bindable var vm: GenerateViewModel

    private var canSubmit: Bool {
        !vm.adjustInProgress
            && vm.adjustInstruction.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Descreva o ajuste em linguagem natural. Ex.: \u{201C}muda a frase do líquido, ILA 10,4\u{201D}.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("O que ajustar?", text: $vm.adjustInstruction, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .disabled(vm.adjustInProgress)

                if let reason = vm.adjustReason {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A edição mexeu em mais do que o pedido:")
                            .font(.subheadline).bold()
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button("Aplicar mesmo assim") { vm.applyAdjustOverride() }
                                .buttonStyle(.borderedProminent)
                            Button("Refazer") {
                                vm.adjustReason = nil
                                vm.adjustPendingText = nil
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if let error = vm.adjustError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button {
                    Task { await vm.submitAdjust() }
                } label: {
                    if vm.adjustInProgress {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Aplicar ajuste").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
            .padding(20)
            .navigationTitle("Ajustar laudo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { vm.isAdjustSheetPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
