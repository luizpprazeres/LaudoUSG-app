import SwiftUI

struct PasswordStrengthBar: View {
    let password: String

    private var score: Int {
        guard !password.isEmpty else { return 0 }
        var s = 0
        let chars = password.count
        let hasLetter = password.contains { $0.isLetter }
        let hasNumber = password.contains { $0.isNumber }
        let hasSpecial = password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
        let hasUpper = password.contains { $0.isUppercase }
        if chars >= 8 { s += 1 }
        if chars >= 8 && hasLetter && hasNumber { s += 1 }
        if chars >= 10 && hasLetter && hasNumber && hasSpecial { s += 1 }
        if chars >= 12 && hasLetter && hasNumber && hasSpecial && hasUpper { s += 1 }
        return s
    }

    private var fillColor: Color {
        switch score {
        case 0...1: return SemanticColor.errorText
        case 2: return SemanticColor.warningText
        default: return BrandColor.primary
        }
    }

    private var label: String {
        guard !password.isEmpty else { return "" }
        switch score {
        case 0...1: return "Fraca"
        case 2: return "Boa"
        default: return "Forte"
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i < score ? fillColor : AppSurface.border)
                        .frame(height: 4)
                }
            }
            if !label.isEmpty {
                Text(label)
                    .font(TextStyle.caption)
                    .foregroundStyle(AppSurface.textSecondary)
            }
        }
        .animation(.easeOut(duration: 0.2), value: score)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        PasswordStrengthBar(password: "")
        PasswordStrengthBar(password: "abc")
        PasswordStrengthBar(password: "abcdefgh")
        PasswordStrengthBar(password: "abc12345")
        PasswordStrengthBar(password: "abc12345!")
        PasswordStrengthBar(password: "Abc12345!XYZ")
    }
    .padding(24)
    .background(AppSurface.background)
}
