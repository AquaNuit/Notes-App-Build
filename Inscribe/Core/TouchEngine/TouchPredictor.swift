import CoreGraphics
import Foundation

// MARK: - TouchPredictor

/// Generates predicted touch points to reduce perceived latency.
///
/// When the system provides predicted touches (via `event.predictedTouches(for:)`),
/// we use them directly. When they're not available or we want additional prediction,
/// this class uses a velocity-based extrapolation with dampening.
public class TouchPredictor {

    /// Number of points to predict ahead
    public var predictionCount: Int = 3

    /// How far ahead to predict (in fractions of recent velocity)
    public var predictionFactor: CGFloat = 0.5

    /// Minimum velocity before prediction kicks in (pts/s)
    public var minimumVelocity: CGFloat = 50

    /// The maximum distance a predicted point can be from the last real point
    public var maximumPredictionDistance: CGFloat = 200

    private var recentPoints: [InkPoint] = []

    // MARK: - Configuration

    /// Reset the predictor state (call between strokes)
    public func reset() {
        recentPoints.removeAll()
    }

    /// Record a real point for velocity calculations
    public func recordPoint(_ point: InkPoint) {
        recentPoints.append(point)
        // Keep only the last 10 points for velocity estimation
        if recentPoints.count > 10 {
            recentPoints.removeFirst()
        }
    }

    /// Generate predicted points based on recent velocity
    /// - Parameter count: Number of predicted points to generate
    /// - Returns: Array of predicted InkPoints
    public func predict(count: Int? = nil) -> [InkPoint] {
        let numPredictions = count ?? predictionCount
        guard recentPoints.count >= 3 else { return [] }

        // Calculate velocity from the most recent points
        let velocity = calculateVelocity()
        guard velocity >= minimumVelocity else { return [] }

        let lastPoint = recentPoints.last!
        let secondLast = recentPoints[recentPoints.count - 2]
        let direction = CGPoint(
            x: lastPoint.location.x - secondLast.location.x,
            y: lastPoint.location.y - secondLast.location.y
        )
        let directionLength = direction.length
        guard directionLength > 0 else { return [] }

        let unitDirection = CGPoint(
            x: direction.x / directionLength,
            y: direction.y / directionLength
        )

        // Determine if this is the start of a curve for damping
        let isCurving = isCurrentlyCurving()

        var predictedPoints: [InkPoint] = []
        let timeStep: TimeInterval = 0.008 // ~8ms per prediction (matching 120Hz)

        for i in 1...numPredictions {
            let dampening: CGFloat = isCurving ? pow(0.7, CGFloat(i)) : pow(0.85, CGFloat(i))
            let predictedDistance = velocity * predictionFactor * dampening * CGFloat(timeStep) * CGFloat(i)

            guard predictedDistance < maximumPredictionDistance else { break }

            // Add slight curve prediction if recent points are curving
            let curveOffset = isCurving ? calculateCurveOffset(at: i) : .zero

            let predictedLocation = CGPoint(
                x: lastPoint.location.x + unitDirection.x * predictedDistance + curveOffset.x,
                y: lastPoint.location.y + unitDirection.y * predictedDistance + curveOffset.y
            )

            let predictedPoint = InkPoint(
                location: predictedLocation,
                pressure: lastPoint.pressure * dampening,
                azimuth: lastPoint.azimuth,
                altitude: lastPoint.altitude,
                roll: lastPoint.roll,
                velocity: velocity * dampening,
                timestamp: lastPoint.timestamp + timeStep * TimeInterval(i),
                isPredicted: true,
                isCoalesced: false
            )
            predictedPoints.append(predictedPoint)
        }

        return predictedPoints
    }

    // MARK: - Private

    private func calculateVelocity() -> CGFloat {
        guard recentPoints.count >= 3 else { return 0 }

        // Use the last 3 points for velocity
        let p1 = recentPoints[recentPoints.count - 3]
        let p2 = recentPoints[recentPoints.count - 2]
        let p3 = recentPoints.last!

        let v1 = p1.distance(to: p2)
        let v2 = p2.distance(to: p3)
        let t1 = p2.timestamp - p1.timestamp
        let t2 = p3.timestamp - p2.timestamp

        let velocity1: CGFloat = t1 > 0 ? v1 / CGFloat(t1) : 0
        let velocity2: CGFloat = t2 > 0 ? v2 / CGFloat(t2) : 0

        // Weighted average (most recent has higher weight)
        return velocity1 * 0.3 + velocity2 * 0.7
    }

    private func isCurrentlyCurving() -> Bool {
        guard recentPoints.count >= 4 else { return false }

        let p1 = recentPoints[recentPoints.count - 4].location
        let p2 = recentPoints[recentPoints.count - 3].location
        let p3 = recentPoints[recentPoints.count - 2].location
        let p4 = recentPoints.last!.location

        // Calculate angles between segments
        let angle1 = angleBetween(
            from: p1, to: p2, and: p2, to: p3
        )
        let angle2 = angleBetween(
            from: p2, to: p3, and: p3, to: p4
        )

        // If there's consistent turning, we're curving
        return abs(angle1) > 0.1 && abs(angle2) > 0.1 && sign(angle1) == sign(angle2)
    }

    private func calculateCurveOffset(at step: Int) -> CGPoint {
        guard recentPoints.count >= 4 else { return .zero }

        let p2 = recentPoints[recentPoints.count - 3].location
        let p3 = recentPoints[recentPoints.count - 2].location
        let p4 = recentPoints.last!.location

        // Calculate the turning direction
        let v1 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        let v2 = CGPoint(x: p4.x - p3.x, y: p4.y - p3.y)

        // Perpendicular direction (cross product)
        let cross = v1.x * v2.y - v1.y * v2.x
        let perpendicular = CGPoint(
            x: -v2.y / max(v2.length, 0.001),
            y: v2.x / max(v2.length, 0.001)
        )

        let curveStrength: CGFloat = sign(cross) * 5 * CGFloat(step) * 0.5
        return CGPoint(x: perpendicular.x * curveStrength, y: perpendicular.y * curveStrength)
    }

    private func angleBetween(from p1: CGPoint, to p2: CGPoint, and p3: CGPoint, to p4: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let v2 = CGPoint(x: p4.x - p3.x, y: p4.y - p3.y)

        let dot = v1.x * v2.x + v1.y * v2.y
        let cross = v1.x * v2.y - v1.y * v2.x
        let len1 = v1.length
        let len2 = v2.length

        guard len1 > 0, len2 > 0 else { return 0 }

        let cosAngle = (dot / (len1 * len2)).clamped(to: -1...1)
        let angle = acos(cosAngle)
        return cross >= 0 ? angle : -angle
    }

    private func sign(_ value: CGFloat) -> CGFloat {
        value >= 0 ? 1 : -1
    }
}
