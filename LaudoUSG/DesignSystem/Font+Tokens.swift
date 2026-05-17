import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum BrandFont {
    enum Body: String {
        case regular = "Inter-Regular"
        case medium = "Inter-Medium"
        case semibold = "Inter-SemiBold"
        case bold = "Inter-Bold"

        var systemWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }

    enum Display: String {
        case regular = "Barlow-Regular"
        case medium = "Barlow-Medium"
        case semibold = "Barlow-SemiBold"
        case bold = "Barlow-Bold"
        case extraBold = "Barlow-ExtraBold"

        var systemWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .extraBold: return .heavy
            }
        }
    }

    private static var registeredBodyFamily: String? {
        UIFont.fontNames(forFamilyName: "Inter").isEmpty ? nil : "Inter"
    }

    private static var registeredDisplayFamily: String? {
        UIFont.fontNames(forFamilyName: "Barlow").isEmpty ? nil : "Barlow"
    }

    static func body(_ style: Body, size: CGFloat) -> Font {
        if registeredBodyFamily != nil {
            return Font.custom(style.rawValue, size: size)
        }
        return Font.system(size: size, weight: style.systemWeight, design: .default)
    }

    static func display(_ style: Display, size: CGFloat) -> Font {
        if registeredDisplayFamily != nil {
            return Font.custom(style.rawValue, size: size)
        }
        return Font.system(size: size, weight: style.systemWeight, design: .rounded)
    }
}

enum TextStyle {
    static let caption = BrandFont.body(.regular, size: 12)
    static let captionMedium = BrandFont.body(.medium, size: 12)
    static let footnote = BrandFont.body(.regular, size: 13)
    static let body = BrandFont.body(.regular, size: 14)
    static let bodyMedium = BrandFont.body(.medium, size: 14)
    static let bodySemibold = BrandFont.body(.semibold, size: 14)
    static let bodyBold = BrandFont.body(.bold, size: 14)
    static let bodyLarge = BrandFont.body(.regular, size: 16)
    static let bodyLargeMedium = BrandFont.body(.medium, size: 16)
    static let bodyLargeSemibold = BrandFont.body(.semibold, size: 16)
    static let subtitle = BrandFont.body(.semibold, size: 18)

    static let h3 = BrandFont.display(.bold, size: 20)
    static let h2 = BrandFont.display(.bold, size: 24)
    static let h1 = BrandFont.display(.extraBold, size: 30)
    static let display = BrandFont.display(.extraBold, size: 36)
    static let hero = BrandFont.display(.extraBold, size: 48)
}
