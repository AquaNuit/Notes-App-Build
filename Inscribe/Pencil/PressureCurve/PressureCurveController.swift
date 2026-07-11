import CoreGraphics
import Foundation
import InscribeCore

// MARK: - PressureCurveType

public enum PressureCurveType: String, CaseIterable, Codable, Sendable {
    case linear
    case logarithmic
    case exponential
    case custom
}

// MARK: - PressureCurveProviding

public protocol PressureCurveProviding {
    func mapPressure(_ rawPressure: CGFloat) -> CGFloat
    var curveType: PressureCurveType { get }
}

// MARK: - LinearPressureCurve

public struct LinearPressureCurve: PressureCurveProviding {
    public let curveType: PressureCurveType = .linear

    public init() {}

    public func mapPressure(_ rawPressure: CGFloat) -> CGFloat {
        rawPressure.clamped(to: 0...1)
    }
}

// MARK: - LogarithmicPressureCurve

public struct LogarithmicPressureCurve: PressureCurveProviding {
    public let curveType: PressureCurveType = .logarithmic

    /// Base of the logarithm (higher = more sensitive at low pressure)
    public var base: CGFloat

    public init(base: CGFloat = 3.0) {
        self.base = max(1.1, base)
    }

    public func mapPressure(_ rawPressure: CGFloat) -> CGFloat {
        let clamped = rawPressure.clamped(to: 0...1)
        // Logarithmic: more sensitive at low pressures
        let result = log(1.0 + clamped * (base - 1.0)) / log(base)
        return result.clamped(to: 0...1)
    }
}

// MARK: - ExponentialPressureCurve

public struct ExponentialPressureCurve: PressureCurveProviding {
    public let curveType: PressureCurveType = .exponential

    /// Exponent (higher = less sensitive at low pressure, more at high)
    public var exponent: CGFloat

    public init(exponent: CGFloat = 2.0) {
        self.exponent = max(0.5, exponent)
    }

    public func mapPressure(_ rawPressure: CGFloat) -> CGFloat {
        let clamped = rawPressure.clamped(to: 0...1)
        // Exponential: less sensitive at low, more at high pressure
        return pow(clamped, exponent)
    }
}

// MARK: - CustomPressureCurve

public struct CustomPressureCurve: PressureCurveProviding {
    public let curveType: PressureCurveType = .custom

    /// Control points for the curve (must be sorted by x)
    public var controlPoints: [CGPoint]

    public init(controlPoints: [CGPoint] = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 0.25, y: 0.15),
        CGPoint(x: 0.5, y: 0.4),
        CGPoint(x: 0.75, y: 0.7),
        CGPoint(x: 1, y: 1)
    ]) {
        self.controlPoints = controlPoints
    }

    public func mapPressure(_ rawPressure: CGFloat) -> CGFloat {
        let clamped = rawPressure.clamped(to: 0...1)

        guard controlPoints.count >= 2 else { return clamped }

        // Find the segment containing this input
        for i in 1..<controlPoints.count {
            let p0 = controlPoints[i - 1]
            let p1 = controlPoints[i]

            if clamped >= p0.x && clamped <= p1.x {
                let t = (clamped - p0.x) / (p1.x - p0.x)
                return p0.y + t * (p1.y - p0.y)
            }
        }

        return clamped
    }
}

// MARK: - PressureCurveController

/// Manages the active pressure curve and provides pressure mapping.
public class PressureCurveController {

    public var activeCurve: PressureCurveProviding {
        didSet {
            onCurveChanged?(activeCurve)
        }
    }

    public var onCurveChanged: ((PressureCurveProviding) -> Void)?

    public init(curve: PressureCurveProviding = LinearPressureCurve()) {
        self.activeCurve = curve
    }

    /// Map raw pressure through the active curve.
    public func mapPressure(_ rawPressure: CGFloat) -> CGFloat {
        activeCurve.mapPressure(rawPressure)
    }

    /// Switch to a specific curve type with optional parameters.
    public func setCurve(_ type: PressureCurveType, parameter: CGFloat = 3.0) {
        switch type {
        case .linear:
            activeCurve = LinearPressureCurve()
        case .logarithmic:
            activeCurve = LogarithmicPressureCurve(base: parameter)
        case .exponential:
            activeCurve = ExponentialPressureCurve(exponent: parameter)
        case .custom:
            activeCurve = CustomPressureCurve()
        }
    }
}
