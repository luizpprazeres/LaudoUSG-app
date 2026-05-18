import SwiftUI

struct MedicalDisclaimerView: View {
    var body: some View {
        MarkdownDocumentView(title: "Disclaimer Médico", resourceName: "medical-disclaimer")
    }
}

#Preview {
    NavigationStack {
        MedicalDisclaimerView()
    }
    .environment(AppState())
}
