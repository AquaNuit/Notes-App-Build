import Metal
import CoreGraphics
import Foundation
import OSLog

// MARK: - InkPipeline

/// Orchestrates the complete stroke-to-rendered-ink pipeline.
///
/// The InkPipeline connects the StrokeVertexGenerator with the MetalRenderer,
/// manages GPU buffer allocation, and handles the encoding of draw calls.
///
/// Flow:
/// 1. Stroke → StrokeVertexGenerator → vertex data
/// 2. Vertex data → MTLBuffer (GPU)
/// 3. MTLRenderCommandEncoder → set pipeline state → set buffers → draw
public class InkPipeline {

    private let metalRenderer: MetalRenderer
    private let vertexGenerator: StrokeVertexGenerator
    private let logger = Logger(subsystem: "com.inscribe.rendering", category: "InkPipeline")

    // MARK: - Initialization

    public init(metalRenderer: MetalRenderer, vertexGenerator: StrokeVertexGenerator = StrokeVertexGenerator()) {
        self.metalRenderer = metalRenderer
        self.vertexGenerator = vertexGenerator
    }

    // MARK: - Rendering

    /// Encode a batch of strokes for rendering into the current command encoder.
    /// - Parameters:
    ///   - strokes: The strokes to render
    ///   - encoder: The command encoder to use
    ///   - frameUniforms: Frame uniform buffer
    public func encodeStrokes(
        _ strokes: [Stroke],
        into encoder: MTLRenderCommandEncoder,
        frameUniforms: MTLBuffer
    ) {
        encoder.setVertexBuffer(frameUniforms, offset: 0, index: 1)

        for stroke in strokes {
            guard stroke.isVisible else { continue }

            // Get the pipeline state for this tool
            guard let pipelineState = metalRenderer.pipelineState(for: stroke.toolType) else {
                continue
            }

            // Generate vertices
            let vertices = vertexGenerator.generateVertices(for: stroke)
            guard vertices.count >= 4 else { continue } // Need at least 2 points = 4 vertices

            // Create GPU buffer for vertices
            guard let vertexBuffer = createVertexBuffer(from: vertices) else {
                continue
            }

            // Create stroke uniform buffer
            guard let strokeUniforms = createStrokeUniformBuffer(for: stroke) else {
                continue
            }

            // Encode draw call
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentBuffer(strokeUniforms, offset: 0, index: 2)

            let primitiveType: MTLPrimitiveType = (stroke.toolType == .eraserPixel || stroke.toolType == .eraserStroke)
                ? .triangleStrip
                : .triangleStrip

            encoder.drawPrimitives(
                type: primitiveType,
                vertexStart: 0,
                vertexCount: vertices.count
            )
        }
    }

    /// Encode a single active stroke (currently being drawn) for the dynamic layer.
    /// - Parameters:
    ///   - stroke: The active stroke being drawn
    ///   - encoder: The command encoder
    ///   - frameUniforms: Frame uniform buffer
    public func encodeActiveStroke(
        _ stroke: Stroke,
        into encoder: MTLRenderCommandEncoder,
        frameUniforms: MTLBuffer
    ) {
        guard stroke.pointCount >= 2 else { return }

        var renderStroke = stroke
        // Mark predicted points with reduced opacity on the dynamic layer
        if stroke.points.contains(where: { $0.isPredicted }) {
            // Predicted strokes rendered with lower opacity
            renderStroke.color = PlatformColor(
                red: stroke.color.red,
                green: stroke.color.green,
                blue: stroke.color.blue,
                alpha: stroke.color.alpha * 0.4
            )
        }

        encodeStrokes([renderStroke], into: encoder, frameUniforms: frameUniforms)
    }

    // MARK: - Buffer Management

    /// Create a Metal buffer from vertex data.
    public func createVertexBuffer(from vertices: [InkVertex]) -> MTLBuffer? {
        let size = vertices.count * MemoryLayout<InkVertex>.stride
        guard size > 0 else { return nil }

        return metalRenderer.device.makeBuffer(
            bytes: vertices,
            length: size,
            options: .storageModeShared
        )
    }

    /// Create a Metal buffer for frame uniforms.
    public func createFrameUniformBuffer(from uniforms: FrameUniforms) -> MTLBuffer? {
        metalRenderer.device.makeBuffer(
            bytes: uniforms,
            length: MemoryLayout<FrameUniforms>.stride,
            options: .storageModeShared
        )
    }

    /// Create a Metal buffer for stroke uniforms.
    public func createStrokeUniformBuffer(for stroke: Stroke) -> MTLBuffer? {
        var uniforms = StrokeUniforms(
            strokeColor: vector_float4(
                Float(stroke.color.red),
                Float(stroke.color.green),
                Float(stroke.color.blue),
                Float(stroke.color.alpha)
            ),
            strokeWidth: Float(stroke.width),
            brushType: UInt32(toolTypeIndex(stroke.toolType)),
            brushParameter: 0,
            usePressureWidth: stroke.toolType != .highlighter,
            padding: (0, 0)
        )

        return metalRenderer.device.makeBuffer(
            bytes: &uniforms,
            length: MemoryLayout<StrokeUniforms>.stride,
            options: .storageModeShared
        )
    }

    // MARK: - Helpers

    private func toolTypeIndex(_ type: ToolType) -> Int {
        switch type {
        case .fountainPen: return 0
        case .pencil: return 1
        case .marker: return 2
        case .highlighter: return 3
        case .brush: return 4
        case .calligraphy: return 5
        case .eraserPixel: return 6
        case .eraserStroke: return 7
        case .lasso: return 8
        }
    }
}
