import CoreGraphics
import Foundation
import InscribeCore

// MARK: - TiltShadingEngine

/// Calculates tilt-based shading effects for pencil-like brushes.
///
/// When the Apple Pencil is tilted (low altitude), the side of the pencil
/// creates a wider, lighter stroke — similar to a real pencil. This engine
/// simulates that effect by adjusting opacity and width based on altitude
/// and azimuth.
public class TiltShadingEngine {

    /// Minimum opacity for flat angles (as fraction of max opacity)
    public var minimumOpacityRatio: CGFloat = 0.3

    /// Maximum width multiplier for flat angles
    public var maximumWidthMultiplier: CGFloat = 2.0

    /// The azimuth angle at which shading is strongest
    public var shadingDirection: CGFloat = 0

    // MARK: - Shading Calculations

    /// Calculate the opacity multiplier from tilt.
    /// - Parameter altitude: The altitude angle (radians)
    /// - Returns: Opacity multiplier (0-1)
    public func opacityMultiplier(altitude: CGFloat) -> CGFloat {
        // Upright (π/2): full opacity
        // Flat (0): minimum opacity
        let normalizedAltitude = (altitude / (.pi / 2)).clamped(to: 0...1)
        return minimumOpacityRatio + (1 - minimumOpacityRatio) * normalizedAltitude
    }

    /// Calculate the width multiplier from tilt.
    /// - Parameter altitude: The altitude angle (radians)
    /// - Returns: Width multiplier (1.0 = normal, higher = wider)
    public func widthMultiplier(altitude: CGFloat) -> CGFloat {
        let normalizedAltitude = (altitude / (.pi / 2)).clamped(to: 0...1)
        let flatness = 1 - normalizedAltitude
        return 1.0 + flatness * (maximumWidthMultiplier - 1.0)
    }

    /// Calculate the offset for shading effect (simulates pencil side contact).
    /// - Parameters:
    ///   - altitude: The altitude angle
    ///   - azimuth: The azimuth angle
    /// - Returns: Offset in canvas points
    public func shadingOffset(altitude: CGFloat, azimuth: CGFloat) -> CGPoint {
        let flatness = 1 - (altitude / (.pi / 2))
        guard flatness > 0.01 else { return .zero }

        // Offset is in the direction opposite to the azimuth
        let offsetMagnitude = flatness * 5.0 // Up to 5pt offset
        return CGPoint(
            x: -cos(azimuth) * offsetMagnitude,
            y: -sin(azimuth) * offsetMagnitude
        )
    }

    /// Generate a tilt-related noise value for pencil texture.
    /// - Parameters:
    ///   - altitude: The altitude angle
    ///   - azimuth: The azimuth angle
    ///   - position: Position on the canvas (for spatial noise)
    /// - Returns: Noise value (0-1) for texture mixing
    public func tiltNoise(altitude: CGFloat, azimuth: CGFloat, position: CGPoint) -> CGFloat {
        let flatness = 1 - (altitude / (.pi / 2))
        guard flatness > 0.01 else { return 0 }

        // Simple deterministic noise based on position and angle
        let noiseInput = position.x * 0.1 + position.y * 0.1 + azimuth
        let noise = sin(noiseInput) * 0.5 + 0.5
        return noise * flatness * 0.3
    }
}
