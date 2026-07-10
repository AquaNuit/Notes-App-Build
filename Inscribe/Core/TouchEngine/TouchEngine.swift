import CoreGraphics
import Foundation
import UIKit

// MARK: - TouchProcessing Protocol

/// Processes raw UITouch events into InkPoints for stroke building.
public protocol TouchProcessing {
    /// Process a single touch event into an InkPoint
    func process(touch: UITouch, in view: UIView) -> InkPoint

    /// Process coalesced touches (interpolated points between main touch events)
    func process(coalescedTouches touches: [UITouch], in view: UIView) -> [InkPoint]

    /// Process predicted touches (future points estimated by the system)
    func process(predictedTouches touches: [UITouch], in view: UIView) -> [InkPoint]
}

// MARK: - TouchEngine

/// The primary touch processor for Inscribe.
///
/// TouchEngine converts raw UITouch events from Apple Pencil into structured
/// InkPoint values with pressure, tilt, roll, and velocity data.
/// It handles the full lifecycle of a touch from beginning to end, including:
/// - Pressure mapping with configurable curves
/// - Tilt (altitude/azimuth) extraction
/// - Roll (Apple Pencil Pro) extraction
/// - Velocity calculation
/// - Touch type classification (pencil vs finger)
public class TouchEngine: TouchProcessing {

    private var previousTouch: UITouch?
    private var previousPoint: InkPoint?

    /// Whether to include predicted points in the output
    public var usePredictedTouches: Bool = true

    /// Whether to include coalesced points
    public var useCoalescedTouches: Bool = true

    /// The minimum pressure threshold to register a touch
    public var minimumPressureThreshold: CGFloat = 0.001

    // MARK: - TouchProcessing

    public func process(touch: UITouch, in view: UIView) -> InkPoint {
        let location = touch.location(in: view)
        let previousLocation = previousTouch?.location(in: view) ?? location

        // Calculate velocity (points per second)
        let distance = location.distance(to: previousLocation)
        let timeDelta = max(touch.timestamp - (previousTouch?.timestamp ?? touch.timestamp), 0.001)
        let velocity = distance / CGFloat(timeDelta)

        // Determine touch type
        let isPencil = touch.type == .pencil

        // Normalize pressure
        let rawPressure: CGFloat
        if touch.type == .pencil {
            rawPressure = touch.estimatedProperties.contains(.force)
                ? touch.force / touch.maximumPossibleForce
                : 0.5 // Default to mid-pressure if force not yet estimated
        } else {
            rawPressure = touch.force / touch.maximumPossibleForce
        }

        let inkPoint = InkPoint(
            location: location,
            pressure: isPencil ? rawPressure.clamped(to: 0...1) : 0,
            azimuth: touch.azimuthAngle(in: view),
            altitude: touch.altitudeAngle,
            roll: touch.type == .pencil ? touch.roll : nil,
            velocity: velocity,
            timestamp: touch.timestamp,
            isPredicted: false,
            isCoalesced: false
        )

        previousTouch = touch
        previousPoint = inkPoint

        return inkPoint
    }

    public func process(coalescedTouches touches: [UITouch], in view: UIView) -> [InkPoint] {
        guard useCoalescedTouches else { return [] }
        return touches.map { touch in
            var point = process(touch: touch, in: view)
            point.isCoalesced = true
            return point
        }
    }

    public func process(predictedTouches touches: [UITouch], in view: UIView) -> [InkPoint] {
        guard usePredictedTouches else { return [] }
        return touches.map { touch in
            var point = process(touch: touch, in: view)
            point.isPredicted = true
            return point
        }
    }

    // MARK: - Session Management

    /// Called when a new touch sequence begins
    public func beginSession() {
        previousTouch = nil
        previousPoint = nil
    }

    /// Called when a touch sequence ends
    public func endSession() {
        previousTouch = nil
        previousPoint = nil
    }
}
