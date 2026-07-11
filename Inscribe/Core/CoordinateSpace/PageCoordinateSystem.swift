import CoreGraphics
import Foundation

// MARK: - PageSize

/// Standard page sizes supported by Inscribe.
public enum PageSize: String, CaseIterable, Codable, Sendable {
    case a4 = "A4"
    case usLetter = "US Letter"
    case a5 = "A5"
    case a3 = "A3"
    case tabloid = "Tabloid"
    case square = "Square"
    case infinite = "Infinite"

    /// Page size in points (at 72 DPI)
    public var sizeInPoints: CGSize {
        switch self {
        case .a4: return CGSize(width: 595, height: 842)     // 210 x 297 mm
        case .usLetter: return CGSize(width: 612, height: 792) // 8.5 x 11 in
        case .a5: return CGSize(width: 420, height: 595)     // 148 x 210 mm
        case .a3: return CGSize(width: 842, height: 1191)    // 297 x 420 mm
        case .tabloid: return CGSize(width: 792, height: 1224) // 11 x 17 in
        case .square: return CGSize(width: 600, height: 600)
        case .infinite: return CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
        }
    }

    /// Whether this page size has fixed boundaries
    public var hasFixedSize: Bool {
        self != .infinite
    }
}

// MARK: - PageCoordinateSystem

/// Manages page-relative coordinates for the "Page Mode" of the infinite canvas.
///
/// In page mode, content is organized into discrete pages within the infinite canvas.
/// Each page occupies a region of the infinite canvas. This system handles:
/// - Page placement on the infinite canvas
/// - Calculating which page a canvas point belongs to
/// - Page boundaries for export and printing
public struct PageCoordinateSystem: Equatable, Sendable {

    /// The page size for this document
    public var pageSize: PageSize

    /// Spacing between pages in canvas coordinates
    public var pageSpacing: CGFloat = 40

    /// Number of pages in the document
    public var pageCount: Int

    /// Layout direction for pages
    public var layoutDirection: PageLayoutDirection = .vertical

    // MARK: - Initialization

    public init(
        pageSize: PageSize = .a4,
        pageSpacing: CGFloat = 40,
        pageCount: Int = 1,
        layoutDirection: PageLayoutDirection = .vertical
    ) {
        self.pageSize = pageSize
        self.pageSpacing = pageSpacing
        self.pageCount = pageCount
        self.layoutDirection = layoutDirection
    }

    // MARK: - Page Rect Calculation

    /// Get the rect for a specific page in canvas coordinates
    /// - Parameter pageIndex: The page number (0-based)
    /// - Returns: The page rect in canvas coordinates
    public func rectForPage(_ pageIndex: Int) -> CGRect {
        guard pageIndex >= 0, pageIndex < pageCount else { return .zero }

        let size = pageSize.sizeInPoints
        let origin: CGPoint

        switch layoutDirection {
        case .vertical:
            origin = CGPoint(
                x: 0,
                y: CGFloat(pageIndex) * (size.height + pageSpacing)
            )
        case .horizontal:
            origin = CGPoint(
                x: CGFloat(pageIndex) * (size.width + pageSpacing),
                y: 0
            )
        }

        return CGRect(origin: origin, size: size)
    }

    /// Determine which page a canvas point belongs to
    /// - Parameter canvasPoint: A point in canvas coordinates
    /// - Returns: The page index, or nil if the point is between pages
    public func pageIndex(for canvasPoint: CGPoint) -> Int? {
        for i in 0..<pageCount {
            if rectForPage(i).contains(canvasPoint) {
                return i
            }
        }
        return nil
    }

    /// The total canvas size covered by all pages
    public var totalCanvasSize: CGSize {
        let pageSizePoints = pageSize.sizeInPoints
        switch layoutDirection {
        case .vertical:
            let height = CGFloat(pageCount) * pageSizePoints.height
                + CGFloat(max(0, pageCount - 1)) * pageSpacing
            return CGSize(width: pageSizePoints.width, height: height)
        case .horizontal:
            let width = CGFloat(pageCount) * pageSizePoints.width
                + CGFloat(max(0, pageCount - 1)) * pageSpacing
            return CGSize(width: width, height: pageSizePoints.height)
        }
    }

    /// All page rects in the document
    public var allPageRects: [CGRect] {
        (0..<pageCount).map { rectForPage($0) }
    }

    // MARK: - Stroke Clipping

    /// Clip a stroke to a specific page boundary
    /// - Parameters:
    ///   - stroke: The stroke to clip
    ///   - pageIndex: The target page
    /// - Returns: Points within the page rect, or nil if none
    public func clipStroke(_ stroke: Stroke, toPage pageIndex: Int) -> Stroke? {
        let pageRect = rectForPage(pageIndex)
        let inBounds = stroke.points.filter { pageRect.contains($0.location) }
        guard !inBounds.isEmpty else { return nil }

        return Stroke(
            id: stroke.id,
            points: inBounds,
            toolType: stroke.toolType,
            color: stroke.color,
            width: stroke.width,
            creationDate: stroke.creationDate,
            isVisible: stroke.isVisible
        )
    }
}

// MARK: - PageLayoutDirection

public enum PageLayoutDirection: String, Codable, Sendable {
    case vertical
    case horizontal
}
