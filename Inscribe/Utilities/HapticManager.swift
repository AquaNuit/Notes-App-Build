import UIKit

// MARK: - HapticManager

/// Manages haptic feedback for Pencil interactions and UI events.
///
/// Uses the modern UICanvasFeedbackGenerator (iOS 18+) for canvas-specific
/// haptics and UIImpactFeedbackGenerator/UISelectionFeedbackGenerator for
/// other UI interactions.
@available(iOS 17.0, *)
@MainActor
public class HapticManager {


    public static let shared = HapticManager()

    private var canvasFeedback: UICanvasFeedbackGenerator?
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    /// Whether haptic feedback is enabled
    public var isEnabled: Bool = true

    private init() {}

    // MARK: - Canvas Feedback (iOS 18+)

    /// Prepare canvas feedback for a specific view
    public func prepareCanvasFeedback(for view: UIView) {
        if #available(iOS 18.0, *) {
            let feedback = UICanvasFeedbackGenerator(view: view)
            feedback.prepare()
            canvasFeedback = feedback
        }
    }

    /// Trigger haptic on stroke completion
    public func strokeCompleted() {
        guard isEnabled else { return }
        if #available(iOS 18.0, *) {
            canvasFeedback?.pathCompleted(at: CGPoint.zero)
        } else {
            impactLight.impactOccurred(intensity: 0.5)
        }
    }

    /// Trigger haptic on stroke completion at a specific point
    public func strokeCompleted(at point: CGPoint) {
        guard isEnabled else { return }
        if #available(iOS 18.0, *) {
            canvasFeedback?.pathCompleted(at: point)
        } else {
            impactLight.impactOccurred(intensity: 0.5)
        }
    }

    /// Trigger haptic when snapping to a guide
    public func snappedToGuide() {
        guard isEnabled else { return }
        if #available(iOS 18.0, *) {
            canvasFeedback?.alignmentOccurred(at: CGPoint.zero)
        } else {
            selection.selectionChanged()
        }
    }

    /// Trigger haptic when snapping to a guide at a specific point
    public func snappedToGuide(at point: CGPoint) {
        guard isEnabled else { return }
        if #available(iOS 18.0, *) {
            canvasFeedback?.alignmentOccurred(at: point)
        } else {
            selection.selectionChanged()
        }
    }

    // MARK: - Tool Feedback

    public func toolChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    public func colorChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    // MARK: - Interaction Feedback

    public func squeezeDetected() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.7)
    }

    public func doubleTapDetected() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.6)
    }

    public func undoPerformed() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    public func errorOccurred() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    // MARK: - Gesture Feedback

    public func lassoCompleted() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.4)
    }

    public func shapeRecognized() {
        guard isEnabled else { return }
        if #available(iOS 18.0, *) {
            canvasFeedback?.pathCompleted(at: CGPoint.zero)
        } else {
            notification.notificationOccurred(.success)
        }
    }

    public func shapeRecognized(at point: CGPoint) {
        guard isEnabled else { return }
        if #available(iOS 18.0, *) {
            canvasFeedback?.pathCompleted(at: point)
        } else {
            notification.notificationOccurred(.success)
        }
    }

    // MARK: - Preparation

    public func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selection.prepare()
        notification.prepare()
    }
}
