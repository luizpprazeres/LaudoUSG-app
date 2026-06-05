import SwiftUI

/// Modelo COMPLEMENTO: o watch só captura ditados e envia pro iPhone pareado.
/// O fluxo standalone antigo (setup/categorias/geração) fica dormente.
struct ContentView: View {
    var body: some View {
        ComplementCaptureView()
    }
}

#Preview {
    ComplementCaptureView()
}
