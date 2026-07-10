import SwiftUI
import Combine

// MARK: - CanvasViewModel

/// Manages the state of the canvas editing session.
///
/// CanvasViewModel is the central state manager for the active canvas.
/// It tracks:
/// - Current stroke being drawn (activeStroke)
/// - Completed strokes (strokes)
/// - Active tool configuration (tool, color, width)
/// - Selection state (lasso)
/// - Undo/redo
/// - Coordinate system (zoom, pan)
///
/// This is designed as an @Observable class for SwiftUI integration.
@available(iOS 17.0, *)
@Observable
public final class CanvasViewModel {

    // MARK: - Drawing State

    /// All completed strokes on the current page
    public private(set) var strokes: [Stroke] = []

    /// The stroke currently being drawn (nil when not drawing)
    public private(set) var activeStroke: Stroke?

    /// Whether the user is currently drawing
    public private(set) var isDrawing: Bool = false

    // MARK: - Tool State

    /// The currently active drawing tool
    public var activeTool: ToolType = .fountainPen

    /// The currently active stroke color
    public var activeColor: PlatformColor = .black

    /// The currently active stroke width
    public var strokeWidth: CGFloat = 2.0

    /// Whether the eraser is active (toggled via Pencil squeeze)
    public var isEraserActive: Bool = false

    // MARK: - Selection

    /// Currently selected strokes (for move/copy/delete)
    public private(set) var selectedStrokeIDs: Set<UUID> = []

    /// The lasso path currently being drawn
    public var lassoPath: [CGPoint] = []

    /// Whether there's an active selection
    public var hasSelection: Bool { !selectedStrokeIDs.isEmpty }

    // MARK: - Canvas State

    /// The coordinate system for zoom/pan
    public var coordinateSystem = CanvasCoordinateSystem()

    /// The page coordinate system for page mode
    public var pageCoordinateSystem = PageCoordinateSystem()

    // MARK: - Dependencies

    public var undoManager: InscribeUndoManager
    public var brushEngine: BrushEngine

    // MARK: - Stroke Building

    private var strokeBuilder: StrokeBuilder

    // MARK: - Initialization

    public init(
        strokes: [Stroke] = [],
        undoManager: InscribeUndoManager = InscribeUndoManager(),
        brushEngine: BrushEngine? = nil
    ) {
        self.strokes = strokes
        self.undoManager = undoManager
        self.brushEngine = brushEngine ?? BrushEngine(definition: .fountainPen)
        self.strokeBuilder = StrokeBuilder()
    }

    // MARK: - Drawing Actions

    /// Begin a new stroke at the given point.
    public func beginStroke(at point: InkPoint) {
        isDrawing = true
        let tool = isEraserActive ? (activeTool == .eraserPixel ? .eraserPixel : .eraserStroke) : activeTool
        let width = brushEngine.width(at: point)
        strokeBuilder.beginStroke(at: point, tool: tool, color: activeColor, width: width)
    }

    /// Add a point to the current stroke.
    public func addPointToStroke(_ point: InkPoint) {
        guard isDrawing else { return }
        strokeBuilder.appendPoint(point)
        updateActiveStroke()
    }

    /// Add predicted points to the current stroke.
    public func addPredictedPoint(_ point: InkPoint) {
        guard isDrawing else { return }
        strokeBuilder.appendPredictedPoint(point)
        updateActiveStroke()
    }

    /// End the current stroke and add it to the completed strokes.
    /// Predicted points are excluded from the finalized stroke — they're only for
    /// real-time display latency reduction.
    public func endStroke() {
        guard isDrawing else { return }

        let stroke = strokeBuilder.endStroke(excludePredicted: true)
        guard stroke.pointCount >= 2 else {
            isDrawing = false
            return
        }

        strokes.append(stroke)
        activeStroke = nil
        isDrawing = false

        // Register undo action
        let undoAction = StrokeAction(
            label: "Draw Stroke",
            strokeID: stroke.id,
            pageID: UUID(),
            undo: { [weak self] in
                self?.strokes.removeAll { $0.id == stroke.id }
            },
            redo: { [weak self] in
                self?.strokes.append(stroke)
            }
        )
        undoManager.registerUndo(undoAction)
    }

    /// Cancel the current stroke (no points saved).
    public func cancelStroke() {
        strokeBuilder.cancelStroke()
        activeStroke = nil
        isDrawing = false
    }

    /// Undo the last drawing action.
    public func undo() {
        try? undoManager.undo()
    }

    /// Redo the last undone action.
    public func redo() {
        try? undoManager.redo()
    }

    /// Toggle between current tool and eraser.
    public func toggleEraser() {
        isEraserActive.toggle()
    }

    // MARK: - Selection Actions

    /// Select strokes within a lasso path.
    public func selectStrokes(in path: [CGPoint]) {
        guard path.count >= 3 else { return }
        let lassoRect = boundingBox(of: path)

        selectedStrokeIDs = Set(
            strokes.filter { stroke in
                stroke.isVisible && lassoRect.intersects(stroke.bounds)
            }.map { $0.id }
        )
    }

    /// Clear the current selection.
    public func clearSelection() {
        selectedStrokeIDs.removeAll()
        lassoPath.removeAll()
    }

    /// Delete the selected strokes.
    public func deleteSelectedStrokes() {
        let toDelete = strokes.filter { selectedStrokeIDs.contains($0.id) }
        for stroke in toDelete {
            let undoAction = StrokeAction(
                label: "Delete Stroke",
                strokeID: stroke.id,
                pageID: UUID(),
                undo: { [weak self] in self?.strokes.append(stroke) },
                redo: { [weak self] in self?.strokes.removeAll { $0.id == stroke.id } }
            )
            undoManager.registerUndo(undoAction)
        }
        strokes.removeAll { selectedStrokeIDs.contains($0.id) }
        clearSelection()
    }

    // MARK: - Zoom/Pan

    /// Zoom the canvas by a scale factor, centered on a focal point.
    public func zoom(by scale: CGFloat, focalPoint: CGPoint) {
        let newScale = (coordinateSystem.zoomScale * scale)
            .clamped(to: coordinateSystem.minimumZoom...coordinateSystem.maximumZoom)
        coordinateSystem = coordinateSystem.zoom(to: newScale, focalPoint: focalPoint)
    }

    /// Pan the canvas by an offset.
    public func pan(by offset: CGSize) {
        coordinateSystem.panOffset.x -= offset.width / coordinateSystem.zoomScale
        coordinateSystem.panOffset.y -= offset.height / coordinateSystem.zoomScale
    }

    // MARK: - Private

    private func updateActiveStroke() {
        activeStroke = strokeBuilder.currentStroke
    }

    private func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for point in points {
            minX = min(minX, point.x); minY = min(minY, point.y)
            maxX = max(maxX, point.x); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - StrokeBuilder

/// Builds a single stroke from sequential InkPoints.
public class StrokeBuilder {
    private var points: [InkPoint] = []
    private var predictedPoints: [InkPoint] = []
    private var toolType: ToolType = .fountainPen
    private var color: PlatformColor = .black
    private var width: CGFloat = 2.0

    public var currentStroke: Stroke? {
        guard !points.isEmpty else { return nil }
        return Stroke(
            id: UUID(),
            points: points + predictedPoints,
            toolType: toolType,
            color: color,
            width: width
        )
    }

    public func beginStroke(at point: InkPoint, tool: ToolType, color: PlatformColor, width: CGFloat) {
        points = [point]
        predictedPoints = []
        toolType = tool
        self.color = color
        self.width = width
    }

    public func appendPoint(_ point: InkPoint) {
        points.append(point)
        // Clear predicted points when we get a real point
        predictedPoints.removeAll()
    }

    public func appendPredictedPoint(_ point: InkPoint) {
        predictedPoints.append(point)
    }

    public func endStroke(excludePredicted: Bool = false) -> Stroke {
        let allPoints = excludePredicted ? points : points + predictedPoints
        let stroke = Stroke(
            id: UUID(),
            points: allPoints,
            toolType: toolType,
            color: color,
            width: width
        )
        points = []
        predictedPoints = []
        return stroke
    }

    public func cancelStroke() {
        points = []
        predictedPoints = []
    }
}

// MARK: - InscribeUndoManager

/// Alias for Inscribe's undo manager tied to canvas operations.
public class InscribeUndoManager {
    private let manager = UndoManager(maxUndoCount: 500)

    public func registerUndo(_ action: UndoableAction) {
        manager.registerUndo(action)
    }

    public func undo() throws {
        try manager.undo()
    }

    public func redo() throws {
        try manager.redo()
    }

    public var canUndo: Bool { manager.canUndo }
    public var canRedo: Bool { manager.canRedo }
    public var undoLabel: String? { manager.undoLabel }
    public var redoLabel: String? { manager.redoLabel }
}
