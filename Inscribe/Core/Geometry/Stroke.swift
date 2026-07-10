import CoreGraphics
import Foundation
import SwiftUI

// MARK: - ToolType

/// The drawing tool used for a stroke.
public enum ToolType: String, Codable, CaseIterable, Sendable {
    case fountainPen
    case pencil
    case marker
    case highlighter
    case brush
    case calligraphy
    case eraserPixel
    case eraserStroke
    case lasso

    /// Whether this tool produces visible ink on the canvas
    public var isEraser: Bool {
        self == .eraserPixel || self == .eraserStroke
    }

    /// Whether this tool is a selection tool
    public var isSelectionTool: Bool {
        self == .lasso
    }

    /// Display name for the tool
    public var displayName: String {
        switch self {
        case .fountainPen: return "Fountain Pen"
        case .pencil: return "Pencil"
        case .marker: return "Marker"
        case .highlighter: return "Highlighter"
        case .brush: return "Brush"
        case .calligraphy: return "Calligraphy"
        case .eraserPixel: return "Pixel Eraser"
        case .eraserStroke: return "Stroke Eraser"
        case .lasso: return "Lasso"
        }
    }

    /// System icon name for the tool
    public var iconName: String {
        switch self {
        case .fountainPen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "paintbrush.pointed"
        case .highlighter: return "highlighter"
        case .brush: return "paintbrush"
        case .calligraphy: return "pen.tip"
        case .eraserPixel: return "eraser"
        case .eraserStroke: return "eraser.line.dashed"
        case .lasso: return "lasso"
        }
    }
}

// MARK: - PlatformColor

/// Cross-platform color representation that works with SwiftUI and can be serialized.
public struct PlatformColor: Codable, Equatable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
        self.alpha = alpha.clamped(to: 0...1)
    }

    public init(hex: UInt32) {
        self.red = CGFloat((hex >> 16) & 0xFF) / 255.0
        self.green = CGFloat((hex >> 8) & 0xFF) / 255.0
        self.blue = CGFloat(hex & 0xFF) / 255.0
        self.alpha = 1.0
    }

    public static let black = PlatformColor(red: 0, green: 0, blue: 0)
    public static let white = PlatformColor(red: 1, green: 1, blue: 1)
    public static let clear = PlatformColor(red: 0, green: 0, blue: 0, alpha: 0)

    public var swiftUIColor: Color {
        Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
    }

    /// Pack RGBA into a single UInt32
    public var rgbaUInt32: UInt32 {
        let r = UInt32(round(red * 255)).clamped(to: 0...255)
        let g = UInt32(round(green * 255)).clamped(to: 0...255)
        let b = UInt32(round(blue * 255)).clamped(to: 0...255)
        let a = UInt32(round(alpha * 255)).clamped(to: 0...255)
        return (r << 24) | (g << 16) | (b << 8) | a
    }

    public static func from(rgba: UInt32) -> PlatformColor {
        PlatformColor(
            red: CGFloat((rgba >> 24) & 0xFF) / 255.0,
            green: CGFloat((rgba >> 16) & 0xFF) / 255.0,
            blue: CGFloat((rgba >> 8) & 0xFF) / 255.0,
            alpha: CGFloat(rgba & 0xFF) / 255.0
        )
    }
}

// MARK: - Stroke

/// A complete stroke drawn on the canvas.
///
/// A Stroke is the fundamental drawing primitive in Inscribe. It consists of
/// a sequence of InkPoints captured during a single Pencil stroke, along with
/// the tool configuration that was active when it was drawn.
public struct Stroke: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var points: [InkPoint]
    public var toolType: ToolType
    public var color: PlatformColor
    public var width: CGFloat
    public var transform: CGAffineTransform
    public var creationDate: Date
    public var isVisible: Bool

    /// Computed bounding box of all points in canvas space
    public var bounds: CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for point in points {
            let p = point.location.applying(transform)
            minX = min(minX, p.x - width / 2)
            minY = min(minY, p.y - width / 2)
            maxX = max(maxX, p.x + width / 2)
            maxY = max(maxY, p.y + width / 2)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The number of points in this stroke
    public var pointCount: Int { points.count }

    /// The total length of the stroke in canvas coordinates
    public var length: CGFloat {
        guard points.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<points.count {
            total += points[i].distance(to: points[i - 1])
        }
        return total
    }

    /// Average pressure across all points
    public var averagePressure: CGFloat {
        guard !points.isEmpty else { return 0 }
        return points.reduce(0) { $0 + $1.pressure } / CGFloat(points.count)
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        points: [InkPoint] = [],
        toolType: ToolType = .fountainPen,
        color: PlatformColor = .black,
        width: CGFloat = 2.0,
        transform: CGAffineTransform = .identity,
        creationDate: Date = Date(),
        isVisible: Bool = true
    ) {
        self.id = id
        self.points = points
        self.toolType = toolType
        self.color = color
        self.width = max(0.5, width)
        self.transform = transform
        self.creationDate = creationDate
        self.isVisible = isVisible
    }

    // MARK: - Simplification

    /// Reduce point count by removing points that are very close together.
    /// Uses the Ramer-Douglas-Peucker algorithm.
    /// - Parameter epsilon: Minimum distance threshold. Higher values = fewer points.
    /// - Returns: A new Stroke with simplified points.
    public func simplified(epsilon: CGFloat = 0.5) -> Stroke {
        guard points.count > 2 else { return self }
        var result = Stroke(
            id: id,
            toolType: toolType,
            color: color,
            width: width,
            transform: transform,
            creationDate: creationDate,
            isVisible: isVisible
        )
        result.points = ramerDouglasPeucker(points: points, epsilon: epsilon)
        return result
    }

    private func ramerDouglasPeucker(points: [InkPoint], epsilon: CGFloat) -> [InkPoint] {
        guard points.count > 2 else { return points }

        var maxDistance: CGFloat = 0
        var maxIndex = 0

        let first = points.first!
        let last = points.last!

        for i in 1..<points.count - 1 {
            let distance = perpendicularDistance(from: points[i], toLine: first, lineEnd: last)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        if maxDistance > epsilon {
            let left = ramerDouglasPeucker(points: Array(points[0...maxIndex]), epsilon: epsilon)
            let right = ramerDouglasPeucker(points: Array(points[maxIndex..<points.count]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [first, last]
        }
    }

    private func perpendicularDistance(from point: InkPoint, toLine start: InkPoint, lineEnd end: InkPoint) -> CGFloat {
        let p = point.location
        let s = start.location
        let e = end.location

        let dx = e.x - s.x
        let dy = e.y - s.y
        let lengthSq = dx * dx + dy * dy

        if lengthSq == 0 { return p.distance(to: s) }

        let t = ((p.x - s.x) * dx + (p.y - s.y) * dy) / lengthSq
        let clampedT = t.clamped(to: 0...1)
        let projection = CGPoint(x: s.x + clampedT * dx, y: s.y + clampedT * dy)

        return p.distance(to: projection)
    }
}

// MARK: - Stroke Collection

public extension Array where Element == Stroke {
    /// Compute the union of all stroke bounds
    var unionBounds: CGRect {
        guard !isEmpty else { return .zero }
        var union = CGRect.null
        for stroke in self where stroke.isVisible {
            union = union.union(stroke.bounds)
        }
        return union
    }

    /// Filter strokes that intersect a given rect (using bounding box)
    func strokesIntersecting(_ rect: CGRect) -> [Stroke] {
        filter { $0.isVisible && $0.bounds.intersects(rect) }
    }
}
