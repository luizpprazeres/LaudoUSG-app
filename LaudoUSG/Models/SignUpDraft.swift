import Foundation

struct SignUpDraft: Equatable {
    var name: String = ""
    var crm: String = ""
    var uf: String = ""
    var email: String = ""
    var password: String = ""
    var passwordConfirm: String = ""
    var termsAccepted: Bool = false

    var nameValid: Bool { name.trimmingCharacters(in: .whitespaces).count >= 3 }
    var crmValid: Bool {
        let t = crm.trimmingCharacters(in: .whitespaces)
        return t.count >= 3 && t.allSatisfy { $0.isNumber }
    }
    var ufValid: Bool { uf.count == 2 && uf.allSatisfy { $0.isLetter } }
    var emailValid: Bool {
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
    var passwordValid: Bool {
        password.count >= 8 &&
        password.rangeOfCharacter(from: .letters) != nil &&
        password.rangeOfCharacter(from: .decimalDigits) != nil
    }
    var passwordsMatch: Bool { !password.isEmpty && password == passwordConfirm }
    var isValid: Bool {
        nameValid && crmValid && ufValid && emailValid && passwordValid && passwordsMatch && termsAccepted
    }
}
