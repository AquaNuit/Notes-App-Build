import CoreGraphics
import Foundation

public extension CGRect {

    /// Center point of the rectangle
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    /// Create a rect centered on a point with a given size
    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Inset the rect by a uniform amount
    func inset(by amount: CGFloat) -> CGRect {
        insetBy(dx: amount, dy: amount)
    }

    /// Expand the rect to include a point
    func union(with point: CGPoint) -> CGRect {
        union(CGRect(origin: point, size: .zero))
    }

    /// Aspect-fit this rect inside another rect
    func aspectFit(in container: CGRect) -> CGRect {
        let aspectRatio = width / height
        let containerAspect = container.width / container.height

        var fittedSize: CGSize
        if aspectRatio > containerAspect {
            fittedSize = CGSize(width: container.width, height: container.width / aspectRatio)
        } else {
            fittedSize = CGSize(width: container.height * aspectRatio, height: container.height)
        }

        return CGRect(
            x: container.midX - fittedSize.width / 2,
            y: container.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    /// Aspect-fill this rect to cover another rect
    func aspectFill(in container: CGRect) -> CGRect {
        let aspectRatio = width / height
        let containerAspect = container.width / container.height

        var filledSize: CGSize
        if aspectRatio > containerAspect {
            filledSize = CGSize(width: container.height * aspectRatio, height: container.height)
        } else {
            filledSize = CGSize(width: container.width, height: container.width / aspectRatio)
        }

        return CGRect(
            x: container.midX - filledSize.width / 2,
            y: container.midY - filledSize.height / 2,
            width: filledSize.width,
            height: filledSize.height
        )
    }

    /// Integer-rounded rect (useful for pixel alignment)
    var integral: CGRect {
        CGRect(
            x: floor(origin.x),
            y: floor(origin.y),
            width: ceil(size.width),
            height: ceil(size.height)
        )
    }

    /// Scale the rect by a factor around its center
    func scaled(by factor: CGFloat) -> CGRect {
        let newSize = CGSize(width: width * factor, height: height * factor)
        return CGRect(
            x: midX - newSize.width / 2,
            y: midY - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
    }
}

public extension CGSize {
    /// Scale a size by a uniform factor
    func scaled(by factor: CGFloat) -> CGSize {
        CGSize(width: width * factor, height: height * factor)
    }

    /// Aspect ratio (width / height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1 }
        return width / height
    }
}
