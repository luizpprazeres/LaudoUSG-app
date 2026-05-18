import SwiftUI

struct TermsOfUseView: View {
    var body: some View {
        MarkdownDocumentView(title: "Termos de Uso", resourceName: "terms-of-use")
    }
}

#Preview {
    NavigationStack {
        TermsOfUseView()
    }
    .environment(AppState())
}
