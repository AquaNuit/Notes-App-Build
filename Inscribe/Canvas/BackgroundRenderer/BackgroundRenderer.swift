import CoreGraphics
import UIKit

// MARK: - BackgroundType

/// Types of canvas backgrounds available.
public enum BackgroundType: String, CaseIterable, Codable, Sendable {
    case blank
    case grid
    case dotGrid
    case ruled
    case musicStaff
    case graphPaper
    case custom

    public var displayName: String {
        switch self {
        case .blank: return "Blank"
        case .grid: return "Grid"
        case .dotGrid: return "Dot Grid"
        case .ruled: return "Ruled"
        case .musicStaff: return "Music Staff"
        case .graphPaper: return "Graph Paper"
        case .custom: return "Custom"
        }
    }
}

// MARK: - BackgroundRenderer

/// Renders background patterns (grids, dot grids, music staff, etc.)
/// for the canvas background layer.
///
/// Backgrounds are rendered as a static texture that can be cached
/// and composited with the stroke layers.
public class BackgroundRenderer {

    /// The spacing between grid lines in canvas points
    public var gridSpacing: CGFloat = 20

    /// Color for primary grid lines
    public var primaryGridColor: UIColor = UIColor(white: 0.85, alpha: 1.0)

    /// Color for secondary grid lines (major divisions)
    public var secondaryGridColor: UIColor = UIColor(white: 0.75, alpha: 1.0)

    /// Color for dot grid dots
    public var dotColor: UIColor = UIColor(white: 0.75, alpha: 1.0)

    /// Dot radius for dot grid
    public var dotRadius: CGFloat = 1.5

    // MARK: - Rendering

    /// Render a background pattern into a CGContext.
    /// - Parameters:
    ///   - context: The graphics context to render into
    ///   - rect: The rect to render in canvas coordinates
    ///   - type: The background type
    ///   - zoomScale: Current zoom scale
    public func renderBackground(
        in context: CGContext,
        rect: CGRect,
        type: BackgroundType,
        zoomScale: CGFloat
    ) {
        switch type {
        case .blank:
            renderBlank(in: context, rect: rect)
        case .grid:
            renderGrid(in: context, rect: rect, zoomScale: zoomScale)
        case .dotGrid:
            renderDotGrid(in: context, rect: rect, zoomScale: zoomScale)
        case .ruled:
            renderRuled(in: context, rect: rect, zoomScale: zoomScale)
        case .musicStaff:
            renderMusicStaff(in: context, rect: rect, zoomScale: zoomScale)
        case .graphPaper:
            renderGraphPaper(in: context, rect: rect, zoomScale: zoomScale)
        case .custom:
            break // Custom templates handled by TemplateManager
        }
    }

    // MARK: - Pattern Renderers

    private func renderBlank(in context: CGContext, rect: CGRect) {
        // Just fill with white
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)
    }

    private func renderGrid(in context: CGContext, rect: CGRect, zoomScale: CGFloat) {
        guard zoomScale > 0.05 else { return } // Skip at very low zoom

        let spacing = gridSpacing
        let visibleSpacing = spacing * zoomScale

        // Only draw if spacing is visible (> 3px)
        guard visibleSpacing > 3 else { return }

        context.setLineWidth(0.5)

        // Vertical lines
        let startX = floor(rect.minX / spacing) * spacing
        let startY = floor(rect.minY / spacing) * spacing

        var x = startX
        while x <= rect.maxX {
            let isMajor = Int(round(x / spacing)) % 5 == 0
            context.setStrokeColor(isMajor ? secondaryGridColor.cgColor : primaryGridColor.cgColor)
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.strokePath()
            x += spacing
        }

        // Horizontal lines
        var y = startY
        while y <= rect.maxY {
            let isMajor = Int(round(y / spacing)) % 5 == 0
            context.setStrokeColor(isMajor ? secondaryGridColor.cgColor : primaryGridColor.cgColor)
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
            y += spacing
        }
    }

    private func renderDotGrid(in context: CGContext, rect: CGRect, zoomScale: CGFloat) {
        guard zoomScale > 0.05 else { return }

        let spacing = gridSpacing
        let visibleSpacing = spacing * zoomScale
        guard visibleSpacing > 5 else { return }

        context.setFillColor(dotColor.cgColor)

        let startX = floor(rect.minX / spacing) * spacing
        let startY = floor(rect.minY / spacing) * spacing
        let radius = dotRadius / zoomScale

        var x = startX
        while x <= rect.maxX {
            var y = startY
            while y <= rect.maxY {
                let dotRect = CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fillEllipse(in: dotRect)
                y += spacing
            }
            x += spacing
        }
    }

    private func renderRuled(in context: CGContext, rect: CGRect, zoomScale: CGFloat) {
        // Standard ruled paper: horizontal lines with left margin
        let lineSpacing: CGFloat = 24
        let marginLeft: CGFloat = 60
        let visibleSpacing = lineSpacing * zoomScale

        guard visibleSpacing > 3 else { return }

        context.setLineWidth(0.5)
        context.setStrokeColor(primaryGridColor.cgColor)

        // Horizontal lines
        let startY = floor(rect.minY / lineSpacing) * lineSpacing
        var y = startY
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
            y += lineSpacing
        }

        // Margin line
        context.setStrokeColor(UIColor.red.withAlphaComponent(0.3).cgColor)
        context.move(to: CGPoint(x: marginLeft, y: rect.minY))
        context.addLine(to: CGPoint(x: marginLeft, y: rect.maxY))
        context.strokePath()
    }

    private func renderMusicStaff(in context: CGContext, rect: CGRect, zoomScale: CGFloat) {
        // 5-line staffs with spacing
        let lineSpacing: CGFloat = 8
        let staffSpacing: CGFloat = 80
        let visibleSpacing = lineSpacing * zoomScale

        guard visibleSpacing > 2 else { return }

        context.setLineWidth(0.5)
        context.setStrokeColor(primaryGridColor.cgColor)

        let startY = floor(rect.minY / staffSpacing) * staffSpacing
        var y = startY
        while y <= rect.maxY {
            // Draw 5 lines per staff
            for i in 0..<5 {
                let lineY = y + CGFloat(i) * lineSpacing
                context.move(to: CGPoint(x: rect.minX, y: lineY))
                context.addLine(to: CGPoint(x: rect.maxX, y: lineY))
                context.strokePath()
            }
            y += staffSpacing
        }
    }

    private func renderGraphPaper(in context: CGContext, rect: CGRect, zoomScale: CGFloat) {
        // Fine grid + minor grid for engineering graph paper
        let minorSpacing: CGFloat = 5
        let majorSpacing: CGFloat = 25

        let visibleMinor = minorSpacing * zoomScale
        guard visibleMinor > 1 else {
            renderGrid(in: context, rect: rect, zoomScale: zoomScale)
            return
        }

        // Minor grid (thin, light)
        context.setLineWidth(0.3)
        context.setStrokeColor(primaryGridColor.withAlphaComponent(0.5).cgColor)

        let startX = floor(rect.minX / minorSpacing) * minorSpacing
        let startY = floor(rect.minY / minorSpacing) * minorSpacing

        var x = startX
        while x <= rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.strokePath()
            x += minorSpacing
        }

        var y = startY
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
            y += minorSpacing
        }

        // Major grid (thicker, darker)
        context.setLineWidth(0.8)
        context.setStrokeColor(secondaryGridColor.cgColor)

        let majorStartX = floor(rect.minX / majorSpacing) * majorSpacing
        let majorStartY = floor(rect.minY / majorSpacing) * majorSpacing

        x = majorStartX
        while x <= rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.strokePath()
            x += majorSpacing
        }

        y = majorStartY
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
            y += majorSpacing
        }
    }
}
