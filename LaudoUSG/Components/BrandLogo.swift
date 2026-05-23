import SwiftUI

struct BrandLogo: View {
    enum Size {
        case small, medium, large

        var fontSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 26
            case .large: return 36
            }
        }

        var dotSize: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }
    }

    var size: Size = .medium

    var body: some View {
        HStack(spacing: 0) {
            // Espelha o wordmark do web (laudousg.com): "Laudo" em peso black (900) e
            // "USG" em peso regular (400) — ambos SF Pro design .default pra casar com
            // o Inter Black usado lá. Antes ambos estavam em extraBold (heavy/800).
            Text("Laudo")
                .font(.system(size: size.fontSize, weight: .black, design: .default))
                .foregroundStyle(BrandColor.primaryDeep)
            Text("USG")
                .font(.system(size: size.fontSize, weight: .regular, design: .default))
                .foregroundStyle(BrandColor.primary)
            Circle()
                .fill(BrandColor.primary)
                .frame(width: size.dotSize, height: size.dotSize)
                .offset(y: size.fontSize * 0.25)
                .padding(.leading, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LaudoUSG")
    }
}

#Preview {
    VStack(spacing: 24) {
        BrandLogo(size: .small)
        BrandLogo(size: .medium)
        BrandLogo(size: .large)
    }
    .padding()
    .background(AppSurface.background)
}
