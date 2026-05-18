#if canImport(UIKit)
import UIKit

extension UIImage {
    func compressedForUpload(maxSize: Int = 2_500_000) -> Data? {
        for maxDimension in [CGFloat(2048), CGFloat(1600), CGFloat(1280), CGFloat(1024)] {
            let image = resizedForUpload(maxDimension: maxDimension)
            var quality: CGFloat = 0.7
            var attempts = 0

            while quality >= 0.2, attempts < 6 {
                if let data = image.jpegData(compressionQuality: quality), data.count <= maxSize {
                    return data
                }
                quality -= 0.1
                attempts += 1
            }
        }

        return resizedForUpload(maxDimension: 1024).jpegData(compressionQuality: 0.2)
    }

    private func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif
