import CoreGraphics
import Foundation
import UIKit

// MARK: - TouchClassification

/// How a touch event is classified for palm rejection.
public enum TouchClassification: Equatable, Sendable {
    /// The touch is from Apple Pencil
    case pencil
    /// The touch is from a finger (should be ignored for drawing)
    case finger
    /// The touch is from a palm/resting hand (should be ignored)
    case palm
}

// MARK: - PalmRejectionSensitivity

/// Sensitivity level for palm rejection.
public enum PalmRejectionSensitivity: String, CaseIterable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    /// Minimum touch radius to classify as palm
    var palmRadiusThreshold: CGFloat {
        switch self {
        case .low: return 30
        case .medium: return 20
        case .high: return 12
        }
    }

    /// Time window for initial palm detection
    var detectionWindow: TimeInterval {
        switch self {
        case .low: return 0.15
        case .medium: return 0.25
        case .high: return 0.35
        }
    }
}

// MARK: - PalmRejectionFilter

/// Filters touch events to distinguish Apple Pencil input from finger and palm touches.
///
/// Palm rejection is critical for a good note-taking experience. This filter uses
/// multiple heuristics:
/// 1. Touch type: Pencil touches are always accepted
/// 2. Touch radius: Large touch areas indicate palm
/// 3. Touch location: Touches near screen edges are more likely to be palm
/// 4. Multi-touch patterns: Multiple simultaneous touches suggest palm resting
/// 5. Timing: Quick touches with large area are palm
public class PalmRejectionFilter {

    public var sensitivity: PalmRejectionSensitivity = .medium

    /// The minimum distance from the current drawing point that a palm touch
    /// must be to be ignored (in points)
    public var palmIgnoreDistance: CGFloat = 30

    private var activeTouches: [UITouch: TouchClassification] = [:]
    private var touchStartTimes: [UITouch: Date] = [:]
    private var lastAcceptedPencilTouch: UITouch?

    // MARK: - Public API

    /// Classify a touch event.
    /// - Parameter touch: The touch to classify
    /// - Returns: Classification: pencil, finger, or palm
    public func classify(touch: UITouch) -> TouchClassification {
        // Apple Pencil is always accepted
        if touch.type == .pencil {
            activeTouches[touch] = .pencil
            lastAcceptedPencilTouch = touch
            return .pencil
        }

        // If this is a new touch, record start time
        if touchStartTimes[touch] == nil {
            touchStartTimes[touch] = Date()
        }

        // Classify based on touch properties
        let classification = classifyTouch(touch)

        // Track the classification
        if touch.phase == .began {
            activeTouches[touch] = classification
        } else if touch.phase == .ended || touch.phase == .cancelled {
            activeTouches.removeValue(forKey: touch)
            touchStartTimes.removeValue(forKey: touch)
            if touch == lastAcceptedPencilTouch {
                lastAcceptedPencilTouch = nil
            }
        }

        return classification
    }

    /// Check if a touch at a given location should be ignored for drawing.
    /// - Parameter location: The touch location in view coordinates
    /// - Returns: true if this touch should be ignored
    public func shouldIgnoreTouch(at location: CGPoint) -> Bool {
        // Ignore touches near the active pencil area (palm resting near drawing)
        guard let pencilTouch = lastAcceptedPencilTouch else { return false }
        let pencilLocation = pencilTouch.location(in: nil) // screen coordinates
        return location.distance(to: pencilLocation) < palmIgnoreDistance
    }

    /// Update palm rejection sensitivity
    public func setPalmRejectionSensitivity(_ sensitivity: PalmRejectionSensitivity) {
        self.sensitivity = sensitivity
    }

    /// Reset filter state (call when switching tools or canvases)
    public func reset() {
        activeTouches.removeAll()
        touchStartTimes.removeAll()
        lastAcceptedPencilTouch = nil
    }

    // MARK: - Private

    private func classifyTouch(_ touch: UITouch) -> TouchClassification {
        // 1. Apple Pencil check
        guard touch.type != .pencil else { return .pencil }

        // 2. Major radius-based palm detection
        let majorRadius = touch.majorRadius
        if majorRadius > sensitivity.palmRadiusThreshold {
            return .palm
        }

        // 3. Finger vs palm based on size + location
        // Large touches with many simultaneous touches → palm
        let simultaneousTouchCount = activeTouches.count
        if majorRadius > sensitivity.palmRadiusThreshold * 0.7 && simultaneousTouchCount > 3 {
            return .palm
        }

        // 4. Medium-sized touches could be finger or palm
        // Check the location - palm typically rests on edges
        if let window = touch.window {
            let screenBounds = window.bounds
            let location = touch.location(in: window)
            let edgeMargin: CGFloat = 20

            let isNearEdge = location.x < edgeMargin
                || location.x > screenBounds.width - edgeMargin
                || location.y > screenBounds.height - edgeMargin

            if isNearEdge && majorRadius > 8 {
                return .palm
            }
        }

        // 5. Check for rapid large-area touches (palm slap)
        if let startTime = touchStartTimes[touch] {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < sensitivity.detectionWindow && majorRadius > 10 {
                return .palm
            }
        }

        // Default: treat as finger
        return .finger
    }
}
