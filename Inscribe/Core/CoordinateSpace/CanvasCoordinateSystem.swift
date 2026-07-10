import CoreGraphics
import Foundation

// MARK: - CanvasCoordinateSystem

/// Transforms between canvas coordinate space and screen coordinate space.
///
/// The canvas is an infinite plane. Screen coordinates represent what the user
/// sees through the viewport. This class handles:
/// - Canvas → Screen (for rendering)
/// - Screen → Canvas (for touch input)
/// - Zoom and pan transforms
/// - Viewport rectangle calculation
public struct CanvasCoordinateSystem: Equatable, Sendable {

    /// Current zoom scale (1.0 = 100%)
    public var zoomScale: CGFloat {
        didSet {
            zoomScale = zoomScale.clamped(to: minimumZoom...maximumZoom)
        }
    }

    /// Current pan offset in canvas coordinates
    public var panOffset: CGPoint

    /// Minimum allowed zoom scale
    public var minimumZoom: CGFloat = 0.1

    /// Maximum allowed zoom scale
    public var maximumZoom: CGFloat = 32.0

    /// The viewport size in screen points
    public var viewportSize: CGSize

    // MARK: - Initialization

    public init(
        zoomScale: CGFloat = 1.0,
        panOffset: CGPoint = .zero,
        viewportSize: CGSize = .zero
    ) {
        self.zoomScale = zoomScale.clamped(to: 0.1...32.0)
        self.panOffset = panOffset
        self.viewportSize = viewportSize
    }

    // MARK: - Transforms

    /// The combined transform: canvas → screen
    public var canvasToScreenTransform: CGAffineTransform {
        CGAffineTransform(scaleX: zoomScale, y: zoomScale)
            .translatedBy(x: -panOffset.x, y: -panOffset.y)
    }

    /// The inverse transform: screen → canvas
    public var screenToCanvasTransform: CGAffineTransform {
        canvasToScreenTransform.inverted()
    }

    /// Convert a point from canvas space to screen space
    public func canvasToScreen(_ canvasPoint: CGPoint) -> CGPoint {
        canvasPoint.applying(canvasToScreenTransform)
    }

    /// Convert a point from screen space to canvas space
    public func screenToCanvas(_ screenPoint: CGPoint) -> CGPoint {
        screenPoint.applying(screenToCanvasTransform)
    }

    /// Convert a rect from canvas space to screen space
    public func canvasToScreen(_ canvasRect: CGRect) -> CGRect {
        let origin = canvasToScreen(canvasRect.origin)
        let size = CGSize(
            width: canvasRect.width * zoomScale,
            height: canvasRect.height * zoomScale
        )
        return CGRect(origin: origin, size: size)
    }

    /// Convert a rect from screen space to canvas space
    public func screenToCanvas(_ screenRect: CGRect) -> CGRect {
        let origin = screenToCanvas(screenRect.origin)
        let size = CGSize(
            width: screenRect.width / zoomScale,
            height: screenRect.height / zoomScale
        )
        return CGRect(origin: origin, size: size)
    }

    // MARK: - Viewport

    /// The visible area in canvas coordinates
    public var visibleCanvasRect: CGRect {
        let screenRect = CGRect(origin: .zero, size: viewportSize)
        return screenToCanvas(screenRect)
    }

    /// The center of the viewport in canvas coordinates
    public var viewportCenter: CGPoint {
        CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height / 2
        ).applying(screenToCanvasTransform)
    }

    // MARK: - Zoom

    /// Zoom to a specific point on the canvas (e.g., for pinch zoom)
    /// - Parameters:
    ///   - newScale: The target zoom scale
    ///   - focalPoint: The focal point in screen coordinates
    public func zoom(to newScale: CGFloat, focalPoint: CGPoint) -> CanvasCoordinateSystem {
        let clampedScale = newScale.clamped(to: minimumZoom...maximumZoom)
        let canvasPoint = screenToCanvas(focalPoint)

        var newSystem = self
        newSystem.zoomScale = clampedScale

        // Adjust pan so the focal point stays in the same screen position
        let newScreenPoint = canvasPoint.applying(newSystem.canvasToScreenTransform)
        newSystem.panOffset.x -= (newScreenPoint.x - focalPoint.x) / newSystem.zoomScale
        newSystem.panOffset.y -= (newScreenPoint.y - focalPoint.y) / newSystem.zoomScale

        return newSystem
    }

    /// Pan to center on a specific canvas point
    public func panToCenter(on canvasPoint: CGPoint) -> CanvasCoordinateSystem {
        var newSystem = self
        newSystem.panOffset = canvasPoint
        return newSystem
    }

    /// Check if a canvas rect is visible (at least partially) in the current viewport
    public func isVisible(canvasRect: CGRect) -> Bool {
        visibleCanvasRect.intersects(canvasRect)
    }

    /// Equality
    public static func == (lhs: CanvasCoordinateSystem, rhs: CanvasCoordinateSystem) -> Bool {
        lhs.zoomScale == rhs.zoomScale
            && lhs.panOffset == rhs.panOffset
            && lhs.viewportSize == rhs.viewportSize
    }
}
