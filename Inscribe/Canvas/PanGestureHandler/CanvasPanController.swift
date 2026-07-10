import CoreGraphics
import UIKit

// MARK: - CanvasPanController

/// Manages pan (scroll) behavior for the infinite canvas.
///
/// Features:
/// - Smooth drag panning
/// - Momentum/inertia scrolling after gesture ends
/// - Configurable friction and speed
/// - Programmatic pan to specific canvas points
/// - Pan constraints (optional)
public class CanvasPanController {

    /// Whether momentum scrolling is enabled
    public var momentumEnabled: Bool = true

    /// Friction coefficient for momentum (0.0 = no friction, 1.0 = stop immediately)
    public var friction: CGFloat = 0.92

    /// Minimum velocity for momentum to start (points/second)
    public var minimumMomentumVelocity: CGFloat = 50

    /// The current pan offset in canvas coordinates
    public private(set) var currentOffset: CGPoint = .zero

    /// The current velocity for momentum scrolling
    public private(set) var velocity: CGPoint = .zero

    /// Whether momentum is currently active
    public private(set) var isDecelerating: Bool = false

    /// Called when the pan offset changes
    public var onPanChanged: ((CGPoint) -> Void)?

    // MARK: - Pan Handling

    /// Handle a pan gesture change.
    /// - Parameter translation: The gesture's translation in screen points
    /// - Parameter zoomScale: Current zoom scale (for converting screen → canvas)
    public func handlePan(translation: CGSize, zoomScale: CGFloat) {
        let canvasDelta = CGPoint(
            x: -translation.width / zoomScale,
            y: -translation.height / zoomScale
        )

        currentOffset.x += canvasDelta.x
        currentOffset.y += canvasDelta.y

        // Calculate velocity for momentum
        velocity = CGPoint(
            x: canvasDelta.x * 60, // Approximate per-second velocity
            y: canvasDelta.y * 60
        )

        onPanChanged?(currentOffset)
    }

    /// Handle pan end (start momentum).
    public func handlePanEnded() {
        guard momentumEnabled, velocity.length >= minimumMomentumVelocity else {
            velocity = .zero
            return
        }

        startMomentum()
    }

    // MARK: - Momentum

    private var momentumDisplayLink: CADisplayLink?

    private func startMomentum() {
        isDecelerating = true
        momentumDisplayLink = CADisplayLink(target: self, selector: #selector(momentumTick))
        momentumDisplayLink?.add(to: .main, forMode: .common)
    }

    @objc private func momentumTick() {
        velocity.x *= friction
        velocity.y *= friction

        currentOffset.x += velocity.x / 60
        currentOffset.y += velocity.y / 60

        onPanChanged?(currentOffset)

        if velocity.length < 1 {
            stopMomentum()
        }
    }

    private func stopMomentum() {
        isDecelerating = false
        velocity = .zero
        momentumDisplayLink?.invalidate()
        momentumDisplayLink = nil
    }

    // MARK: - Programmatic Pan

    /// Pan to an absolute canvas position.
    public func panTo(_ position: CGPoint, animated: Bool = true) {
        if animated {
            animatePan(to: position, duration: 0.3)
        } else {
            currentOffset = position
            onPanChanged?(position)
        }
    }

    private func animatePan(to target: CGPoint, duration: TimeInterval) {
        let startOffset = currentOffset
        let startTime = CACurrentMediaTime()

        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] timer in
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(elapsed / duration, 1.0)

            let eased = 1.0 - pow(1.0 - progress, 3)

            self?.currentOffset = CGPoint(
                x: startOffset.x + (target.x - startOffset.x) * CGFloat(eased),
                y: startOffset.y + (target.y - startOffset.y) * CGFloat(eased)
            )
            self?.onPanChanged?(self?.currentOffset ?? .zero)

            if progress >= 1.0 {
                timer.invalidate()
            }
        }
    }

    // MARK: - Reset

    /// Reset pan to origin.
    public func reset() {
        currentOffset = .zero
        velocity = .zero
        stopMomentum()
        onPanChanged?(.zero)
    }
}
