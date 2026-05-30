import SwiftUI

struct SymbolBreathingModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .symbolEffect(.pulse, options: .repeating, isActive: isActive)
    }
}

extension View {
    func symbolBreathing(isActive: Bool = true) -> some View {
        modifier(SymbolBreathingModifier(isActive: isActive))
    }
}

#Preview {
    Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 34))
        .foregroundStyle(BrandColor.primary)
        .symbolBreathing()
}
