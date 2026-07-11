import CoreGraphics
import Foundation
import UIKit

// MARK: - TouchCoalescer

/// Manages coalesced and predicted touch events for smooth stroke rendering.
///
/// iOS provides:
/// - **Coalesced touches**: Intermediate points interpolated by the system between
///   the main touch events (at ~120Hz vs the main event rate of ~60-80Hz)
/// - **Predicted touches**: Estimated future points to reduce perceived latency
///
/// This class merges these touch types into a single ordered stream for the stroke builder.
public class TouchCoalescer {

    public var includeCoalesced: Bool = true
    public var includePredicted: Bool = true

    // MARK: - Processing

    /// Process a touch event along with its coalesced and predicted touches.
    /// - Parameters:
    ///   - touch: The primary touch event
    ///   - event: The UIEvent containing coalesced/predicted touches
    ///   - view: The view for coordinate conversion
    /// - Returns: (coalesced points, predicted points)
    public func process(
        touch: UITouch,
        event: UIEvent,
        in view: UIView
    ) -> (coalesced: [InkPoint], predicted: [InkPoint]) {
        let coalesced: [InkPoint]
        let predicted: [InkPoint]

        if includeCoalesced, let coalescedTouches = event.coalescedTouches(for: touch) {
            coalesced = coalescedTouches.map { coalescedTouch in
                InkPoint(
                    location: coalescedTouch.location(in: view),
                    pressure: coalescedTouch.force / coalescedTouch.maximumPossibleForce,
                    azimuth: coalescedTouch.azimuthAngle(in: view),
                    altitude: coalescedTouch.altitudeAngle,
                    roll: nil, // TODO: Add Pencil Pro roll support when API is confirmed in target SDK
                    velocity: 0, // velocity calculated by TouchEngine
                    timestamp: coalescedTouch.timestamp,
                    isPredicted: false,
                    isCoalesced: true
                )
            }
        } else {
            coalesced = []
        }

        if includePredicted, let predictedTouches = event.predictedTouches(for: touch) {
            predicted = predictedTouches.map { predictedTouch in
                InkPoint(
                    location: predictedTouch.location(in: view),
                    pressure: predictedTouch.force / predictedTouch.maximumPossibleForce,
                    azimuth: predictedTouch.azimuthAngle(in: view),
                    altitude: predictedTouch.altitudeAngle,
                    roll: nil, // TODO: Add Pencil Pro roll support when API is confirmed in target SDK
                    velocity: 0,
                    timestamp: predictedTouch.timestamp,
                    isPredicted: true,
                    isCoalesced: false
                )
            }
        } else {
            predicted = []
        }

        return (coalesced, predicted)
    }

    /// Merge a touch event and its extras into a single ordered stream.
    /// Order: coalesced → main → predicted
    public func mergePoints(
        mainPoint: InkPoint,
        coalesced: [InkPoint],
        predicted: [InkPoint]
    ) -> (allPoints: [InkPoint], lastRealPoint: InkPoint) {
        var allPoints: [InkPoint] = []
        allPoints.append(contentsOf: coalesced)
        allPoints.append(mainPoint)

        let lastReal = mainPoint

        allPoints.append(contentsOf: predicted)

        return (allPoints, lastReal)
    }
}
