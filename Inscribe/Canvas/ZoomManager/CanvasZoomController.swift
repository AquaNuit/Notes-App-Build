import CoreGraphics
import UIKit

// MARK: - CanvasZoomController

/// Manages zoom behavior for the infinite canvas.
///
/// Supports:
/// - Pinch-to-zoom with customizable focal point
/// - Programmatic zoom to specific levels
/// - Zoom constraints (min/max)
/// - Smooth animated zoom transitions
/// - Double-tap to zoom in / two-finger tap to zoom out
public class CanvasZoomController {

    /// Minimum zoom scale
    public var minimumZoom: CGFloat = 0.1

    /// Maximum zoom scale
    public var maximumZoom: CGFloat = 32.0

    /// Whether zoom animation is currently running
    public private(set) var isAnimating: Bool = false

    /// The current zoom scale
    public private(set) var currentScale: CGFloat = 1.0

    /// Called when zoom changes
    public var onZoomChanged: ((CGFloat, CGPoint) -> Void)?

    // MARK: - Pinch Zoom

    /// Handle pinch gesture change.
    /// - Parameters:
    ///   - scale: The gesture's current scale
    ///   - focalPoint: The focal point in screen coordinates
    /// - Returns: The new zoom scale
    @discardableResult
    public func handlePinch(scale: CGFloat, focalPoint: CGPoint) -> CGFloat {
        let newScale = (currentScale * scale).clamped(to: minimumZoom...maximumZoom)
        currentScale = newScale
        onZoomChanged?(newScale, focalPoint)
        return newScale
    }

    /// Handle pinch end (snap to zoom level).
    public func handlePinchEnded() {
        // Snap to nearest "nice" zoom level if close enough
        let niceLevels: [CGFloat] = [0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0, 24.0, 32.0]
        for level in niceLevels {
            if abs(currentScale - level) / level < 0.1 {
                currentScale = level
                break
            }
        }
    }

    // MARK: - Programmatic Zoom

    /// Set zoom to an absolute scale.
    public func setZoom(_ scale: CGFloat, focalPoint: CGPoint) {
        let clampedScale = scale.clamped(to: minimumZoom...maximumZoom)
        currentScale = clampedScale
        onZoomChanged?(clampedScale, focalPoint)
    }

    /// Zoom in by one level (centered on focal point).
    public func zoomIn(focalPoint: CGPoint) {
        let newScale = (currentScale * 1.5).clamped(to: minimumZoom...maximumZoom)
        setZoom(newScale, focalPoint: focalPoint)
    }

    /// Zoom out by one level (centered on focal point).
    public func zoomOut(focalPoint: CGPoint) {
        let newScale = (currentScale / 1.5).clamped(to: minimumZoom...maximumZoom)
        setZoom(newScale, focalPoint: focalPoint)
    }

    /// Zoom to fit a rect on screen.
    public func zoomToFit(_ rect: CGRect, viewportSize: CGSize, padding: CGFloat = 40) {
        let paddedRect = rect.insetBy(dx: -padding, dy: -padding)
        let scaleX = viewportSize.width / paddedRect.width
        let scaleY = viewportSize.height / paddedRect.height
        let fitScale = min(scaleX, scaleY).clamped(to: minimumZoom...maximumZoom)

        let centerPoint = CGPoint(
            x: paddedRect.midX,
            y: paddedRect.midY
        )

        currentScale = fitScale
        onZoomChanged?(fitScale, centerPoint)
    }

    // MARK: - Animation

    /// Animate zoom to a target scale over a duration.
    public func animateZoom(to targetScale: CGFloat, duration: TimeInterval = 0.3) {
        guard !isAnimating else { return }
        isAnimating = true

        let startScale = currentScale
        let startTime = CACurrentMediaTime()

        // Simple animation timer
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] timer in
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(elapsed / duration, 1.0)

            // Ease-out cubic
            let eased = 1.0 - pow(1.0 - progress, 3)
            let current = startScale + (targetScale - startScale) * CGFloat(eased)

            self?.currentScale = current
            self?.onZoomChanged?(current, .zero)

            if progress >= 1.0 {
                timer.invalidate()
                self?.isAnimating = false
            }
        }
    }

    // MARK: - Reset

    /// Reset zoom to default (1.0).
    public func resetZoom() {
        currentScale = 1.0
        onZoomChanged?(1.0, .zero)
    }
}
