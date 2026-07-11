import UIKit
import InscribeCore

// MARK: - HoverPreviewController

/// Manages the on-canvas hover preview for Apple Pencil.
///
/// On supported iPads (M2 and later), the system provides hover events
/// before the Pencil touches the screen. This controller renders a
/// preview cursor showing where the Pencil is pointing, including:
/// - Dot/crosshair at the hover position
/// - Brush size preview
/// - Tool tip text
/// - Color swatch
public class HoverPreviewController {

    /// Whether hover preview is enabled
    public var isEnabled: Bool = true {
        didSet {
            hoverView?.isHidden = !isEnabled
        }
    }

    /// The current hover location in view coordinates
    public private(set) var hoverLocation: CGPoint?

    /// Whether the Pencil is currently hovering
    public private(set) var isHovering: Bool = false

    /// The size of the brush preview circle
    public var brushPreviewDiameter: CGFloat = 10

    /// The view that displays the hover indicator
    private var hoverView: UIView?
    private var previewLayer: CAShapeLayer?
    private var label: UILabel?

    // MARK: - Setup

    /// Attach the hover preview to a view.
    /// - Parameter view: The parent view for the hover indicator
    public func attach(to view: UIView) {
        let hView = UIView(frame: view.bounds)
        hView.isUserInteractionEnabled = false
        hView.isHidden = true

        // Preview circle
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5).cgColor
        shapeLayer.lineWidth = 1.5
        shapeLayer.lineDashPattern = [4, 4]

        // Label
        let lbl = UILabel()
        lbl.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        lbl.textColor = UIColor.systemBlue.withAlphaComponent(0.7)
        lbl.textAlignment = .center

        hView.layer.addSublayer(shapeLayer)
        hView.addSubview(lbl)

        view.addSubview(hView)

        self.hoverView = hView
        self.previewLayer = shapeLayer
        self.label = lbl
    }

    /// Update the hover preview.
    /// - Parameters:
    ///   - location: The hover location in view coordinates
    ///   - toolType: The currently active tool
    ///   - color: The currently active color
    ///   - strokeWidth: The currently active stroke width
    public func updateHover(
        at location: CGPoint,
        toolType: ToolType,
        color: PlatformColor,
        strokeWidth: CGFloat
    ) {
        guard isEnabled, let hoverView = hoverView, let previewLayer = previewLayer else { return }

        isHovering = true
        hoverLocation = location
        hoverView.isHidden = false
        hoverView.frame = hoverView.superview?.bounds ?? .zero

        // Update preview position and size
        let diameter = max(strokeWidth * 2, 20)
        let previewRect = CGRect(
            x: location.x - diameter / 2,
            y: location.y - diameter / 2,
            width: diameter,
            height: diameter
        )

        previewLayer.path = UIBezierPath(ovalIn: previewRect).cgPath
        previewLayer.strokeColor = UIColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: 0.5
        ).cgColor

        // Update label
        label?.text = toolType.displayName
        label?.sizeToFit()
        label?.center = CGPoint(x: location.x, y: location.y - diameter / 2 - 12)
    }

    /// Hide the hover preview (when Pencil leaves hover range).
    public func hidePreview() {
        isHovering = false
        hoverLocation = nil
        hoverView?.isHidden = true
    }

    /// Remove the hover view from its parent.
    public func detach() {
        hoverView?.removeFromSuperview()
        hoverView = nil
        previewLayer = nil
        label = nil
    }
}
