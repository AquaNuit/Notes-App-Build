import CoreGraphics
import Foundation

// MARK: - KalmanFilter

/// A 2D Kalman filter for smoothing Apple Pencil touch points.
///
/// Kalman filtering reduces jitter and noise in touch input while maintaining
/// responsiveness. It works by maintaining an estimate of the true position
/// and velocity of the touch, then updating this estimate with each new measurement.
///
/// The filter is particularly effective for:
/// - Reducing high-frequency noise from hand tremor
/// - Smoothing the transition between coalesced touch points
/// - Providing smoother interpolation when combined with Catmull-Rom splines
public class KalmanFilter {

    // MARK: - State

    /// Filtered position (the current estimate of true position)
    public private(set) var position: CGPoint = .zero

    /// Filtered velocity (estimated speed and direction of movement)
    public private(set) var velocity: CGPoint = .zero

    // MARK: - Configuration

    /// Process noise covariance (how much we trust our motion model).
    /// Higher = more responsive, less smooth.
    public var processNoise: CGFloat = 0.01

    /// Measurement noise covariance (how much we trust each new touch).
    /// Higher = smoother, more lag.
    public var measurementNoise: CGFloat = 0.5

    /// Error covariance (current uncertainty in our estimate)
    private var errorCovariance: CGFloat = 1.0

    /// Whether the filter has been initialized with a first measurement
    private var isInitialized: Bool = false

    // MARK: - Public API

    /// Update the filter with a new raw touch point.
    /// - Parameter measurement: The raw touch point from the system
    /// - Returns: The filtered (smoothed) point
    public func update(with measurement: CGPoint) -> CGPoint {
        guard isInitialized else {
            position = measurement
            velocity = .zero
            errorCovariance = 1.0
            isInitialized = true
            return measurement
        }

        // Predict step (motion model: constant velocity)
        let predictedPosition = CGPoint(
            x: position.x + velocity.x,
            y: position.y + velocity.y
        )
        let predictedErrorCovariance = errorCovariance + processNoise

        // Update step (incorporating measurement)
        let kalmanGain = predictedErrorCovariance / (predictedErrorCovariance + measurementNoise)

        // State update
        let newX = predictedPosition.x + kalmanGain * (measurement.x - predictedPosition.x)
        let newY = predictedPosition.y + kalmanGain * (measurement.y - predictedPosition.y)
        let newPosition = CGPoint(x: newX, y: newY)

        // Velocity update
        velocity = CGPoint(
            x: (newPosition.x - position.x) * 0.5 + velocity.x * 0.5,
            y: (newPosition.y - position.y) * 0.5 + velocity.y * 0.5
        )

        // Error covariance update
        errorCovariance = (1 - kalmanGain) * predictedErrorCovariance

        position = newPosition
        return position
    }

    /// Update with a batch of sequential measurements (e.g., coalesced touches)
    /// - Parameter measurements: Array of raw touch points
    /// - Returns: Array of filtered points
    public func updateBatch(_ measurements: [CGPoint]) -> [CGPoint] {
        measurements.map { update(with: $0) }
    }

    /// Reset the filter to its initial state (call between strokes or on interruption)
    public func reset() {
        position = .zero
        velocity = .zero
        errorCovariance = 1.0
        isInitialized = false
    }

    /// Configure the filter's noise parameters based on drawing speed.
    /// - Parameter speed: Current drawing speed in points/second
    public func configure(for speed: CGFloat) {
        if speed > 500 {
            // Fast drawing: more responsive
            processNoise = 0.1
            measurementNoise = 0.2
        } else if speed > 100 {
            // Medium speed: balance
            processNoise = 0.05
            measurementNoise = 0.5
        } else {
            // Slow/detailed drawing: more smoothing
            processNoise = 0.01
            measurementNoise = 1.0
        }
    }
}
