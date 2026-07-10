import SwiftUI

// MARK: - InfiniteCanvasView

/// A SwiftUI view that wraps the Metal-backed infinite canvas.
///
/// This is the primary canvas view that hosts the Metal rendering layer
/// and provides gesture handling for zoom, pan, and drawing input.
/// It bridges between SwiftUI's declarative world and UIKit/Metal's
/// imperative rendering.
public struct InfiniteCanvasView: UIViewControllerRepresentable {

    @Binding var viewModel: CanvasViewModel

    public init(viewModel: Binding<CanvasViewModel>) {
        self._viewModel = viewModel
    }

    public func makeUIViewController(context: Context) -> CanvasViewController {
        let controller = CanvasViewController(viewModel: viewModel)
        return controller
    }

    public func updateUIViewController(_ uiViewController: CanvasViewController, context: Context) {
        uiViewController.updateViewModel(viewModel)
    }
}

// MARK: - CanvasViewController

/// UIKit view controller hosting the Metal canvas and handling Pencil input.
public class CanvasViewController: UIViewController {

    private var viewModel: CanvasViewModel
    private var metalCanvasView: MetalCanvasView?
    private var pencilInteractionController: PencilInteractionController?

    private let touchEngine = TouchEngine()
    private let palmRejectionFilter = PalmRejectionFilter()
    private let touchCoalescer = TouchCoalescer()
    private let touchPredictor = TouchPredictor()
    private let hoverController = HoverPreviewController()

    // MARK: - Initialization

    public init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupCanvas()
        setupPencilInteraction()
        setupHover()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        metalCanvasView?.coordinateSystem.viewportSize = view.bounds.size
    }

    // MARK: - Setup

    private func setupCanvas() {
        guard let metalRenderer = try? MetalRenderer() else {
            print("Failed to create Metal renderer")
            return
        }

        let canvasView = MetalCanvasView(metalRenderer: metalRenderer, frame: view.bounds)
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(canvasView)

        canvasView.onRender = { [weak self] mtkView, commandBuffer in
            self?.renderFrame(mtkView: mtkView, commandBuffer: commandBuffer)
        }

        self.metalCanvasView = canvasView
        viewModel.coordinateSystem = canvasView.coordinateSystem
    }

    private func setupPencilInteraction() {
        let controller = PencilInteractionController()
        controller.onSqueeze = { [weak self] in
            self?.viewModel.toggleEraser()
        }
        controller.onDoubleTap = { [weak self] in
            self?.viewModel.undo()
        }
        controller.setup(on: view)
        self.pencilInteractionController = controller
    }

    private func setupHover() {
        hoverController.attach(to: view)
        hoverController.brushPreviewDiameter = viewModel.strokeWidth * 2
    }

    // MARK: - ViewModel Updates

    public func updateViewModel(_ viewModel: CanvasViewModel) {
        self.viewModel = viewModel
        viewModel.coordinateSystem = metalCanvasView?.coordinateSystem ?? viewModel.coordinateSystem
    }

    // MARK: - Touch Handling

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view = touch.view else { return }

        let classification = palmRejectionFilter.classify(touch: touch)
        guard classification == .pencil else { return }

        touchEngine.beginSession()
        let inkPoint = touchEngine.process(touch: touch, in: view)
        viewModel.beginStroke(at: inkPoint)

        // Process coalesced touches
        let (coalesced, predicted) = touchCoalescer.process(touch: touch, event: event, in: view)
        for point in coalesced {
            viewModel.addPointToStroke(point)
        }
        for point in predicted {
            viewModel.addPointToStroke(point)
        }

        pencilInteractionController?.updateRoll(from: touch)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view = touch.view else { return }

        let classification = palmRejectionFilter.classify(touch: touch)
        guard classification == .pencil else { return }

        let inkPoint = touchEngine.process(touch: touch, in: view)
        viewModel.addPointToStroke(inkPoint)

        let (coalesced, predicted) = touchCoalescer.process(touch: touch, event: event, in: view)
        for point in coalesced {
            viewModel.addPointToStroke(point)
        }
        for point in predicted {
            viewModel.addPredictedPoint(point)
        }

        pencilInteractionController?.updateRoll(from: touch)

        // Update hover preview
        hoverController.updateHover(
            at: touch.location(in: view),
            toolType: viewModel.activeTool,
            color: viewModel.activeColor,
            strokeWidth: viewModel.strokeWidth
        )
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchEngine.endSession()
        touchPredictor.reset()
        viewModel.endStroke()
        hoverController.hidePreview()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchEngine.endSession()
        touchPredictor.reset()
        viewModel.cancelStroke()
        hoverController.hidePreview()
    }

    // MARK: - Rendering

    private func renderFrame(mtkView: MTKView, commandBuffer: MTLCommandBuffer) {
        // This is a simplified render loop
        // Full implementation would:
        // 1. Draw static layer (cached completed strokes)
        // 2. Draw dynamic layer (active stroke + predicted points)
        // 3. Draw UI overlay (selection, grid, etc.)

        guard let descriptor = mtkView.currentRenderPassDescriptor,
              let drawable = mtkView.currentDrawable else { return }

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.endEncoding()
        commandBuffer.present(drawable)
    }
}
