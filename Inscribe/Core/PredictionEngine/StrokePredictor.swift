import CoreGraphics
import Foundation

// MARK: - StrokePredictor

/// Predicts stroke continuation using velocity-based extrapolation
/// and (future) ML-based prediction.
///
/// This engine runs alongside the TouchPredictor but operates at the stroke
/// level rather than the touch level. It can predict:
/// 1. Where a stroke will go next (for low-latency rendering)
/// 2. The likely shape being drawn (for shape recognition hints)
/// 3. The intended user path (for stroke smoothing)
public class StrokePredictor {

    /// Whether prediction is enabled
    public var isEnabled: Bool = true

    /// Maximum number of predicted points
    public var maxPredictedPoints: Int = 5

    /// Minimum number of points required to start predicting
    public var minimumPointsForPrediction: Int = 3

    /// Confidence threshold for showing predictions
    public var confidenceThreshold: Float = 0.3

    private var velocityHistory: [CGFloat] = []
    private var directionHistory: [CGFloat] = []

    // MARK: - Public API

    /// Predict the next `count` points of a stroke in progress.
    /// - Parameters:
    ///   - stroke: The current stroke being drawn (may be incomplete)
    ///   - count: Number of points to predict
    /// - Returns: Array of predicted InkPoints
    public func predictNextPoints(for stroke: Stroke, count: Int? = nil) -> [InkPoint] {
        guard isEnabled else { return [] }
        let predictionCount = count ?? maxPredictedPoints
        guard stroke.pointCount >= minimumPointsForPrediction else { return [] }

        let recentPoints = Array(stroke.points.suffix(5))
        let velocity = calculateVelocity(from: recentPoints)
        let direction = calculateDirection(from: recentPoints)
        let confidence = velocity.magnitude > 50 ? min(1.0, velocity.magnitude / 1000) : 0

        guard confidence >= confidenceThreshold else { return [] }

        let lastPoint = recentPoints.last!
        let timeStep: TimeInterval = 0.008

        var predicted: [InkPoint] = []

        for i in 1...predictionCount {
            let dampening = pow(0.8, CGFloat(i))
            let distance = velocity.magnitude * dampening * CGFloat(timeStep) * CGFloat(i)

            let angle = direction + (velocity.isCurving ? velocity.curveAngle * CGFloat(i) * 0.1 : 0)

            let predictedLocation = CGPoint(
                x: lastPoint.location.x + cos(angle) * distance,
                y: lastPoint.location.y + sin(angle) * distance
            )

            let point = InkPoint(
                location: predictedLocation,
                pressure: lastPoint.pressure * dampening,
                azimuth: lastPoint.azimuth,
                altitude: lastPoint.altitude,
                roll: lastPoint.roll,
                velocity: velocity.magnitude * dampening,
                timestamp: lastPoint.timestamp + timeStep * TimeInterval(i),
                isPredicted: true,
                isCoalesced: false
            )
            predicted.append(point)
        }

        return predicted
    }

    /// Reset the predictor state for a new stroke
    public func reset() {
        velocityHistory.removeAll()
        directionHistory.removeAll()
    }

    // MARK: - Private

    private struct VelocityInfo {
        let magnitude: CGFloat
        let direction: CGFloat
        let isCurving: Bool
        let curveAngle: CGFloat
    }

    private func calculateVelocity(from points: [InkPoint]) -> VelocityInfo {
        guard points.count >= 3 else {
            return VelocityInfo(magnitude: 0, direction: 0, isCurving: false, curveAngle: 0)
        }

        // Calculate velocities between consecutive points
        var velocities: [CGFloat] = []
        var angles: [CGFloat] = []

        for i in 1..<points.count {
            let dx = points[i].location.x - points[i - 1].location.x
            let dy = points[i].location.y - points[i - 1].location.y
            let dist = points[i].distance(to: points[i - 1])
            let time = points[i].timestamp - points[i - 1].timestamp
            let speed = time > 0 ? dist / CGFloat(time) : 0
            velocities.append(speed)

            let angle = atan2(dy, dx)
            angles.append(angle)
        }

        // Weighted average (most recent = higher weight)
        var weightedSpeed: CGFloat = 0
        var weightSum: CGFloat = 0
        for (i, speed) in velocities.enumerated() {
            let weight = CGFloat(i + 1)
            weightedSpeed += speed * weight
            weightSum += weight
        }
        let avgSpeed = weightSum > 0 ? weightedSpeed / weightSum : 0

        // Current direction
        let currentAngle = angles.last ?? 0

        // Check for curving
        let isCurving = angles.count >= 3
            && abs(angles[angles.count - 1] - angles[angles.count - 2]) > 0.1
            && sign(angles[angles.count - 1]) == sign(angles[angles.count - 2])

        let curveAngle = angles.count >= 2 ? angles.last! - angles[angles.count - 2] : 0

        return VelocityInfo(
            magnitude: avgSpeed,
            direction: currentAngle,
            isCurving: isCurving,
            curveAngle: curveAngle
        )
    }

    private func calculateDirection(from points: [InkPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        let last = points.last!
        let second = points[points.count - 2]
        return atan2(last.location.y - second.location.y, last.location.x - second.location.x)
    }
}
