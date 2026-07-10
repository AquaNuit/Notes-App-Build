import UIKit

public extension UIImage {

    /// Resize image to a target size
    func resized(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Resize image to fit within a maximum dimension, maintaining aspect ratio
    func resizedToFit(maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        guard scale < 1 else { return self }
        return resized(to: CGSize(width: size.width * scale, height: size.height * scale))
    }

    /// Compress image to a target file size
    func compressed(maxFileSizeKB: Int) -> Data? {
        let maxBytes = maxFileSizeKB * 1024
        var compression: CGFloat = 1.0
        var imageData = jpegData(compressionQuality: compression)

        while imageData?.count ?? 0 > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = jpegData(compressionQuality: compression)
        }

        return imageData
    }

    /// Apply a color tint to the image
    func tinted(with color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(at: .zero, blendMode: .destinationIn, alpha: 1)
        }
    }

    /// Create a thumbnail with the given size
    func thumbnail(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
