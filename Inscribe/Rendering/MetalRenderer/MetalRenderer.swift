import Metal
import MetalKit
import CoreGraphics
import Foundation
import OSLog

// MARK: - MetalRenderer

/// Manages the Metal device, command queue, pipeline states, and render targets.
///
/// The MetalRenderer is the core rendering engine for Inscribe's canvas.
/// It manages:
/// - Metal device and command queue creation
/// - Pipeline state objects for each brush type
/// - Double-buffered render targets (static + dynamic layers)
/// - Frame synchronization via command buffers
/// - Background grid and template rendering
public class MetalRenderer {

    // MARK: - Properties

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    private let library: MTLLibrary
    private var pipelineStates: [String: MTLRenderPipelineState] = [:]
    private var depthStencilState: MTLDepthStencilState?

    private let logger = Logger(subsystem: "com.inscribe.rendering", category: "MetalRenderer")

    // MARK: - Initialization

    /// Initialize the Metal renderer.
    /// - Parameter device: The Metal device to use
    /// - Throws: MetalRendererError if setup fails
    public init(device: MTLDevice? = nil) throws {
        guard let metalDevice = device ?? MTLCreateSystemDefaultDevice() else {
            throw MetalRendererError.deviceNotAvailable
        }
        self.device = metalDevice

        guard let queue = metalDevice.makeCommandQueue() else {
            throw MetalRendererError.commandQueueCreationFailed
        }
        self.commandQueue = queue

        // Load the Metal shader library
        guard let lib = metalDevice.makeDefaultLibrary() else {
            throw MetalRendererError.libraryNotFound
        }
        self.library = lib

        // Setup depth stencil state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = false
        self.depthStencilState = metalDevice.makeDepthStencilState(descriptor: depthDescriptor)

        // Create pipeline states
        try createPipelineStates()
    }

    // MARK: - Pipeline State Setup

    private func createPipelineStates() throws {
        // Ink (solid) pipeline
        try createRenderPipelineState(
            name: "ink",
            vertexFunction: "inkVertexShader",
            fragmentFunction: "inkFragmentShader",
            blendMode: .normal
        )

        // Ink (textured) pipeline
        try createRenderPipelineState(
            name: "inkTextured",
            vertexFunction: "inkVertexShader",
            fragmentFunction: "texturedInkFragmentShader",
            blendMode: .normal
        )

        // Marker pipeline (additive-like buildup)
        try createRenderPipelineState(
            name: "marker",
            vertexFunction: "inkVertexShader",
            fragmentFunction: "markerFragmentShader",
            blendMode: .alpha
        )

        // Highlighter pipeline
        try createRenderPipelineState(
            name: "highlighter",
            vertexFunction: "inkVertexShader",
            fragmentFunction: "highlighterFragmentShader",
            blendMode: .alpha
        )

        // Eraser pipeline
        try createRenderPipelineState(
            name: "eraser",
            vertexFunction: "inkVertexShader",
            fragmentFunction: "eraserFragmentShader",
            blendMode: .alpha
        )

        // Grid pipeline
        try createRenderPipelineState(
            name: "grid",
            vertexFunction: "gridVertexShader",
            fragmentFunction: "gridFragmentShader",
            blendMode: .alpha
        )

        logger.info("Created \(self.pipelineStates.count) Metal pipeline states")
    }

    private func createRenderPipelineState(
        name: String,
        vertexFunction: String,
        fragmentFunction: String,
        blendMode: BlendMode
    ) throws {
        guard let vertexFunc = library.makeFunction(name: vertexFunction) else {
            throw MetalRendererError.functionNotFound(name: vertexFunction)
        }
        guard let fragmentFunc = library.makeFunction(name: fragmentFunction) else {
            throw MetalRendererError.functionNotFound(name: fragmentFunction)
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Ink Pipeline: \(name)"
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Configure blending
        let attachment = descriptor.colorAttachments[0]!
        attachment.isBlendingEnabled = true

        switch blendMode {
        case .normal:
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.sourceAlphaBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        case .alpha:
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.sourceAlphaBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        case .additive:
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.sourceAlphaBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .one
        }

        let state = try device.makeRenderPipelineState(descriptor: descriptor)
        pipelineStates[name] = state
    }

    // MARK: - Pipeline State Access

    /// Get a render pipeline state by name.
    public func pipelineState(named name: String) -> MTLRenderPipelineState? {
        pipelineStates[name]
    }

    /// Get the appropriate pipeline state for a tool type.
    public func pipelineState(for toolType: ToolType) -> MTLRenderPipelineState? {
        switch toolType {
        case .fountainPen, .pencil, .calligraphy:
            return pipelineStates["ink"]
        case .marker:
            return pipelineStates["marker"]
        case .highlighter:
            return pipelineStates["highlighter"]
        case .brush:
            return pipelineStates["inkTextured"]
        case .eraserPixel, .eraserStroke:
            return pipelineStates["eraser"]
        case .lasso:
            return pipelineStates["ink"] // Selection outline
        }
    }

    // MARK: - Command Buffer

    /// Create a new command buffer for rendering a frame.
    public func createCommandBuffer() -> MTLCommandBuffer? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            logger.error("Failed to create command buffer")
            return nil
        }
        commandBuffer.label = "InkFrame"
        return commandBuffer
    }

    /// Create an encoder for the static layer (completed strokes).
    public func createStaticRenderEncoder(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) -> MTLRenderCommandEncoder? {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            logger.error("Failed to create render encoder for static layer")
            return nil
        }
        encoder.label = "Static Layer"
        encoder.setDepthStencilState(depthStencilState)
        return encoder
    }

    /// Create an encoder for the dynamic layer (active stroke).
    public func createDynamicRenderEncoder(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) -> MTLRenderCommandEncoder? {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            logger.error("Failed to create render encoder for dynamic layer")
            return nil
        }
        encoder.label = "Dynamic Layer"
        encoder.setDepthStencilState(depthStencilState)
        return encoder
    }

    // MARK: - Render Target Management

    /// Create an offscreen render target for caching the static layer.
    public func createOffscreenRenderTarget(size: CGSize) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .bgra8Unorm
        descriptor.width = Int(size.width)
        descriptor.height = Int(size.height)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        return device.makeTexture(descriptor: descriptor)
    }
}

// MARK: - BlendMode

public enum BlendMode {
    case normal
    case alpha
    case additive
}

// MARK: - MetalRendererError

public enum MetalRendererError: Error, LocalizedError {
    case deviceNotAvailable
    case commandQueueCreationFailed
    case libraryNotFound
    case functionNotFound(name: String)
    case pipelineStateCreationFailed(name: String)

    public var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Metal is not available on this device"
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue"
        case .libraryNotFound:
            return "Metal shader library not found. Check that Shaders.metal is included in the build phase"
        case .functionNotFound(let name):
            return "Metal function '\(name)' not found in shader library"
        case .pipelineStateCreationFailed(let name):
            return "Failed to create render pipeline state '\(name)'"
        }
    }
}
