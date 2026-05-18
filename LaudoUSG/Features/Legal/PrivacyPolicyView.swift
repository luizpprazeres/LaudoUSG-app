import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        MarkdownDocumentView(title: "Política de Privacidade", resourceName: "privacy-policy")
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
    .environment(AppState())
}
