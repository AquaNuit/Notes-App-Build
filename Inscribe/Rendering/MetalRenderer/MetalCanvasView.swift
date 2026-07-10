import MetalKit
import UIKit
import OSLog

// MARK: - MetalCanvasView

/// A Metal-backed view for rendering the infinite canvas.
///
/// MetalCanvasView wraps an MTKView and manages:
/// - Frame rendering loop via display link
/// - Coordinate system setup for each frame
/// - Layer compositing (static + dynamic)
/// - Touch event forwarding to the touch engine
public class MetalCanvasView: UIView {

    // MARK: - Properties

    public let metalRenderer: MetalRenderer
    public let mtkView: MTKView

    /// Called when a new frame needs to be drawn
    public var onRender: ((MTKView, MTLCommandBuffer) -> Void)?

    /// The current coordinate system for the canvas
    public var coordinateSystem = CanvasCoordinateSystem()

    private let logger = Logger(subsystem: "com.inscribe.rendering", category: "MetalCanvasView")

    // MARK: - Initialization

    public init(metalRenderer: MetalRenderer, frame: CGRect = .zero) {
        self.metalRenderer = metalRenderer

        // Create MTKView
        self.mtkView = MTKView(frame: frame, device: metalRenderer.device)
        mtkView.backgroundColor = .clear
        mtkView.isOpaque = false
        mtkView.framebufferOnly = false
        mtkView.presentsWithTransaction = false
        mtkView.enableSetNeedsDisplay = true

        // Configure for 120Hz
        if #available(iOS 15.0, *) {
            mtkView.preferredFramesPerSecond = 120
        } else {
            mtkView.preferredFramesPerSecond = 60
        }

        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColorMake(1, 1, 1, 0) // transparent
        mtkView.sampleCount = 1

        super.init(frame: frame)

        // Add MTKView as subview
        addSubview(mtkView)
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mtkView.topAnchor.constraint(equalTo: topAnchor),
            mtkView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mtkView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Set ourselves as the delegate
        mtkView.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func layoutSubviews() {
        super.layoutSubviews()
        coordinateSystem.viewportSize = bounds.size
    }

    /// Request a redraw of the canvas
    public func setNeedsRender() {
        mtkView.setNeedsDisplay(mtkView.bounds)
    }

    /// Force an immediate render
    public func renderNow() {
        mtkView.draw()
    }

    // MARK: - Coordinate Conversion

    /// Convert a point from screen coordinates to canvas coordinates
    public func screenToCanvas(_ screenPoint: CGPoint) -> CGPoint {
        coordinateSystem.screenToCanvas(screenPoint)
    }

    /// Convert a point from canvas coordinates to screen coordinates
    public func canvasToScreen(_ canvasPoint: CGPoint) -> CGPoint {
        coordinateSystem.canvasToScreen(canvasPoint)
    }
}

// MARK: - MTKViewDelegate

extension MetalCanvasView: MTKViewDelegate {

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        coordinateSystem.viewportSize = CGSize(
            width: size.width / view.contentScaleFactor,
            height: size.height / view.contentScaleFactor
        )
    }

    public func draw(in view: MTKView) {
        guard let commandBuffer = metalRenderer.createCommandBuffer() else {
            return
        }

        // Process any necessary state updates
        coordinateSystem.viewportSize = CGSize(
            width: view.drawableSize.width / view.contentScaleFactor,
            height: view.drawableSize.height / view.contentScaleFactor
        )

        // Notify the render handler
        onRender?(view, commandBuffer)

        // Commit the command buffer
        commandBuffer.commit()
    }
}
