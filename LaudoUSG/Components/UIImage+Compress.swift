import SwiftUI

#if canImport(UIKit)
import UIKit

extension UIImage {
    func compressedForUpload(maxSize: Int = 4 * 1024 * 1024) -> Data? {
        let maxDimension: CGFloat = 2048
        let longestSide = max(size.width, size.height)
        let resized: UIImage

        if longestSide > maxDimension {
            let scale = maxDimension / longestSide
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resized = renderer.image { _ in
                self.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            resized = self
        }

        var quality: CGFloat = 0.7
        var attempts = 0
        while quality > 0.2, attempts < 5 {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= maxSize {
                return data
            }
            quality -= 0.1
            attempts += 1
        }

        return resized.jpegData(compressionQuality: 0.2)
    }
}
#endif
