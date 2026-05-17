import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let r, g, b, a: Double
        switch trimmed.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static func dynamic(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #else
        return light
        #endif
    }
}

enum BrandColor {
    static let primary = Color(hex: "059669")
    static let primaryHover = Color(hex: "047857")
    static let primaryDeep = Color(hex: "065F46")
    static let primarySoft = Color(hex: "D1FAE5")
    static let primaryBorder = Color(hex: "A7F3D0")
    static let primaryTint = Color(hex: "ECFDF5")

    static let wordmark = Color(hex: "18533F")
    static let wordmarkAccent = Color(hex: "4A8A6A")
    static let wordmarkDark = Color(hex: "6EE7B7")
}

enum NeutralColor {
    static let gray50 = Color(hex: "F9FAFB")
    static let gray100 = Color(hex: "F3F4F6")
    static let gray200 = Color(hex: "E5E7EB")
    static let gray300 = Color(hex: "D1D5DB")
    static let gray400 = Color(hex: "9CA3AF")
    static let gray500 = Color(hex: "6B7280")
    static let gray600 = Color(hex: "4B5563")
    static let gray700 = Color(hex: "374151")
    static let gray800 = Color(hex: "1F2937")
    static let gray900 = Color(hex: "111827")
}

enum SemanticColor {
    static let errorBg = Color(hex: "FEF2F2")
    static let errorBorder = Color(hex: "FECACA")
    static let errorText = Color(hex: "B91C1C")
    static let errorAccent = Color(hex: "FF3B30")

    static let warningBg = Color(hex: "FFFBEB")
    static let warningBorder = Color(hex: "FDE68A")
    static let warningText = Color(hex: "B45309")

    static let successBg = Color(hex: "F0FDF4")
    static let successBorder = Color(hex: "BBF7D0")
    static let successText = Color(hex: "15803D")

    static let info = Color(hex: "2563EB")
}

enum AppSurface {
    static let background = Color.dynamic(
        light: Color(hex: "F2F2F7"),
        dark: Color(hex: "0B0B0F")
    )
    static let card = Color.dynamic(
        light: .white,
        dark: Color(hex: "1C1C1E")
    )
    static let muted = Color.dynamic(
        light: NeutralColor.gray50,
        dark: Color(hex: "131316")
    )
    static let border = Color.dynamic(
        light: NeutralColor.gray200,
        dark: Color(hex: "2C2C2E")
    )
    static let textPrimary = Color.dynamic(
        light: NeutralColor.gray900,
        dark: .white
    )
    static let textSecondary = Color.dynamic(
        light: NeutralColor.gray600,
        dark: Color(hex: "8E8E93")
    )
    static let textMuted = Color.dynamic(
        light: NeutralColor.gray400,
        dark: Color(hex: "636366")
    )
    static let wordmark = Color.dynamic(
        light: BrandColor.wordmark,
        dark: BrandColor.wordmarkDark
    )
}
