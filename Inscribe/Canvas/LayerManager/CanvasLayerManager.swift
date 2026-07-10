import CoreGraphics
import Foundation

// MARK: - CanvasLayers

/// Enumeration of rendering layers in the canvas.
public enum CanvasLayer: Int, CaseIterable {
    /// Background grid, templates (bottom-most)
    case background

    /// Completed strokes (static, cached)
    case staticStrokes

    /// Currently active stroke (dynamic, updated per-frame)
    case activeStroke

    /// Selection highlights, lasso path
    case selection

    /// UI overlays (top-most)
    case uiOverlay
}

// MARK: - CanvasLayerManager

/// Manages the composition and visibility of all canvas layers.
///
/// The canvas uses a multi-layer approach:
/// 1. Background layer: grids, templates, static content
/// 2. Static layer: completed strokes (rendered once, cached)
/// 3. Dynamic layer: in-progress strokes (redrawn per frame)
/// 4. Selection layer: lasso selection highlights
/// 5. UI overlay: tool indicators, zoom level
///
/// Each layer can be independently toggled and cleared.
public class CanvasLayerManager {

    /// Whether each layer is visible
    public var layerVisibility: [CanvasLayer: Bool] = [
        .background: true,
        .staticStrokes: true,
        .activeStroke: true,
        .selection: true,
        .uiOverlay: true
    ]

    // MARK: - Layer Operations

    /// Set visibility for a specific layer.
    public func setLayer(_ layer: CanvasLayer, visible: Bool) {
        layerVisibility[layer] = visible
    }

    /// Check if a layer is visible.
    public func isLayerVisible(_ layer: CanvasLayer) -> Bool {
        layerVisibility[layer] ?? true
    }

    /// Get the render order for layers (bottom to top).
    public var renderOrder: [CanvasLayer] {
        CanvasLayer.allCases.sorted { $0.rawValue < $1.rawValue }
            .filter { layerVisibility[$0] ?? true }
    }

    /// Reset all layers to default visibility.
    public func resetVisibility() {
        for layer in CanvasLayer.allCases {
            layerVisibility[layer] = true
        }
    }
}
