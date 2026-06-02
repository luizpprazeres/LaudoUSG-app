import SwiftUI

struct CategoryListView: View {
    @Environment(WatchAppState.self) private var app
    @State private var isResetConfirmationPresented = false

    var body: some View {
        List {
            Section("Novo laudo") {
                ForEach(CategoryWatch.allCases) { category in
                    Button {
                        app.select(category)
                    } label: {
                        CategoryRow(category: category)
                    }
                }
            }
            Button("Redefinir acesso", role: .destructive) {
                isResetConfirmationPresented = true
            }
            .font(.caption)
        }
        .confirmationDialog(
            "Redefinir acesso?",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Redefinir", role: .destructive) {
                Task { await app.resetSetup() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Você precisará configurar novamente.")
        }
    }
}

#Preview {
    CategoryListView()
        .environment(WatchAppState())
}
