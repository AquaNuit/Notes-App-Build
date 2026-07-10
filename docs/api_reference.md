# Inscribe — API Reference

> This document defines the public protocol interfaces and key type signatures for Inscribe modules. These are the contracts between modules that must remain stable.

---

## 1. Core Module

### TouchEngine

```swift
/// Processes raw UITouch events into InkPoints for stroke building.
protocol TouchProcessing {
    func process(touch: UITouch, in view: UIView) -> InkPoint
    func process(coalescedTouches touches: [UITouch], in view: UIView) -> [InkPoint]
    func process(predictedTouches touches: [UITouch], in view: UIView) -> [InkPoint]
}

/// Classifies touch type for palm rejection.
protocol PalmRejecting {
    func classify(touch: UITouch) -> TouchClassification
    func setPalmRejectionSensitivity(_ sensitivity: PalmRejectionSensitivity)
}

enum TouchClassification {
    case pencil
    case finger
    case palm
}

enum PalmRejectionSensitivity {
    case low
    case medium
    case high
}
```

### Stroke Pipeline

```swift
/// Builds strokes from input points with interpolation and smoothing.
protocol StrokeBuilding {
    func beginStroke(at point: InkPoint, tool: ToolType, color: PlatformColor, width: CGFloat)
    func appendPoint(_ point: InkPoint)
    func appendPredictedPoints(_ points: [InkPoint])
    func endStroke() -> Stroke
    func cancelStroke()
}

struct InkPoint: Codable, Equatable {
    var location: CGPoint
    var pressure: CGFloat        // 0.0 - 1.0
    var azimuth: CGFloat         // radians
    var altitude: CGFloat        // radians
    var roll: CGFloat?           // radians, Pencil Pro only
    var velocity: CGFloat        // points/second
    var timestamp: TimeInterval
}

struct Stroke: Identifiable, Codable {
    var id: UUID
    var points: [InkPoint]
    var toolType: ToolType
    var color: PlatformColor
    var width: CGFloat
    var transform: CGAffineTransform
    var bounds: CGRect
    var creationDate: Date
}

enum ToolType: String, Codable, CaseIterable {
    case fountainPen
    case pencil
    case marker
    case highlighter
    case brush
    case calligraphy
    case eraserPixel
    case eraserStroke
    case lasso
}
```

### Undo Manager

```swift
protocol UndoManaging: AnyObject {
    func registerUndo(_ action: any UndoableAction)
    func undo() throws
    func redo() throws
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    var undoCount: Int { get }
    var redoCount: Int { get }
    func beginUndoGroup(_ label: String)
    func endUndoGroup()
    func removeAll()
}

protocol UndoableAction {
    var label: String { get }
    func undo() throws
    func redo() throws
}
```

---

## 2. Rendering Module

### Metal Renderer

```swift
/// Core rendering interface for the Metal canvas.
protocol CanvasRendering {
    func setup(with metalDevice: MTLDevice, drawableSize: CGSize)
    func render(strokes: [Stroke], viewport: CGRect, scale: CGFloat) -> MTLRenderPassDescriptor?
    func render(activeStroke: Stroke?) -> MTLRenderPassDescriptor?
    func commit()
    func invalidate()
}

/// Brush engine defines how strokes are rendered.
protocol BrushRendering {
    var brushType: ToolType { get }
    func generateVertices(for stroke: Stroke, scale: CGFloat) -> MetalStrokeGeometry
    func pipelineState(for device: MTLDevice) -> MTLRenderPipelineState
    func texture(for device: MTLDevice) -> MTLTexture?
}

struct MetalStrokeGeometry {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var vertexCount: Int
    var indexCount: Int
    var bounds: CGRect
}
```

### Stroke Cache

```swift
protocol StrokeCaching {
    func cache(_ geometry: MetalStrokeGeometry, for strokeID: UUID)
    func cachedGeometry(for strokeID: UUID) -> MetalStrokeGeometry?
    func removeCachedGeometry(for strokeID: UUID)
    func removeAll()
    var memoryUsage: ByteCount { get }
}
```

---

## 3. Pencil Module

```swift
protocol PencilInteractionHandling {
    func handleSqueeze(_ interaction: UIPencilInteraction)
    func handleDoubleTap(_ interaction: UIPencilInteraction)
    func setDoubleTapShortcut(_ shortcut: PencilShortcut)
}

enum PencilShortcut: String, CaseIterable {
    case toggleEraser
    case undo
    case redo
    case showColorPicker
    case toggleToolPalette
    case showLaserPointer
    case none
}

protocol PressureCurveProviding {
    func mapPressure(_ rawPressure: CGFloat) -> CGFloat
    var curveType: PressureCurveType { get }
}

enum PressureCurveType: String, CaseIterable {
    case linear
    case logarithmic
    case exponential
    case custom
}

protocol HoverProviding {
    func hoverLocation(in view: UIView) -> CGPoint?
    func isHovering -> Bool
    func setHoverPreviewEnabled(_ enabled: Bool)
}
```

---

## 4. Documents Module

```swift
protocol NotebookManaging {
    func createNotebook(title: String, template: TemplateType) async throws -> NotebookModel
    func deleteNotebook(_ id: UUID) async throws
    func renameNotebook(_ id: UUID, title: String) async throws
    func fetchNotebooks(sortedBy: SortDescriptor) async throws -> [NotebookModel]
    func fetchNotebook(_ id: UUID) async throws -> NotebookModel?
    func archiveNotebook(_ id: UUID) async throws
    func addTag(_ tagID: UUID, to notebookID: UUID) async throws
    func removeTag(_ tagID: UUID, from notebookID: UUID) async throws
}

protocol PageManaging {
    func createPage(in notebookID: UUID, title: String?) async throws -> PageModel
    func deletePage(_ id: UUID) async throws
    func movePage(_ id: UUID, to notebookID: UUID, at index: Int) async throws
    func duplicatePage(_ id: UUID) async throws -> PageModel
    func fetchPages(in notebookID: UUID) async throws -> [PageModel]
}
```

---

## 5. Storage Module

```swift
protocol StrokePersisting {
    func saveStroke(_ stroke: Stroke, for pageID: UUID) async throws
    func loadStrokes(for pageID: UUID) async throws -> [Stroke]
    func loadStrokeMetadata(for pageID: UUID) async throws -> [StrokeMetadataModel]
    func deleteStroke(_ strokeID: UUID, for pageID: UUID) async throws
    func loadStrokeData(path: String) async throws -> Data
}

protocol MediaPersisting {
    func saveImage(_ imageData: Data, name: String) async throws -> URL
    func loadImage(url: URL) async throws -> Data
    func saveRecording(_ audioData: Data, name: String) async throws -> URL
    func deleteMedia(at url: URL) async throws
}
```

---

## 6. Sync Module

```swift
protocol SyncEngine {
    var syncState: SyncState { get async }
    func startSync() async
    func stopSync() async
    func forceSync() async throws
    func enqueueChange(_ change: SyncChange) async
}

struct SyncChange {
    var id: UUID
    var entityType: String
    var entityID: UUID
    var changeType: ChangeType
    var timestamp: Date
    var data: Data
}

enum ChangeType: String {
    case create
    case update
    case delete
}

enum SyncState {
    case idle
    case syncing(progress: Double)
    case paused
    case error(SyncError)
}
```

---

## 7. Search Module

```swift
protocol Searchable {
    var searchableText: String { get }
    var searchableTags: [String] { get }
}

protocol SearchIndexing {
    func indexItem(_ item: any Searchable) async
    func removeItem(id: UUID) async
    func search(query: String, options: SearchOptions) async throws -> [SearchResult]
    func reindexAll() async
}

struct SearchResult: Identifiable {
    var id: UUID
    var title: String
    var snippet: String
    var pageID: UUID
    var notebookID: UUID
    var notebookTitle: String
    var relevance: Double
    var type: SearchResultType
}

enum SearchResultType {
    case title
    case handwriting
    case pdfText
    case tag
    case ocr
}
```

---

## 8. AI Bridge

```swift
/// Protocol for handwriting recognition providers (on-device or cloud).
protocol HandwritingRecognizing {
    func recognize(strokes: [Stroke]) async throws -> RecognizedText
    func supportedLanguages() -> [String]
}

struct RecognizedText {
    var segments: [TextSegment]
    var confidence: Float
}

struct TextSegment {
    var text: String
    var boundingRect: CGRect
    var confidence: Float
}

/// Protocol for shape classification.
protocol ShapeClassifying {
    func classify(strokes: [Stroke]) async throws -> ShapeClassification
}

enum ShapeClassification {
    case line
    case circle
    case ellipse
    case rectangle
    case triangle
    case star
    case arrow
    case unknown
    case partial(shape: ShapeClassification, confidence: Float)
}
```

---

## 9. App State Protocols

```swift
/// Global app state accessible via Environment.
@Observable
final class AppState {
    var currentNotebookID: UUID?
    var currentPageID: UUID?
    var activeTool: ToolType
    var activeColor: PlatformColor
    var strokeWidth: CGFloat
    var isSidebarVisible: Bool
    var isToolPaletteVisible: Bool
    var darkModeEnabled: Bool
    var syncStatus: SyncState
}
```

---

## Versioning

This API reference follows the project's version. Breaking changes to public protocols must be reflected in:

1. This document
2. `docs/changelog.md`
3. New ADR in `docs/decisions.md`
