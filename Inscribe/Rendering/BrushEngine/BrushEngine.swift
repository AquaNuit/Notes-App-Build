import CoreGraphics
import Foundation

// MARK: - BrushEngine

/// Calculates brush properties (width, opacity, tilt offset) for a given point.
///
/// The BrushEngine takes raw InkPoint data and a BrushDefinition and produces
/// the rendering parameters needed by the vertex generator and shader pipeline.
public class BrushEngine {

    public let definition: BrushDefinition

    public init(definition: BrushDefinition) {
        self.definition = definition
    }

    // MARK: - Width Calculation

    /// Calculate the rendered width at a given point.
    /// - Parameter point: The ink point
    /// - Returns: Width in canvas points
    public func width(at point: InkPoint) -> CGFloat {
        let range = definition.maximumWidth - definition.minimumWidth

        // Pressure component
        let pressureFactor = 1.0 - definition.pressureSensitivity
            + definition.pressureSensitivity * point.pressure
        let pressureWidth = definition.minimumWidth + range * pressureFactor

        // Velocity component (thinning)
        let velocityFactor = velocityThinning(velocity: point.velocity)
        let velocityWidth = pressureWidth * (1.0 - definition.velocitySensitivity
            + definition.velocitySensitivity * velocityFactor)

        // Tilt component (wider when flat)
        let tiltFactor = tiltWidthMultiplier(altitude: point.altitude)
        let finalWidth = velocityWidth * (1.0 - definition.tiltSensitivity
            + definition.tiltSensitivity * tiltFactor)

        return finalWidth.clamped(to: definition.minimumWidth...definition.maximumWidth)
    }

    // MARK: - Opacity Calculation

    /// Calculate the opacity at a given point.
    /// - Parameter point: The ink point
    /// - Returns: Alpha value (0-1)
    public func opacity(at point: InkPoint) -> CGFloat {
        var alpha = definition.opacity

        // Tilt affects opacity (flatter pencil = lighter)
        if definition.tiltOpacity > 0 {
            let tiltFactor = 1.0 - (point.altitude / (.pi / 2))
            alpha *= (1.0 - definition.tiltOpacity + definition.tiltOpacity * (1.0 - tiltFactor))
        }

        // Pressure affects opacity for some brushes
        if definition.toolType == .pencil {
            alpha *= (0.3 + 0.7 * point.pressure)
        }

        return alpha.clamped(to: 0...1)
    }

    // MARK: - Tilt Offset

    /// Calculate the offset due to tilt (pencil shading effect).
    /// - Parameter point: The ink point
    /// - Returns: Offset in canvas points
    public func tiltOffset(at point: InkPoint) -> CGPoint {
        let tiltStrength = (1.0 - point.altitude / (.pi / 2)) * definition.tiltSensitivity
        let offset = tiltStrength * 3.0 // Maximum 3pt offset

        return CGPoint(
            x: cos(point.azimuth) * offset,
            y: sin(point.azimuth) * offset
        )
    }

    // MARK: - Texture Coordinate Adjustment

    /// Get the texture coordinate adjustment for calligraphy angle.
    /// - Parameter azimuth: The azimuth angle
    /// - Returns: Rotation angle for texture sampling
    public func textureRotation(azimuth: CGFloat) -> CGFloat {
        switch definition.toolType {
        case .calligraphy:
            return azimuth // Follow pen angle
        case .brush:
            return -azimuth // Oppose pen angle for bristle effect
        default:
            return 0
        }
    }

    // MARK: - Private Helpers

    private func velocityThinning(velocity: CGFloat) -> CGFloat {
        // Fast strokes get thinner
        if velocity < 100 { return 1.0 }
        if velocity < 1000 {
            return 1.0 - (velocity - 100) / 900 * 0.4
        }
        return 0.6
    }

    private func tiltWidthMultiplier(altitude: CGFloat) -> CGFloat {
        // Flat pencil = wider stroke
        if altitude > .pi / 4 { return 1.0 } // Upright
        return 1.0 + (1.0 - altitude / (.pi / 4)) * 0.8
    }
}
