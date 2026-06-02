import SwiftUI

struct SetupSalaView: View {
    @Environment(WatchAppState.self) private var app
    @State private var email = ""
    @State private var password = ""
    @State private var pairingCode = ""

    var body: some View {
        ScrollView {
            VStack(spacing: WatchTheme.s3) {
                Text("L")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.brand)

                Text("LaudoUSG")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(WatchTheme.textPrimary)

                Text("WATCH · SETUP")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(WatchTheme.textMuted)

                Spacer().frame(height: WatchTheme.s3)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)

                SecureField("Senha", text: $password)
                    .textContentType(.password)

                TextField("Código da Sala", text: $pairingCode)
                    .textInputAutocapitalization(.characters)
                    .font(.system(.body, design: .monospaced))

                if let error = app.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.danger)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await app.configure(
                            email: email,
                            password: password,
                            pairingCode: pairingCode
                        )
                    }
                } label: {
                    Text(app.isBusy ? "Validando…" : "Entrar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchTheme.brand)
                .disabled(app.isBusy || email.isEmpty || password.isEmpty || pairingCode.count < 6)
            }
            .padding(.horizontal, WatchTheme.s1)
        }
    }
}

#Preview {
    SetupSalaView()
        .environment(WatchAppState())
}
