import SwiftUI

struct BrandShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let sm = BrandShadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    static let md = BrandShadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    static let lg = BrandShadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    static let xl = BrandShadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 8)
    static let cardHover = BrandShadow(color: BrandColor.primary.opacity(0.10), radius: 16, x: 0, y: 6)
}

extension View {
    func brandShadow(_ shadow: BrandShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
