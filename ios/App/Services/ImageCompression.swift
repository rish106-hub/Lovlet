import UIKit

enum ImageCompression {
    static func compressedJPEGData(_ image: UIImage, maxBytes: Int = 1_000_000) -> Data? {
        var quality: CGFloat = 0.8
        guard var data = image.jpegData(compressionQuality: quality) else { return nil }

        while data.count > maxBytes, quality > 0.2 {
            quality -= 0.1
            guard let next = image.jpegData(compressionQuality: quality) else { break }
            data = next
        }
        return data
    }
}
