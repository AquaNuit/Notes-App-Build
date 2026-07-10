import CoreGraphics
import Foundation

// MARK: - BezierPathBuilder

/// Builds smooth Cubic Bézier curves from stroke point data using Catmull-Rom splines.
///
/// Catmull-Rom splines pass through all control points (unlike Bézier curves which
/// only approximate them), making them ideal for handwriting where every point matters.
/// We convert Catmull-Rom segments to Cubic Bézier form for Metal rendering.
public enum BezierPathBuilder {

    /// Generate cubic Bézier curves from stroke points.
    /// - Parameter points: The stroke points to interpolate
    /// - Parameter alpha: Catmull-Rom alpha parameter (0.5 = centripetal, recommended for smooth curves)
    /// - Returns: Array of cubic Bézier segments (each segment has 4 control points: start, c1, c2, end)
    public static func buildCubicBezierSegments(
        from points: [CGPoint],
        alpha: CGFloat = 0.5
    ) -> [CubicBezierSegment] {
        guard points.count >= 2 else { return [] }
        guard points.count > 2 else {
            // Just a line between two points
            return [CubicBezierSegment(
                start: points[0],
                control1: points[0],
                control2: points[1],
                end: points[1]
            )]
        }

        var segments: [CubicBezierSegment] = []

        // For centripetal Catmull-Rom, we need the tension parameter
        // Each segment requires 4 points: p0, p1, p2, p3
        // We generate segments from p1 to p2 using p0 and p3 as tangents

        for i in 1..<points.count - 1 {
            let p0 = points[safe: i - 1] ?? points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[safe: i + 2] ?? points[i + 1]

            let segment = catmullRomToCubicBezier(
                p0: p0, p1: p1, p2: p2, p3: p3,
                alpha: alpha
            )
            segments.append(segment)
        }

        return segments
    }

    /// Convert a Catmull-Rom segment (p1→p2 with tangents from p0,p3) to Cubic Bézier form
    private static func catmullRomToCubicBezier(
        p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint,
        alpha: CGFloat
    ) -> CubicBezierSegment {
        // Calculate knot distances (t values) for centripetal Catmull-Rom
        let t0: CGFloat = 0
        let t1 = t0 + pow(p1.distance(to: p0), alpha)
        let t2 = t1 + pow(p2.distance(to: p1), alpha)
        let t3 = t2 + pow(p3.distance(to: p2), alpha)

        // Tangent at p1
        let t1Sq = t1 * t1
        let t2Sq = t2 * t2
        let t0Sq = t0 * t0

        // Using the standard Catmull-Rom formula:
        // m1 = (1 - tension) * (t2 - t1) * ((p1 - p0)/(t1 - t0) - (p2 - p0)/(t2 - t0) + (p2 - p1)/(t2 - t1))
        // Simplified for centripetal:
        let tension: CGFloat = 1.0 // Full tension (standard)

        let tangent1 = CGPoint(
            x: (p2.x - p0.x) / (t2 - t0),
            y: (p2.y - p0.y) / (t2 - t0)
        )

        let tangent2 = CGPoint(
            x: (p3.x - p1.x) / (t3 - t1),
            y: (p3.y - p1.y) / (t3 - t1)
        )

        // Scale tangents by tension and segment length
        let segmentLength = t2 - t1
        let m1 = CGPoint(
            x: tangent1.x * segmentLength * tension,
            y: tangent1.y * segmentLength * tension
        )
        let m2 = CGPoint(
            x: tangent2.x * segmentLength * tension,
            y: tangent2.y * segmentLength * tension
        )

        // Convert to Cubic Bézier control points
        let control1 = CGPoint(x: p1.x + m1.x / 3, y: p1.y + m1.y / 3)
        let control2 = CGPoint(x: p2.x - m2.x / 3, y: p2.y - m2.y / 3)

        return CubicBezierSegment(
            start: p1,
            control1: control1,
            control2: control2,
            end: p2
        )
    }

    /// Generate a smooth path suitable for rendering as a triangle strip.
    /// Each output point includes position and the interpolated pressure/width.
    /// - Returns: Array of (position, width) pairs for vertex generation
    public static func generateWidthPath(
        from points: [CGPoint],
        widths: [CGFloat],
        segmentsPerPoint: Int = 4
    ) -> [(position: CGPoint, width: CGFloat)] {
        guard points.count >= 2 else { return [] }
        guard points.count == widths.count else {
            return points.map { (position: $0, width: widths.first ?? 1.0) }
        }

        var result: [(position: CGPoint, width: CGFloat)] = []

        // Interpolate points along the Catmull-Rom spline and sample widths
        let bezierSegments = buildCubicBezierSegments(from: points)

        for (index, segment) in bezierSegments.enumerated() {
            let startWidth = widths[index + 1]
            let endWidth = widths[safe: index + 2] ?? widths[index + 1]

            for i in 0..<segmentsPerPoint {
                let t = CGFloat(i) / CGFloat(segmentsPerPoint)
                let point = evaluateCubicBezier(segment: segment, t: t)
                let width = startWidth + (endWidth - startWidth) * t
                result.append((position: point, width: width))
            }
        }

        // Add the final point
        if let lastSegment = bezierSegments.last {
            let lastPoint = lastSegment.end
            let lastWidth = widths.last ?? 1.0
            result.append((position: lastPoint, width: lastWidth))
        }

        return result
    }

    /// Evaluate a cubic Bézier segment at parameter t (0..1)
    public static func evaluateCubicBezier(segment: CubicBezierSegment, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt

        let x = mt3 * segment.start.x + 3 * mt2 * t * segment.control1.x
              + 3 * mt * t2 * segment.control2.x + t3 * segment.end.x
        let y = mt3 * segment.start.y + 3 * mt2 * t * segment.control1.y
              + 3 * mt * t2 * segment.control2.y + t3 * segment.end.y

        return CGPoint(x: x, y: y)
    }
}

// MARK: - CubicBezierSegment

/// A single cubic Bézier curve segment defined by 4 control points.
public struct CubicBezierSegment: Equatable, Sendable {
    public var start: CGPoint
    public var control1: CGPoint
    public var control2: CGPoint
    public var end: CGPoint

    public init(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }

    /// The bounding box of this Bézier segment
    public var bounds: CGRect {
        let minX = min(start.x, control1.x, control2.x, end.x)
        let minY = min(start.y, control1.y, control2.y, end.y)
        let maxX = max(start.x, control1.x, control2.x, end.x)
        let maxY = max(start.y, control1.y, control2.y, end.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Approximate length by subdividing into small line segments
    public func approximateLength(subdivisions: Int = 10) -> CGFloat {
        var total: CGFloat = 0
        var previous = start
        for i in 1...subdivisions {
            let t = CGFloat(i) / CGFloat(subdivisions)
            let current = BezierPathBuilder.evaluateCubicBezier(segment: self, t: t)
            total += current.distance(to: previous)
            previous = current
        }
        return total
    }
}

// MARK: - Collection Safe Indexing

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
