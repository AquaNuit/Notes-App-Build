import CoreGraphics
import Foundation

// MARK: - VariableWidthInk

/// Implements variable-width ink logic for fountain pen simulation.
///
/// The fountain pen effect creates elegant, calligraphic strokes where:
/// - Width varies smoothly with pressure
/// - Downstrokes are thicker, upstrokes are thinner
/// - Curves show natural width variation
/// - Velocity affects width (faster = thinner)
///
/// This module provides the mathematical functions to compute these effects
/// independent of the rendering backend.
public class VariableWidthInk {

    /// Calculate the fountain pen width at a given point.
    ///
    /// Fountain pen simulation considers:
    /// 1. Pressure (primary width control)
    /// 2. Direction of stroke (downstrokes are thicker)
    /// 3. Velocity (fast strokes are thinner)
    /// 4. Surface angle (tilt effects)
    ///
    /// - Parameters:
    ///   - pressure: Touch pressure (0-1)
    ///   - velocity: Touch velocity in pts/s
    ///   - directionAngle: The angle of the stroke movement (radians)
    ///   - altitude: Pencil altitude angle (radians)
    ///   - nibWidth: The nib width of the pen (typically 1-5pt)
    /// - Returns: The rendered width at this point
    public static func fountainPenWidth(
        pressure: CGFloat,
        velocity: CGFloat,
        directionAngle: CGFloat,
        altitude: CGFloat,
        nibWidth: CGFloat = 2.0
    ) -> CGFloat {
        // 1. Pressure: primary width driver
        let pressureWidth = nibWidth * (0.3 + 0.7 * pow(pressure, 0.8))

        // 2. Velocity thinning
        let velocityFactor: CGFloat
        if velocity < 50 {
            velocityFactor = 1.0
        } else if velocity < 800 {
            velocityFactor = max(0.5, 1.0 - (velocity - 50) / 750 * 0.5)
        } else {
            velocityFactor = 0.5
        }

        // 3. Directional width variation (downstroke vs upstroke)
        // Downstroke = moving downward (angle near π/2)
        // This creates the characteristic fountain pen line variation
        let verticalComponent = abs(sin(directionAngle))
        let directionFactor = 0.7 + 0.3 * verticalComponent

        // 4. Tilt effect (flatter = wider)
        let tiltFactor: CGFloat
        if altitude < .pi / 6 {
            tiltFactor = 1.3 // Very flat
        } else if altitude < .pi / 3 {
            tiltFactor = 1.0 + (1.0 - altitude / (.pi / 3)) * 0.3
        } else {
            tiltFactor = 1.0 // Upright
        }

        return pressureWidth * velocityFactor * directionFactor * tiltFactor
    }

    /// Calculate the calligraphy pen width at a given azimuth.
    ///
    /// Calligraphy pens have a flat nib whose angle relative to the stroke
    /// direction creates thick/thin variation.
    ///
    /// - Parameters:
    ///   - azimuth: Pencil azimuth angle (radians)
    ///   - strokeAngle: The angle of the stroke (radians)
    ///   - nibWidth: The calligraphy nib width
    /// - Returns: The rendered width
    public static func calligraphyWidth(
        azimuth: CGFloat,
        strokeAngle: CGFloat,
        nibWidth: CGFloat = 4.0
    ) -> CGFloat {
        // The angle between the pen nib and the stroke direction
        let angleDiff = abs(azimuth - strokeAngle)
        let normalizedAngle = min(angleDiff, .pi - angleDiff)

        // Width is max when stroke is perpendicular to nib angle
        let widthFactor = abs(sin(normalizedAngle))
        return max(0.5, nibWidth * widthFactor)
    }

    /// Determine if the current stroke direction is a "downstroke"
    /// for fountain pen simulation.
    public static func isDownstroke(directionAngle: CGFloat) -> Bool {
        let verticalComponent = sin(directionAngle)
        return verticalComponent > 0.3
    }
}
