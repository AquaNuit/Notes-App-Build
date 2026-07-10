import CoreGraphics
import Foundation

// MARK: - BrushDefinition

/// Defines the rendering parameters for a brush type.
///
/// Each brush type has different:
/// - Width range (min/max)
/// - Pressure sensitivity curve
/// - Tilt response
/// - Texture behavior
/// - Opacity/alpha behavior
/// - Velocity thinning
public struct BrushDefinition: Codable, Equatable, Sendable {

    /// The type of brush
    public let toolType: ToolType

    /// Display name for the brush
    public let displayName: String

    /// Minimum stroke width in points
    public var minimumWidth: CGFloat

    /// Maximum stroke width in points
    public var maximumWidth: CGFloat

    /// Default width (when no pressure data)
    public var defaultWidth: CGFloat

    /// How much pressure affects width (0 = none, 1 = full)
    public var pressureSensitivity: CGFloat

    /// How much velocity affects width (0 = none, 1 = full thinning)
    public var velocitySensitivity: CGFloat

    /// How much tilt affects width (0 = none, 1 = full)
    public var tiltSensitivity: CGFloat

    /// How much tilt affects opacity (0 = none, 1 = full)
    public var tiltOpacity: CGFloat

    /// Default opacity (1.0 = fully opaque)
    public var opacity: CGFloat

    /// Opacity buildup for overlapping strokes (marker behavior)
    public var opacityBuildup: CGFloat

    /// Whether this brush uses a texture
    public var usesTexture: Bool

    /// Texture name for textured brushes
    public var textureName: String?

    /// Whether this is an eraser brush
    public var isEraser: Bool

    /// The blend mode for this brush
    public var blendMode: BrushBlendMode

    // MARK: - Presets

    public static let fountainPen = BrushDefinition(
        toolType: .fountainPen,
        displayName: "Fountain Pen",
        minimumWidth: 0.5,
        maximumWidth: 8.0,
        defaultWidth: 2.0,
        pressureSensitivity: 0.9,
        velocitySensitivity: 0.3,
        tiltSensitivity: 0.2,
        tiltOpacity: 0.0,
        opacity: 0.95,
        opacityBuildup: 0.0,
        usesTexture: false,
        textureName: nil,
        isEraser: false,
        blendMode: .normal
    )

    public static let pencil = BrushDefinition(
        toolType: .pencil,
        displayName: "Pencil",
        minimumWidth: 0.3,
        maximumWidth: 4.0,
        defaultWidth: 1.5,
        pressureSensitivity: 0.8,
        velocitySensitivity: 0.4,
        tiltSensitivity: 0.7,
        tiltOpacity: 0.3,
        opacity: 0.8,
        opacityBuildup: 0.1,
        usesTexture: true,
        textureName: "pencil_texture",
        isEraser: false,
        blendMode: .normal
    )

    public static let marker = BrushDefinition(
        toolType: .marker,
        displayName: "Marker",
        minimumWidth: 1.0,
        maximumWidth: 20.0,
        defaultWidth: 8.0,
        pressureSensitivity: 0.5,
        velocitySensitivity: 0.2,
        tiltSensitivity: 0.3,
        tiltOpacity: 0.0,
        opacity: 0.3,
        opacityBuildup: 0.15,
        usesTexture: false,
        textureName: nil,
        isEraser: false,
        blendMode: .marker
    )

    public static let highlighter = BrushDefinition(
        toolType: .highlighter,
        displayName: "Highlighter",
        minimumWidth: 5.0,
        maximumWidth: 30.0,
        defaultWidth: 15.0,
        pressureSensitivity: 0.3,
        velocitySensitivity: 0.1,
        tiltSensitivity: 0.0,
        tiltOpacity: 0.0,
        opacity: 0.25,
        opacityBuildup: 0.0,
        usesTexture: false,
        textureName: nil,
        isEraser: false,
        blendMode: .highlighter
    )

    public static let brush = BrushDefinition(
        toolType: .brush,
        displayName: "Brush",
        minimumWidth: 1.0,
        maximumWidth: 30.0,
        defaultWidth: 10.0,
        pressureSensitivity: 0.9,
        velocitySensitivity: 0.3,
        tiltSensitivity: 0.5,
        tiltOpacity: 0.4,
        opacity: 0.9,
        opacityBuildup: 0.05,
        usesTexture: true,
        textureName: "brush_texture",
        isEraser: false,
        blendMode: .normal
    )

    public static let calligraphy = BrushDefinition(
        toolType: .calligraphy,
        displayName: "Calligraphy Pen",
        minimumWidth: 0.5,
        maximumWidth: 12.0,
        defaultWidth: 3.0,
        pressureSensitivity: 0.6,
        velocitySensitivity: 0.3,
        tiltSensitivity: 0.0,
        tiltOpacity: 0.0,
        opacity: 0.95,
        opacityBuildup: 0.0,
        usesTexture: false,
        textureName: nil,
        isEraser: false,
        blendMode: .normal
    )

    public static let allPresets: [BrushDefinition] = [
        .fountainPen, .pencil, .marker, .highlighter, .brush, .calligraphy
    ]
}

// MARK: - BrushBlendMode

public enum BrushBlendMode: String, Codable, Sendable {
    case normal
    case marker
    case highlighter
    case eraser
}

// MARK: - BrushDefinitionManager

/// Manages brush definitions and user-customized variants.
public class BrushDefinitionManager {

    public static let shared = BrushDefinitionManager()

    private var customDefinitions: [ToolType: BrushDefinition] = [:]

    public func definition(for toolType: ToolType) -> BrushDefinition {
        customDefinitions[toolType] ?? preset(for: toolType)
    }

    public func setCustomDefinition(_ definition: BrushDefinition, for toolType: ToolType) {
        customDefinitions[toolType] = definition
    }

    public func resetToPreset(for toolType: ToolType) {
        customDefinitions.removeValue(forKey: toolType)
    }

    public func resetAll() {
        customDefinitions.removeAll()
    }

    private func preset(for toolType: ToolType) -> BrushDefinition {
        switch toolType {
        case .fountainPen: return .fountainPen
        case .pencil: return .pencil
        case .marker: return .marker
        case .highlighter: return .highlighter
        case .brush: return .brush
        case .calligraphy: return .calligraphy
        case .eraserPixel, .eraserStroke, .lasso:
            return .fountainPen // Fallback
        }
    }
}
