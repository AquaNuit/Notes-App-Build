import CoreGraphics
import Foundation
import simd

// MARK: - CGPoint Extensions

public extension CGPoint {

    /// Calculate distance to another point
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Calculate squared distance (faster when only comparison is needed)
    func distanceSquared(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = point.y - y
        return dx * dx + dy * dy
    }

    /// Linear interpolation between two points
    func lerp(to point: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (point.x - x) * t,
            y: y + (point.y - y) * t
        )
    }

    /// The length of this point as a vector from origin
    var length: CGFloat {
        sqrt(x * x + y * y)
    }

    /// Normalized unit vector
    var normalized: CGPoint {
        let len = length
        guard len > 0 else { return .zero }
        return CGPoint(x: x / len, y: y / len)
    }

    /// Dot product with another point
    func dot(_ point: CGPoint) -> CGFloat {
        x * point.x + y * point.y
    }

    /// Cross product (2D z-component) with another point
    func cross(_ point: CGPoint) -> CGFloat {
        x * point.y - y * point.x
    }

    /// Rotate by an angle (radians)
    func rotated(by angle: CGFloat) -> CGPoint {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        return CGPoint(
            x: x * cosAngle - y * sinAngle,
            y: x * sinAngle + y * cosAngle
        )
    }

    /// Midpoint between two points
    static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Convert to simd float2 for Metal
    var simdFloat2: simd_float2 {
        simd_float2(Float(x), Float(y))
    }

    /// Clamp point inside a rect
    func clamped(to rect: CGRect) -> CGPoint {
        CGPoint(
            x: x.clamped(to: rect.minX...rect.maxX),
            y: y.clamped(to: rect.minY...rect.maxY)
        )
    }
}

// MARK: - CGFloat Extensions

public extension CGFloat {
    /// Clamp a value to a closed range
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// Linear interpolation
    func lerp(to value: CGFloat, t: CGFloat) -> CGFloat {
        self + (value - self) * t
    }

    /// Map from one range to another
    func map(from source: ClosedRange<CGFloat>, to target: ClosedRange<CGFloat>) -> CGFloat {
        let ratio = (self - source.lowerBound) / (source.upperBound - source.lowerBound)
        return target.lowerBound + ratio * (target.upperBound - target.lowerBound)
    }
}

// MARK: - BinaryInteger Extensions

public extension BinaryInteger {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
