import Metal
import CoreGraphics
import Foundation

// MARK: - StrokeVertexGenerator

/// Converts stroke point data into triangle strip vertices for Metal rendering.
///
/// For each point on the stroke, this generates two vertices offset perpendicular
/// to the stroke direction by half the stroke width. This creates the thick,
/// variable-width line that forms the visible ink.
///
/// The approach:
/// 1. Interpolate points with Catmull-Rom spline for smoothness
/// 2. Apply pressure → width mapping
/// 3. Generate left and right edge vertices along the path
/// 4. Handle joins (miters) between segments
/// 5. Output to MTLBuffer for rendering
public class StrokeVertexGenerator {

    // MARK: - Configuration

    /// Number of subdivisions per Bézier segment (higher = smoother, more vertices)
    public var segmentsPerCurve: Int = 8

    /// Minimum vertex distance before merging adjacent vertices
    public var minimumVertexDistance: CGFloat = 0.5

    // MARK: - Vertex Generation

    /// Generate triangle strip vertices for a stroke.
    /// - Parameters:
    ///   - stroke: The stroke to generate vertices for
    ///   - zoomScale: Current zoom scale (affects visible width)
    /// - Returns: Array of InkVertex values for Metal rendering
    public func generateVertices(for stroke: Stroke, zoomScale: CGFloat = 1.0) -> [InkVertex] {
        guard stroke.pointCount >= 2 else { return [] }

        let points = stroke.points
        let locations = points.map { $0.location }
        let rawWidths = points.map { widthForPoint($0, baseWidth: stroke.width, zoomScale: zoomScale) }

        // Generate interpolated path with widths
        let path = BezierPathBuilder.generateWidthPath(
            from: locations,
            widths: rawWidths,
            segmentsPerPoint: segmentsPerCurve
        )

        guard path.count >= 2 else { return [] }

        // Generate triangle strip vertices
        return generateTriangleStrip(from: path, stroke: stroke)
    }

    // MARK: - Width Calculation

    /// Calculate the rendered width at a given point based on pressure and tool type.
    private func widthForPoint(_ point: InkPoint, baseWidth: CGFloat, zoomScale: CGFloat) -> CGFloat {
        let pressureFactor: CGFloat

        switch point.pressure {
        case 0..<0.1:
            pressureFactor = 0.5 // Minimum width even with light touch
        case 0.1..<1.0:
            // Non-linear response for natural feel
            pressureFactor = 0.5 + 0.5 * pow(point.pressure, 0.7)
        default:
            pressureFactor = 1.0
        }

        // Apply velocity thinning: faster strokes are thinner
        let velocityFactor: CGFloat = {
            let speed = point.velocity
            if speed < 100 { return 1.0 }
            if speed < 500 { return 1.0 - (speed - 100) / 400 * 0.3 }
            return 0.7
        }()

        // Apply tilt flattening: more tilted = wider stroke
        let tiltFactor: CGFloat = {
            let altitude = point.altitude
            if altitude > .pi / 4 { return 1.0 } // Upright
            let factor = 1.0 + (1.0 - altitude / (.pi / 4)) * 0.5
            return min(1.5, factor)
        }()

        return baseWidth * pressureFactor * velocityFactor * tiltFactor / zoomScale
    }

    // MARK: - Triangle Strip Generation

    private func generateTriangleStrip(
        from path: [(position: CGPoint, width: CGFloat)],
        stroke: Stroke
    ) -> [InkVertex] {
        guard path.count >= 2 else { return [] }

        var vertices: [InkVertex] = []
        vertices.reserveCapacity(path.count * 2)

        for i in 0..<path.count {
            let current = path[i]

            // Calculate direction (perpendicular to stroke path)
            let direction: CGPoint
            if i == 0 {
                // First point: use direction to next point
                direction = directionBetween(path[0].position, path[1].position)
            } else if i == path.count - 1 {
                // Last point: use direction from previous point
                direction = directionBetween(path[i - 1].position, path[i].position)
            } else {
                // Middle point: average of incoming and outgoing directions
                let inDir = directionBetween(path[i - 1].position, path[i].position)
                let outDir = directionBetween(path[i].position, path[i + 1].position)
                direction = CGPoint(
                    x: (inDir.x + outDir.x) / 2,
                    y: (inDir.y + outDir.y) / 2
                ).normalized
            }

            // Perpendicular vector (rotate 90°)
            let halfWidth = current.width / 2
            let perpendicular = CGPoint(x: -direction.y, y: direction.x)

            // Left vertex
            let leftPos = CGPoint(
                x: current.position.x + perpendicular.x * halfWidth,
                y: current.position.y + perpendicular.y * halfWidth
            )

            // Right vertex
            let rightPos = CGPoint(
                x: current.position.x - perpendicular.x * halfWidth,
                y: current.position.y - perpendicular.y * halfWidth
            )

            // Apply stroke transform (if any)
            let transformedLeft = leftPos.applying(stroke.transform)
            let transformedRight = rightPos.applying(stroke.transform)

            // Create vertices with texture coordinates
            let texV = Float(i) / Float(max(path.count - 1, 1))

            let leftVertex = InkVertex(
                position: transformedLeft.simdFloat2,
                textureCoordinate: simd_float2(0, texV),
                alpha: 1.0,
                width: Float(current.width)
            )

            let rightVertex = InkVertex(
                position: transformedRight.simdFloat2,
                textureCoordinate: simd_float2(1, texV),
                alpha: 1.0,
                width: Float(current.width)
            )

            // Triangle strip alternates left/right
            vertices.append(leftVertex)
            vertices.append(rightVertex)
        }

        return vertices
    }

    // MARK: - Direction Helpers

    private func directionBetween(_ from: CGPoint, _ to: CGPoint) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return CGPoint(x: 1, y: 0) }
        return CGPoint(x: dx / len, y: dy / len)
    }
}
