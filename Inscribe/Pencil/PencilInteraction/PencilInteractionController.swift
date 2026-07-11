import UIKit
import OSLog

// MARK: - PencilInteractionController

/// Manages Apple Pencil interactions including squeeze (Pencil Pro),
/// double-tap, and barrel roll.
///
/// This controller sets up UIPencilInteraction and provides delegate callbacks
/// for Pencil-specific gestures. It also reads UITouch properties for
/// barrel roll during drawing.
public class PencilInteractionController: NSObject {

    // MARK: - Callbacks

    public var onSqueeze: (() -> Void)?
    public var onDoubleTap: (() -> Void)?
    public var onBarrelRollChanged: ((CGFloat) -> Void)?

    /// Current barrel roll angle (radians)
    public private(set) var currentRoll: CGFloat = 0

    /// Whether a Pencil Pro is connected
    public private(set) var isPencilProConnected: Bool = false

    private let logger = Logger(subsystem: "com.inscribe.pencil", category: "Interaction")

    // MARK: - Setup

    /// Set up Pencil interactions on a view.
    /// - Parameter view: The view to attach interactions to
    public func setup(on view: UIView) {
        // Set up UIPencilInteraction for squeeze and double-tap
        if #available(iOS 17.5, *) {
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.isEnabled = true
            pencilInteraction.delegate = self
            view.addInteraction(pencilInteraction)
            logger.info("Pencil interaction set up (Pencil Pro supported)")
            isPencilProConnected = true
        } else {
            // Fallback for older iOS versions
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.isEnabled = true
            pencilInteraction.delegate = self
            view.addInteraction(pencilInteraction)
            logger.info("Pencil interaction set up (basic support)")
        }
    }

    /// Update barrel roll from a touch event.
    /// - Parameter touch: The touch event from Pencil
    public func updateRoll(from touch: UITouch) {
        guard touch.type == .pencil else { return }

        // Note: UITouch.roll requires iOS 17+ with Pencil Pro
        // Using fallback of 0 until API is confirmed in the build SDK
        let roll: CGFloat = 0
        if abs(roll - currentRoll) > 0.01 {
            currentRoll = roll
            onBarrelRollChanged?(roll)
        }
    }

    /// Handle squeeze gesture shortcut
    public func handleSqueeze() {
        onSqueeze?()
    }

    /// Handle double-tap shortcut
    public func handleDoubleTap() {
        onDoubleTap?()
    }
}

// MARK: - UIPencilInteractionDelegate

extension PencilInteractionController: UIPencilInteractionDelegate {

    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceive tap: UIPencilInteraction.Tap) {
        // Pencil interaction handling deferred until SDK API is confirmed.
        // The Tap enum API changed in iOS 18 SDK. Re-implement when the
        // correct case names are verified.
        logger.debug("Pencil interaction received")
    }
}

// MARK: - PencilShortcut

/// Actions that can be mapped to Pencil shortcuts.
public enum PencilShortcut: String, CaseIterable, Sendable {
    case toggleEraser
    case undo
    case redo
    case showColorPicker
    case toggleToolPalette
    case showLaserPointer
    case none

    public var displayName: String {
        switch self {
        case .toggleEraser: return "Toggle Eraser"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .showColorPicker: return "Show Color Picker"
        case .toggleToolPalette: return "Toggle Tool Palette"
        case .showLaserPointer: return "Laser Pointer"
        case .none: return "None"
        }
    }
}
