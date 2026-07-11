import CoreGraphics
import Foundation

// MARK: - ShapeClassification

/// The type of shape a stroke has been classified as.
public indirect enum ShapeClassification: Equatable, Sendable {
    case line
    case circle
    case ellipse
    case rectangle
    case triangle
    case pentagon
    case star
    case arrow
    case unknown
    case partial(shape: ShapeClassification, confidence: Float)
}

// MARK: - ShapeRecognizer

/// Classifies strokes into geometric shapes based on their point distribution.
///
/// This uses geometric heuristics rather than ML for fast, on-device classification.
/// Future versions can replace or augment this with a Core ML model for higher accuracy.
public class ShapeRecognizer {

    public init() {}

    /// Classify a stroke into a shape type.
    /// - Parameter stroke: The stroke to classify
    /// - Returns: The classified shape with confidence level
    public func classify(_ stroke: Stroke) -> (shape: ShapeClassification, confidence: Float) {
        guard stroke.pointCount >= 3 else {
            return (.unknown, 0)
        }

        let points = stroke.points.map { $0.location }

        // First check if it's likely a shape (closed-ish stroke)
        let isClosed = isProbablyClosed(points, threshold: 0.15)
        let aspectRatio = boundingBoxAspectRatio(points)

        if isClosed {
            if aspectRatio > 0.85 && aspectRatio < 1.15 {
                // Could be circle or square
                if isCircular(points) {
                    return (.circle, 0.8)
                }
                return (.rectangle, 0.7)
            }

            if aspectRatio > 0.5 {
                if isCircular(points) {
                    return (.ellipse, 0.7)
                }
                if isRectangular(points) {
                    return (.rectangle, 0.8)
                }
                if isTriangular(points) {
                    return (.triangle, 0.7)
                }
            }

            // Check for pentagram shapes
            if isStarShaped(points) {
                return (.star, 0.6)
            }
        } else {
            // Open strokes
            if isStraightLine(points) {
                return (.line, 0.9)
            }
            if isArrow(points) {
                return (.arrow, 0.7)
            }
        }

        return (.unknown, 0)
    }

    /// Whether the stroke can be beautified into a perfect shape
    public func canBeautify(_ stroke: Stroke) -> Bool {
        let (shape, confidence) = classify(stroke)
        return shape != .unknown && confidence > 0.5
    }

    /// Generate a perfect shape from a classified stroke
    public func beautify(_ stroke: Stroke) -> Stroke? {
        let (shape, confidence) = classify(stroke)
        guard confidence > 0.3 else { return nil }

        let points = stroke.points.map { $0.location }

        var perfectPoints: [CGPoint] = []

        switch shape {
        case .line:
            guard let first = points.first, let last = points.last else { return nil }
            perfectPoints = [first, last]

        case .circle:
            let center = centroid(of: points)
            let radius = averageRadius(from: center, points: points)
            perfectPoints = generateCirclePoints(center: center, radius: radius, segments: 32)

        case .ellipse:
            let center = centroid(of: points)
            let (majorAxis, minorAxis, angle) = ellipseAxes(points)
            perfectPoints = generateEllipsePoints(
                center: center, majorAxis: majorAxis, minorAxis: minorAxis,
                angle: angle, segments: 32
            )

        case .rectangle:
            let rect = boundingBox(points)
            perfectPoints = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY),
                rect.origin
            ]

        case .triangle:
            // Find the 3 corners
            let corners = findCorners(points, count: 3)
            guard corners.count >= 3 else { return nil }
            perfectPoints = corners + [corners[0]]

        default:
            return nil
        }

        guard !perfectPoints.isEmpty else { return nil }

        // Create a new stroke with interpolated points matching the perfect shape
        let inkPoints = perfectPoints.enumerated().map { index, point in
            InkPoint(
                location: point,
                pressure: 1.0,
                azimuth: 0,
                altitude: .pi / 2,
                velocity: 0,
                timestamp: stroke.points.first?.timestamp ?? 0
            )
        }

        return Stroke(
            id: stroke.id,
            points: inkPoints,
            toolType: stroke.toolType,
            color: stroke.color,
            width: stroke.width,
            creationDate: stroke.creationDate,
            isVisible: stroke.isVisible
        )
    }

    // MARK: - Geometric Tests

    private func isProbablyClosed(_ points: [CGPoint], threshold: CGFloat) -> Bool {
        guard points.count >= 3 else { return false }
        guard let first = points.first, let last = points.last else { return false }

        let distance = first.distance(to: last)
        let totalLength = pathLength(points)
        guard totalLength > 0 else { return false }

        return distance / totalLength < threshold
    }

    private func boundingBoxAspectRatio(_ points: [CGPoint]) -> CGFloat {
        let rect = boundingBox(points)
        guard rect.width > 0, rect.height > 0 else { return 1 }
        return min(rect.width, rect.height) / max(rect.width, rect.height)
    }

    private func isCircular(_ points: [CGPoint]) -> Bool {
        let center = centroid(of: points)
        let meanRadius = averageRadius(from: center, points: points)
        guard meanRadius > 0 else { return false }

        // Check variance in radius
        var variance: CGFloat = 0
        for point in points {
            let r = point.distance(to: center)
            variance += (r - meanRadius) * (r - meanRadius)
        }
        variance /= CGFloat(points.count)
        let stdDev = sqrt(variance)

        // For a good circle, standard deviation should be < 15% of mean radius
        return stdDev / meanRadius < 0.15
    }

    private func isRectangular(_ points: [CGPoint]) -> Bool {
        let rect = boundingBox(points)
        let cornerThreshold: CGFloat = rect.width * 0.1

        // Check if most points are near the rectangle edges
        var onEdge = 0
        for point in points {
            let onLeft = abs(point.x - rect.minX) < cornerThreshold
            let onRight = abs(point.x - rect.maxX) < cornerThreshold
            let onTop = abs(point.y - rect.minY) < cornerThreshold
            let onBottom = abs(point.y - rect.maxY) < cornerThreshold

            if (onLeft || onRight) && (point.y >= rect.minY && point.y <= rect.maxY) {
                onEdge += 1
            } else if (onTop || onBottom) && (point.x >= rect.minX && point.x <= rect.maxX) {
                onEdge += 1
            }
        }

        return CGFloat(onEdge) / CGFloat(points.count) > 0.7
    }

    private func isTriangular(_ points: [CGPoint]) -> Bool {
        let corners = findCorners(points, count: 3)
        return corners.count >= 3
    }

    private func isStraightLine(_ points: [CGPoint]) -> Bool {
        guard points.count >= 2 else { return false }

        let first = points.first!
        let last = points.last!

        // Calculate average distance from the ideal line
        var totalDeviation: CGFloat = 0
        for point in points {
            totalDeviation += perpendicularDistance(from: point, to: first, lineEnd: last)
        }
        let avgDeviation = totalDeviation / CGFloat(points.count)
        let lineLength = first.distance(to: last)

        guard lineLength > 0 else { return false }
        return avgDeviation / lineLength < 0.03
    }

    private func isArrow(_ points: [CGPoint]) -> Bool {
        guard points.count >= 5 else { return false }
        // Basic heuristic: a line that ends with a V-shaped divergence
        // For a production implementation, this would be more sophisticated
        return false // Deferred to ML-based approach
    }

    private func isStarShaped(_ points: [CGPoint]) -> Bool {
        // Check for 5-pointed star pattern based on convex hull analysis
        let corners = findCorners(points, count: 10)
        // A star has alternating inner and outer points
        return corners.count >= 10
    }

    // MARK: - Geometric Helpers

    private func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    private func averageRadius(from center: CGPoint, points: [CGPoint]) -> CGFloat {
        guard !points.isEmpty else { return 0 }
        var total: CGFloat = 0
        for point in points {
            total += point.distance(to: center)
        }
        return total / CGFloat(points.count)
    }

    private func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<points.count {
            total += points[i].distance(to: points[i - 1])
        }
        return total
    }

    private func ellipseAxes(_ points: [CGPoint]) -> (majorAxis: CGFloat, minorAxis: CGFloat, angle: CGFloat) {
        let center = centroid(of: points)

        // Compute covariance matrix
        var xx: CGFloat = 0
        var xy: CGFloat = 0
        var yy: CGFloat = 0

        for point in points {
            let dx = point.x - center.x
            let dy = point.y - center.y
            xx += dx * dx
            xy += dx * dy
            yy += dy * dy
        }

        let n = CGFloat(points.count)
        xx /= n
        xy /= n
        yy /= n

        // Eigenvalue decomposition of 2x2 covariance matrix
        let theta = 0.5 * atan2(2 * xy, xx - yy)
        let cosT = cos(theta)
        let sinT = sin(theta)

        let majorAxis = 2 * sqrt(max(0, xx * cosT * cosT + 2 * xy * cosT * sinT + yy * sinT * sinT))
        let minorAxis = 2 * sqrt(max(0, xx * sinT * sinT - 2 * xy * cosT * sinT + yy * cosT * cosT))

        return (majorAxis, minorAxis, theta)
    }

    private func findCorners(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= count * 2 else { return [] }

        // Segment the path into equal-length sections and find corner candidates
        let segmentLength = points.count / count
        var corners: [CGPoint] = []

        for i in 0..<count {
            let index = min(i * segmentLength, points.count - 1)
            corners.append(points[index])
        }

        return corners
    }

    private func perpendicularDistance(from point: CGPoint, to lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSq = dx * dx + dy * dy

        if lengthSq == 0 { return point.distance(to: lineStart) }

        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSq
        let clampedT = max(0, min(1, t))
        let projection = CGPoint(x: lineStart.x + clampedT * dx, y: lineStart.y + clampedT * dy)

        return point.distance(to: projection)
    }

    // MARK: - Shape Generation

    private func generateCirclePoints(center: CGPoint, radius: CGFloat, segments: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 0..<segments {
            let angle = 2 * .pi * CGFloat(i) / CGFloat(segments)
            points.append(CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }
        points.append(points.first!)
        return points
    }

    private func generateEllipsePoints(
        center: CGPoint, majorAxis: CGFloat, minorAxis: CGFloat,
        angle: CGFloat, segments: Int
    ) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 0..<segments {
            let theta = 2 * .pi * CGFloat(i) / CGFloat(segments)
            let x = center.x + majorAxis * cos(theta) * cos(angle) - minorAxis * sin(theta) * sin(angle)
            let y = center.y + majorAxis * cos(theta) * sin(angle) + minorAxis * sin(theta) * cos(angle)
            points.append(CGPoint(x: x, y: y))
        }
        points.append(points.first!)
        return points
    }
}
