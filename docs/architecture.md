# Inscribe — Architecture Document

## Project Overview

**Inscribe** is a production-grade handwritten note-taking application for iPad with full Apple Pencil support. The application combines an infinite canvas, advanced handwriting engine, notebook organization, PDF annotation, and future-ready AI capabilities into a single, fast, offline-first native iPadOS app.

---

## 1. System Architecture

### 1.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Application Layer                           │
│  ┌──────────┐  ┌────────┐  ┌──────────┐  ┌──────────┐  ┌───────┐  │
│  │Notebook  │  │ PDF    │  │ Settings │  │ Onboarding│  │Share  │  │
│  │Browser   │  │ Viewer │  │          │  │          │  │Sheet  │  │
│  └────┬─────┘  └───┬────┘  └────┬─────┘  └────┬─────┘  └───┬───┘  │
│       └────────────┼────────────┼──────────────┼────────────┘      │
│                    │            │              │                    │
├────────────────────┼────────────┼──────────────┼───────────────────┤
│              Feature Layer       │                                  │
│  ┌──────────┐  ┌────────┐  ┌──────────┐  ┌──────────┐  ┌───────┐  │
│  │ Canvas   │  │ Pencil │  │ Document │  │ Search   │  │ Sync  │  │
│  │ Engine   │  │ Engine │  │ Manager  │  │ Engine   │  │Engine │  │
│  └────┬─────┘  └───┬────┘  └────┬─────┘  └────┬─────┘  └───┬───┘  │
│       │            │            │              │            │      │
├───────┼────────────┼────────────┼──────────────┼────────────┼──────┤
│              Core Layer                                            │
│  ┌──────────┐  ┌────────┐  ┌──────────┐  ┌──────────┐  ┌───────┐  │
│  │Rendering │  │ Touch  │  │ Storage  │  │ Undo/Redo│  │ AI    │  │
│  │Engine    │  │Engine  │  │Engine    │  │ Engine   │  │Bridge │  │
│  └────┬─────┘  └───┬────┘  └────┬─────┘  └────┬─────┘  └───┬───┘  │
│       │            │            │              │            │      │
├───────┼────────────┼────────────┼──────────────┼────────────┼──────┤
│              Frameworks Layer                                       │
│  ┌──────────┐  ┌────────┐  ┌──────────┐  ┌──────────┐         │   │
│  │  Metal   │  │Pencil- │  │ SwiftData │  │ CloudKit │         │   │
│  │          │  │ Kit    │  │ /CoreData │  │          │         │   │
│  └──────────┘  └────────┘  └──────────┘  └──────────┘         │   │
│  ┌──────────┐  ┌────────┐  ┌──────────┐                         │   │
│  │  PDFKit  │  │ Vision │  │ Core     │                         │   │
│  │          │  │        │  │ ML       │                         │   │
│  └──────────┘  └────────┘  └──────────┘                         │   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Layer Responsibilities

| Layer | Responsibility |
|-------|---------------|
| **Application** | Window management, scene delegates, app lifecycle, root navigation |
| **Feature** | Feature-level orchestration: canvas sessions, notebook browsing, PDF viewing, search, settings |
| **Core** | Low-level engines: ink rendering, touch processing, data persistence, undo management, AI bridge |
| **Frameworks** | Apple system frameworks abstracted behind protocol interfaces |

### 1.3 Dependency Direction

```
Application → Feature → Core → Frameworks
```

No layer depends on a layer above it. All cross-cutting concerns (logging, metrics, crash reporting) are injected via protocols.

---

## 2. MVVM + Coordinator Architecture

### 2.1 Architecture Pattern

Inscribe uses **MVVM + Coordinator** with SwiftUI as the primary view layer and UIKit integration where necessary.

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  View    │◄────│ ViewModel│◄────│  Model   │◄────│ Services │
│ (SwiftUI)│     │ (Observ- │     │ (Swift   │     │ (Net-    │
│          │     │  ableObj)│     │  Structs)│     │  work,   │
│          │     │          │     │          │     │  DB, etc)│
└──────────┘     └──────────┘     └──────────┘     └──────────┘
       │                │
       │                │
       ▼                ▼
┌──────────┐     ┌──────────┐
│Coordinator│    │  Router  │
│(Navigation)│   │ (Sheet,  │
│           │    │  Push)   │
└──────────┘     └──────────┘
```

### 2.2 Data Flow

1. User touches canvas → TouchEngine processes raw `UITouch` events
2. TouchEngine produces `InkPoint` values → sends to StrokeBuilder
3. StrokeBuilder constructs `Stroke` model with pressure, tilt, roll data
4. Stroke is sent to MetalRenderer for immediate display on dynamic layer
5. Stroke is finalized and persisted via StrokeStore → SwiftData / file storage
6. Model change propagates via Combine → ViewModel → View updates

---

## 3. Module Breakdown

### App Module
```
App/
├── InscribeApp.swift              # @main entry point
├── InscribeSceneDelegate.swift    # Scene-based configuration
├── InscribeAppDelegate.swift      # App delegate callbacks
├── AppCoordinator.swift           # Root navigation coordinator
└── AppDependencyContainer.swift   # DI container
```

**Responsibility:** Application lifecycle, window/scene management, root DI container setup.

### Core Module
```
Core/
├── TouchEngine/
│   ├── TouchEngine.swift          # Raw UITouch → InkPoint processor
│   ├── TouchPredictor.swift       # Predicted touch generation
│   ├── PalmRejectionFilter.swift  # Palm rejection algorithm
│   └── TouchCoalescer.swift       # Coalesced touch merging
├── UndoManager/
│   ├── UndoManager.swift          # Grouped undo/redo with stroke granularity
│   ├── UndoableAction.swift       # Action protocol for undoable operations
│   └── UndoGroup.swift            # Transaction grouping
├── Geometry/
│   ├── InkPoint.swift             # Point with pressure, tilt, roll, velocity
│   ├── Stroke.swift               # Complete stroke model
│   ├── BezierPathBuilder.swift    # Catmull-Rom → Cubic Bézier conversion
│   └── ShapeRecognizer.swift      # Classification of strokes into shapes
├── CoordinateSpace/
│   ├── CanvasCoordinateSystem.swift # Canvas space ↔ Screen space transforms
│   └── PageCoordinateSystem.swift   # Page-relative coordinate transforms
└── PredictionEngine/
    ├── StrokePredictor.swift      # ML-based stroke continuation
    └── KalmanFilter.swift         # Kalman filter for touch smoothing
```

### Canvas Module
```
Canvas/
├── InfiniteCanvas/
│   ├── InfiniteCanvasView.swift           # SwiftUI container for canvas
│   ├── InfiniteCanvasController.swift     # UIKit bridge for PencilKit
│   ├── CanvasViewModel.swift              # Canvas state management
│   ├── CanvasInteractionHandler.swift     # Gesture + Pencil interaction router
│   └── CanvasFocusManager.swift           # Auto-scroll, auto-zoom behavior
├── LayerManager/
│   ├── CanvasLayerManager.swift           # Management of rendering layers
│   ├── StrokeLayer.swift                  # Completed strokes layer
│   ├── ActiveStrokeLayer.swift            # Currently drawing stroke
│   ├── SelectionLayer.swift               # Lasso selection overlay
│   └── GridLayer.swift                    # Background grid rendering
├── BackgroundRenderer/
│   ├── BackgroundRendererView.swift       # Grid/dot/music/graph backgrounds
│   ├── TemplateManager.swift              # Custom template loading
│   └── BackgroundRenderer.swift           # Efficient background compositing
├── ZoomManager/
│   ├── CanvasZoomController.swift         # Zoom state + constraints
│   ├── ZoomGestureHandler.swift           # Pinch-to-zoom with UIKit
│   └── ZoomLevelIndicator.swift           # Current zoom level UI
└── PanGestureHandler/
    ├── CanvasPanController.swift          # Pan state + momentum
    └── InfiniteScrollController.swift     # Boundaryless scrolling
```

### Rendering Module
```
Rendering/
├── MetalRenderer/
│   ├── MetalRenderer.swift                # Metal setup, command queue, pipeline
│   ├── MetalCanvasView.swift              # MTKView wrapper for canvas
│   ├── Shaders.metal                      # Vertex + fragment shaders for ink
│   ├── InkRenderPipeline.swift            # Pipeline state configuration
│   └── RenderTargetManager.swift          # Double-buffered render targets
├── InkPipeline/
│   ├── InkPipeline.swift                  # Stroke → GPU geometry pipeline
│   ├── StrokeVertexGenerator.swift        # Stroke point → triangle strip
│   ├── InkShaderTypes.h                   # Shared Metal types (Swift/C)
│   └── VariableWidthInk.swift             # Pressure → width mapping
├── BrushEngine/
│   ├── BrushEngine.swift                  # Brush property calculator
│   ├── BrushDefinition.swift              # Brush parameter model
│   ├── FountainPenBrush.swift             # Fountain pen simulation
│   ├── PencilBrush.swift                  # Pencil texture simulation
│   ├── MarkerBrush.swift                  # Marker with opacity buildup
│   ├── HighlighterBrush.swift             # Translucent highlighter
│   ├── BrushBrush.swift                   # Paint brush with bristle simulation
│   └── CalligraphyPenBrush.swift          # Angle-dependent width
├── StrokeCache/
│   ├── StrokeCache.swift                  # LRU cache for rendered strokes
│   ├── TileCache.swift                    # Spatial tile-based caching
│   └── StrokeGrouper.swift               # Batch strokes for draw calls
└── TextureAtlas/
    ├── TextureAtlas.swift                 # Atlas for brush textures
    └── TextureGenerator.swift             # Procedural texture generation
```

### Pencil Module
```
Pencil/
├── PencilInteraction/
│   ├── PencilInteractionController.swift   # UIPencilInteraction setup
│   ├── SqueezeHandler.swift               # Pencil Pro squeeze gesture
│   ├── DoubleTapHandler.swift             # Double-tap shortcut router
│   └── BarrelRollHandler.swift            # Roll-aware brush logic
├── PressureCurve/
│   ├── PressureCurveController.swift       # Custom pressure response curves
│   ├── LinearPressureCurve.swift
│   ├── LogarithmicPressureCurve.swift
│   └── CustomPressureCurve.swift          # User-defined curve
├── TiltHandler/
│   ├── TiltShadingEngine.swift            # Altitude/azimuth shading
│   └── TiltSmoother.swift                 # Tilt noise reduction
├── HoverManager/
│   ├── HoverPreviewController.swift        # Hover cursor/preview rendering
│   └── HoverTooltipManager.swift           # Contextual info on hover
└── ToolPickerCustomization/
    ├── CustomToolProvider.swift            # PKToolPicker custom tool registration
    ├── CustomToolDefinition.swift          # Custom tool metadata
    └── ToolPaletteConfiguration.swift      # Palette layout + ordering
```

### Documents Module
```
Documents/
├── Notebook/
│   ├── Notebook.swift                     # Notebook model
│   ├── NotebookManager.swift              # CRUD + fetch operations
│   └── NotebookViewModel.swift
├── Page/
│   ├── Page.swift                         # Page model
│   ├── PageManager.swift                  # Page CRUD + reordering
│   └── PageViewModel.swift
├── Section/
│   ├── Section.swift                      # Section model (group within notebook)
│   └── SectionManager.swift
├── Tagging/
│   ├── Tag.swift                          # Tag model
│   ├── TagManager.swift                   # Tag CRUD + assignment
│   └── TagColorPicker.swift               # Tag color selection UI
├── SmartCollections/
│   ├── SmartCollection.swift              # Smart collection rule model
│   ├── SmartCollectionEngine.swift        # Rule evaluation engine
│   └── SmartCollectionViewModel.swift
└── TemplateSystem/
    ├── Template.swift                     # Template model
    ├── TemplateManager.swift              # Built-in + custom template mgmt
    └── TemplatePickerView.swift           # Template selection UI
```

### PDF Module
```
PDF/
├── PDFImport/
│   ├── PDFImportService.swift             # PDF file import pipeline
│   ├── PDFParser.swift                    # Page extraction, metadata
│   └── PDFThumbnailGenerator.swift        # Thumbnail for browser
├── PDFAnnotation/
│   ├── PDFAnnotationView.swift            # PDF + drawing overlay
│   ├── PDFAnnotationController.swift      # UIKit PDFView + PKCanvasView bridge
│   ├── PDFHighlightHandler.swift          # Text highlight extraction
│   └── PDFNoteAnchor.swift                # Handwritten note anchoring
├── PDFExport/
│   ├── PDFExportService.swift             # Annotated PDF export
│   ├── PDFRenderOptions.swift             # Quality, compression settings
│   └── PDFPrintFormatter.swift            # AirPrint support
└── PDFMergeSplit/
    ├── PDFMerger.swift                    # Multi-PDF merging
    ├── PDFSplitter.swift                  # Page range extraction
    └── PDFReorderView.swift              # Drag-to-reorder pages
```

### Storage Module
```
Storage/
├── SwiftDataModels/
│   ├── NotebookModel.swift                # SwiftData @Model for notebooks
│   ├── PageModel.swift                    # SwiftData @Model for pages
│   ├── StrokeModel.swift                  # SwiftData @Model for stroke metadata
│   ├── TagModel.swift                     # SwiftData @Model for tags
│   └── ModelActor.swift                   # @ModelActor for background operations
├── FileManager/
│   ├── StrokeFileManager.swift            # Stroke data file I/O
│   ├── MediaFileManager.swift             # Image/audio/video file storage
│   ├── TemplateFileManager.swift          # Template file management
│   └── TemporaryFileManager.swift         # Temp file cleanup
├── CacheManager/
│   ├── DiskCache.swift                    # LRU disk cache
│   ├── MemoryCache.swift                  # NSCache-backed memory cache
│   ├── ThumbnailCache.swift               # Page thumbnail cache
│   └── TileCacheManager.swift             # Render tile cache
└── BackupManager/
    ├── BackupManager.swift                # Manual + automatic backup
    └── RestoreManager.swift               # Backup restore from iCloud/local
```

### Sync Module
```
Sync/
├── CloudKitSync/
│   ├── CloudKitSyncEngine.swift           # Core sync engine
│   ├── CloudKitContainer.swift            # CKContainer setup
│   ├── RecordMapper.swift                 # SwiftData → CKRecord mapping
│   └── SyncZoneManager.swift              # Custom zone management
├── ConflictResolver/
│   ├── ConflictResolver.swift             # Last-write-wins / 3-way merge
│   ├── ConflictResolutionStrategy.swift   # Resolution strategy protocol
│   └── ConflictResolutionView.swift       # User-facing conflict UI
├── BackgroundSync/
│   ├── BackgroundSyncManager.swift        # BGTaskScheduler integration
│   ├── SyncOperation.swift                # NSOperation-based sync task
│   └── SyncStatePersister.swift           # Sync cursor persistence
└── StateMachine/
    ├── SyncStateMachine.swift             # State machine for sync lifecycle
    └── SyncEvent.swift                    # Sync event definitions
```

### Search Module
```
Search/
├── FullTextSearch/
│   ├── SearchIndexEngine.swift            # SQLite FTS5 index
│   ├── SearchQueryParser.swift            # Natural language query parsing
│   ├── SearchResult.swift                 # Search result model
│   └── SearchViewModel.swift
├── IndexManager/
│   ├── IndexManager.swift                 # Background index management
│   ├── IndexScheduler.swift               # Prioritized indexing queue
│   └── IndexStats.swift                   # Index health monitoring
└── OCRManager/
    ├── OCRManager.swift                   # Vision framework OCR wrapper
    ├── OCRProcessor.swift                 # Text extraction from strokes/PDF
    └── OCRCache.swift                     # OCR result caching
```

### UI Module
```
UI/
├── Sidebar/
│   ├── SidebarView.swift                  # Primary sidebar navigation
│   ├── SidebarViewModel.swift
│   ├── NotebookTreeView.swift             # Hierarchical notebook list
│   └── SidebarSearchBar.swift             # Quick search in sidebar
├── ToolPalette/
│   ├── FloatingToolPalette.swift          # Floating tool picker
│   ├── ToolPaletteViewModel.swift
│   ├── ToolButton.swift                   # Individual tool button
│   ├── ColorPickerPopover.swift           # Color selection
│   ├── StrokeWidthPicker.swift            # Width/opacity controls
│   └── ToolShortcutBar.swift              # Quick-switch favorites
├── InspectorPanel/
│   ├── InspectorPanelView.swift           # Right-side inspector
│   ├── StrokeInspector.swift              # Selected stroke properties
│   ├── PageInspector.swift                # Page background, size
│   └── LayerInspector.swift              # Layer visibility, order
├── NotebookBrowser/
│   ├── NotebookGalleryView.swift          # Gallery grid of notebooks
│   ├── NotebookListView.swift             # List view with details
│   └── NotebookSortFilter.swift           # Sort/filter controls
├── CanvasOverlay/
│   ├── CanvasOverlayView.swift            # HUD overlays on canvas
│   ├── ZoomIndicator.swift                # Zoom level display
│   ├── PageIndicator.swift                # Page number indicator
│   └── UndoRedoButtons.swift              # Undo/redo popover
└── Modals/
    ├── ShareSheet.swift                   # System share sheet wrapper
    ├── ImportSheet.swift                  # File import picker
    ├── ExportOptionsView.swift            # Export format selection
    └── CreateNotebookSheet.swift          # New notebook creation
```

### Components Module
```
Components/
├── InkWell.swift                          # Custom button with ink ripple
├── ColorPicker.swift                      # HSB + palette color picker
├── StrokeWidthSlider.swift                # Custom slider for stroke width
├── ToolButton.swift                       # Styled tool selection button
├── PageThumbnail.swift                    # Draggable page thumbnail
├── NotebookCell.swift                     # Notebook preview in lists
├── PDFThumbnail.swift                     # PDF page thumbnail
├── LoadingState.swift                     # Loading placeholder
└── EmptyState.swift                       # Empty content placeholder
```

### Settings Module
```
Settings/
├── Preferences/
│   ├── PreferencesView.swift              # General preferences
│   ├── PreferencesViewModel.swift
│   ├── AppearanceSettings.swift           # Dark mode, accent color
│   ├── EditorSettings.swift               # Default tool, auto-advance
│   └── GestureSettings.swift              # Gesture customization
├── PencilSettings/
│   ├── PencilSettingsView.swift           # Pencil-specific settings
│   ├── PressureCurveEditor.swift          # Visual curve editor
│   ├── DoubleTapShortcutPicker.swift      # Shortcut assignment
│   └── PalmRejectionSettings.swift        # Palm rejection sensitivity
├── CloudSettings/
│   ├── CloudSettingsView.swift            # iCloud sync settings
│   ├── SyncStatusView.swift               # Current sync state
│   └── StorageManagement.swift            # Local vs cloud storage
└── AISettings/
    ├── AISettingsView.swift               # AI feature toggles
    ├── ModelManagement.swift              # Model download management
    └── PrivacySettings.swift              # On-device vs cloud processing
```

### Extensions Module
```
Extensions/
├── CGPoint+Extensions.swift               # Distance, interpolation, transform
├── UIColor+Extensions.swift               # Hex, HSB access, blending
├── UIView+Extensions.swift                # Constraints, shadow, border
├── CGRect+Extensions.swift                # Center, aspect-fit, union
├── UIImage+Extensions.swift               # Resize, compress, tint
├── Data+Extensions.swift                  # Hex dump, checksum
└── Date+Extensions.swift                  # Relative formatting, ISO 8601
```

### Utilities Module
```
Utilities/
├── Logger.swift                           # Unified logging (os.log)
├── PerformanceMonitor.swift               # FPS, memory, CPU monitoring
├── FileSizeFormatter.swift                 # Human-readable file sizes
├── MemoryWarningHandler.swift              # Memory pressure response
├── BackgroundTaskManager.swift             # BGTaskScheduler registration
└── HapticManager.swift                     # Haptic feedback wrapper
```

---

## 4. State Management Strategy

### 4.1 State Layers

```
┌────────────────────────────────────────────┐
│              App State (Global)            │
│  - Current notebook/page                   │
│  - Active tool                              │
│  - Active color/width                       │
│  - Sync status                              │
│  - Settings                                 │
├────────────────────────────────────────────┤
│           Canvas State (Session)           │
│  - Zoom level, pan offset                   │
│  - Visible strokes (spatial query)          │
│  - Active stroke (while drawing)            │
│  - Selection state                          │
│  - Cursor position                          │
├────────────────────────────────────────────┤
│           Document State (Persistent)      │
│  - Strokes (in SwiftData + file storage)    │
│  - Page metadata                            │
│  - Notebook hierarchy                       │
│  - Tags, favorites, archive                 │
│  - Index entries                            │
├────────────────────────────────────────────┤
│           Sync State (Background)          │
│  - Sync queue                               │
│  - Conflict status                          │
│  - Last sync timestamp                      │
│  - Pending changes count                    │
└────────────────────────────────────────────┘
```

### 4.2 State Management Tools

| State Type | Tool | Rationale |
|-----------|------|-----------|
| Global App State | `@Observable` classes (iOS 17+) / `ObservableObject` | Shared via SwiftUI Environment |
| Canvas Session | `CanvasViewModel` (`@Observable`) | High-frequency updates, Combine publishers |
| Persistent Data | SwiftData `@Model` + `@Query` | Reactive UI updates from DB changes |
| Sync State | `SyncStateMachine` (actor) | Thread-safe state transitions |

### 4.3 Data Flow for Drawing

```
User Touch → TouchEngine.process(touch)
  → TouchPredictor.predict(touchPoints)
  → PalmRejectionFilter.classify(touch)
    → [If palm] → discard
    → [If pencil] → continue
  → StrokeBuilder.append(InkPoint)
    → ActiveStrokeLayer.update(partiallyRenderedStroke)
      → MetalRenderer.render(partialStroke) → display
    → [On touch end]
      → Stroke finalization
        → StrokeCache.store(stroke)
        → StrokeFileManager.write(strokeData)
        → SwiftData.save(strokeMetadata)
        → SearchIndexManager.index(stroke)
        → SyncEngine.enqueue(change)
        → UndoManager.register(undoAction)
        → CanvasViewModel.notifyStrokeAdded()
```

---

## 5. Rendering Architecture

### 5.1 Dual-Layer Rendering

```
┌─────────────────────────────────────────────────────────────┐
│                    MTKView (Full Screen)                    │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Static Layer (Background)                │  │
│  │  - Completed strokes (rendered once per change)        │  │
│  │  - Grid backgrounds, templates                         │  │
│  │  - PDF page content                                    │  │
│  │  - Cached in off-screen render target                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Dynamic Layer (Foreground)               │  │
│  │  - Active stroke being drawn                           │  │
│  │  - Lasso selection border                              │  │
│  │  - Hover cursor/preview                                │  │
│  │  - Redrawn every frame during drawing                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              UI Overlay Layer                          │  │
│  │  - Tool palette (PKToolPicker / SwiftUI)               │  │
│  │  - Zoom indicator, page indicator                      │  │
│  │  - Context menus, popovers                             │  │
│  │  - SwiftUI overlay on MTKView                          │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Rendering Pipeline

```
Stroke Points
    │
    ▼
StrokeVertexGenerator
    ├── Apply Catmull-Rom spline interpolation
    ├── Apply pressure → width mapping (per brush)
    ├── Apply tilt → offset/shading mapping
    ├── Generate triangle strip vertices
    └── Output: MTLBuffer of vertices
    │
    ▼
InkRenderPipeline
    ├── Bind brush texture from TextureAtlas
    ├── Set blend mode (normal, multiply, additive)
    ├── Set pipeline state for brush type
    └── Encode draw call
    │
    ▼
MetalRenderer.commit()
    ├── Encode to command buffer
    ├── Present to drawable
    └── Call completion handler
```

### 5.3 Metal Shader Overview

```
// Vertex Shader: InkVertexShader
// - Transforms canvas-space vertices to screen space
// - Passes texture coordinates + alpha to fragment shader

// Fragment Shader: InkFragmentShader
// - Samples brush texture
// - Applies pressure-based alpha
// - Applies tilt-based shading
// - Outputs final fragment color with blending

// Fragment Shader: EraserFragmentShader
// - Discards fragments based on brush shape intersection
// - Works in both pixel-erase and stroke-erase modes
```

---

## 6. Data Model (SwiftData)

```swift
// Core Models

@Model
final class NotebookModel {
    var id: UUID
    var title: String
    var creationDate: Date
    var modificationDate: Date
    var iconName: String?
    var colorLabel: String?       // Hex color
    var isArchived: Bool
    var isFavorite: Bool
    var sortOrder: Int
    
    @Relationship(.cascade) var sections: [SectionModel]
    @Relationship(.cascade) var pages: [PageModel]
    @Relationship var tags: [TagModel]
}

@Model
final class SectionModel {
    var id: UUID
    var title: String
    var creationDate: Date
    var sortOrder: Int
    var notebook: NotebookModel?
    
    @Relationship(.cascade) var pages: [PageModel]
}

@Model
final class PageModel {
    var id: UUID
    var title: String?
    var creationDate: Date
    var modificationDate: Date
    var sortOrder: Int
    var backgroundType: String    // "grid", "dot", "blank", "music", "graph"
    var pageSize: String          // "A4", "USLetter", "infinite"
    var isTemplate: Bool
    
    var notebook: NotebookModel?
    var section: SectionModel?
    
    // Stroke data stored on disk, metadata only in SwiftData
    var strokeCount: Int
    var strokeDataPath: String?   // File path to encoded strokes
    var thumbnailPath: String?
    
    var tags: [TagModel]
}

@Model
final class TagModel {
    var id: UUID
    var name: String
    var colorHex: String
    var creationDate: Date
    
    @Relationship(inverse: \NotebookModel.tags) var notebooks: [NotebookModel]
    @Relationship(inverse: \PageModel.tags) var pages: [PageModel]
}

@Model
final class StrokeMetadataModel {
    var id: UUID
    var pageID: UUID
    var toolType: String          // "pen", "marker", "highlighter", etc.
    var colorHex: String
    var width: Double
    var boundsMinX: Double
    var boundsMinY: Double
    var boundsMaxX: Double
    var boundsMaxY: Double
    var creationDate: Date
    var sortOrder: Int
    var isVisible: Bool
}
```

### 6.1 Stroke Data Encoding (On-Disk Format)

Strokes are serialized using a custom binary format for performance:

```
┌─────────────────────────────────┐
│ Header (32 bytes)               │
│ - Magic number: 0x494E4B52     │
│ - Version: UInt16               │
│ - Stroke count: UInt32          │
│ - Total points: UInt32          │
├─────────────────────────────────┤
│ Stroke 1                        │
│ ├── Metadata (56 bytes)         │
│ │   ├── ID: UUID (16)           │
│ │   ├── Tool type: UInt8        │
│ │   ├── Color: UInt32 (RGBA)    │
│ │   ├── Width: Float32          │
│ │   ├── Point count: UInt32     │
│ │   └── Flags: UInt16           │
│ ├── Point Data (N * 20 bytes)   │
│ │   ├── X: Float32              │
│ │   ├── Y: Float32              │
│ │   ├── Pressure: Float32       │
│ │   ├── Azimuth: Float32        │
│ │   ├── Altitude: Float32       │
│ │   └── Roll: Float32 (opt)     │
│ └── Padding (align to 4)        │
├─────────────────────────────────┤
│ Stroke 2...                     │
│ ...                             │
└─────────────────────────────────┘
```

---

## 7. Synchronization Architecture

### 7.1 Sync Architecture Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Device A  │     │   Device B  │     │   Device C  │
│  (iPad)     │     │  (iPad)     │     │  (Mac)      │
│             │     │             │     │             │
│ ┌─────────┐ │     │ ┌─────────┐ │     │ ┌─────────┐ │
│ │Local DB │ │     │ │Local DB │ │     │ │Local DB │ │
│ │(SwiftData)│    │ │(SwiftData)│    │ │(SwiftData)│ │
│ └────┬────┘ │     │ └────┬────┘ │     │ └────┬────┘ │
│      │       │     │      │       │     │      │       │
│ ┌────▼────┐ │     │ ┌────▼────┐ │     │ ┌────▼────┐ │
│ │Sync     │ │     │ │Sync     │ │     │ │Sync     │ │
│ │Engine   │ │     │ │Engine   │ │     │ │Engine   │ │
│ └────┬────┘ │     │ └────┬────┘ │     │ └────┬────┘ │
└──────┼───────┘     └──────┼───────┘     └──────┼───────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                    ┌───────▼───────┐
                    │   CloudKit    │
                    │   Private DB  │
                    │   Custom Zones│
                    └───────────────┘
```

### 7.2 Sync Strategy: Offline-First

1. **All writes go to local storage first** — no network required
2. **Changes tracked via change token** — each mutation increments a local counter
3. **Push on connectivity** — background sync pushes to CloudKit
4. **Pull periodic** — sync engine checks for remote changes
5. **Conflict resolution** — Last-Write-Wins (LWW) with metadata-based merge for non-conflicting changes

### 7.3 Conflict Resolution Algorithm

```swift
enum ConflictResolution {
    case lastWriteWins
    case threeWayMerge
    case userChoice
}

// For strokes: LWW (strokes are additive, no merge needed)
// For page metadata: Three-way merge
// For notebook hierarchy: LWW with parent-child consistency check
// For unresolvable conflicts: UserChoice via conflict notification
```

---

## 8. Performance Architecture

### 8.1 Rendering Performance Targets

| Metric | Target | Method |
|--------|--------|--------|
| Stroke rendering latency | < 8ms | Metal + precomputed geometry |
| Canvas frame rate | 120 FPS | Double-buffered Metal, tile-based rendering |
| Page load time | < 100ms | Progressive loading, spatial indexing |
| Scroll smoothness | 120 FPS | Pre-cached visible tiles |
| Import 100-page PDF | < 2s | Background page extraction, async thumbnail gen |
| Memory (idle) | < 100MB | Aggressive tile eviction, compressed stroke data |

### 8.2 Spatial Indexing

```
┌─────────────────────────────────────────────┐
│             QuadTree Spatial Index          │
│                                             │
│  Root node: Entire canvas (0,0,w,h)         │
│  ├── NW quadrant                            │
│  │   ├── NW-NW                              │
│  │   ├── NW-NE                              │
│  │   ├── NW-SW                              │
│  │   └── NW-SE                              │
│  ├── NE quadrant                            │
│  ├── SW quadrant                            │
│  └── SE quadrant                            │
│                                             │
│  Query: Visible rect → O(log n) retrieval   │
│  Only render strokes in visible quads       │
└─────────────────────────────────────────────┘
```

### 8.3 Memory Management

```swift
// Memory warning response
func handleMemoryWarning() {
    // 1. Flush tile cache (oldest tiles first)
    // 2. Compress recently used tiles
    // 3. Evict undo history beyond recent 50 actions
    // 4. Release offscreen render targets
    // 5. Force SwiftData row cache flush
}
```

---

## 9. Apple Pencil Integration Points

| Feature | API | When |
|---------|-----|------|
| Pressure | `touch.force` / `touch.maximumPossibleForce` | Touch began, moved |
| Tilt | `touch.altitudeAngle` / `touch.azimuthAngle(in:)` | Touch moved |
| Roll (Pencil Pro) | `touch.roll` | Touch moved |
| Hover | `UIHoverGestureRecognizer` / `UITouch.hoverLocation` | Hover began, changed |
| Squeeze (Pencil Pro) | `UIPencilInteraction(.squeeze)` | Interaction received |
| Double-tap | `UIPencilInteraction(.doubleTap)` | Interaction received |
| Predicted touches | `event.predictedTouches(for:)` | Touch moved |
| Coalesced touches | `event.coalescedTouches(for:)` | Touch moved |

---

## 10. AI Bridge Architecture (Future)

```
┌──────────────────────────────────────────────┐
│                 AIBridge                      │
│  Protocol-oriented abstraction layer          │
│                                               │
│  Protocols:                                   │
│  ├── HandwritingRecognizing                   │
│  ├── ShapeClassifying                         │
│  ├── MathSolving                              │
│  ├── TextSummarizing                          │
│  ├── SmartSearching                           │
│  └── DiagramCleaning                          │
│                                               │
│  Implementations:                             │
│  ├── VisionFrameworkOCR (on-device)           │
│  ├── CoreMLModel (on-device)                  │
│  ├── RemoteAIService (cloud)                  │
│  └── HybridEngine (on-device + cloud)         │
└──────────────────────────────────────────────┘
```

---

## 11. Testing Strategy

### 11.1 Test Pyramid

```
        ┌──────────┐
        │  UI Tests │  ← XCUITest, accessibility identifiers
       /│   (E2E)   │\
      / └──────────┘ \
     / ┌──────────────┐\
    /  │Integration   │  ← Stroke pipeline, sync, PDF import
   /   │   Tests      │\
  /    └──────────────┘ \
 /     ┌────────────────┐\
│      │  Unit Tests    │  ← Geometry, models, state machines
│      │  (Fast, 80%+)  │  ← Brush engine, bezier math, serialization
└──────┴────────────────┘
```

### 11.2 Key Test Areas

| Area | Test Type | What to Test |
|------|-----------|-------------|
| Stroke builder | Unit | Point interpolation, pressure mapping |
| Brush engine | Unit | Width calculation, opacity, all brush types |
| Bezier path builder | Unit | Catmull-Rom → Cubic Bézier conversion |
| Coordinate transforms | Unit | Canvas ↔ Screen, zoom/pan mapping |
| Undo manager | Unit | Group operations, memory limits |
| Stroke serialization | Unit | Binary format round-trip |
| Conflict resolver | Unit | All resolution strategies |
| PDF annotation | Integration | Stroke overlay alignment, export fidelity |
| Sync engine | Integration | Change propagation, conflict detection |
| Canvas rendering | Performance | FPS under load, memory usage |

---

## 12. Security & Privacy

| Concern | Mitigation |
|---------|-----------|
| Notes data | Encrypted via iOS Data Protection (NSFileProtectionCompleteUntilFirstUserAuthentication) |
| iCloud data | Encrypted in transit (TLS) and at rest (CloudKit encryption) |
| AI processing | On-device by default; user opt-in for cloud AI features |
| PDF content | Sandboxed access; user-granted permissions only |
| Crash reports | Opt-in, no note content included |
| Analytics | Minimal, opt-in, no stroke data |

---

## 13. Trade-off Analysis

| Decision | Option A (Chosen) | Option B | Rationale |
|----------|-------------------|----------|-----------|
| Persistence | SwiftData + file storage | Pure Core Data | SwiftData for modern SwiftUI integration; binary stroke data on filesystem for performance |
| Rendering | Metal + PencilKit hybrid | PencilKit-only | Custom Metal for advanced brush effects; PKCanvasView as a fallback for basic tools |
| Canvas model | Infinite canvas with virtual pages | Fixed pages only | Max flexibility; page mode is a viewport constraint on the infinite canvas |
| Sync | CloudKit custom zones | CloudKit record sharing | Custom zones for offline-first + deterministic conflict resolution |
| Architecture | MVVM + Coordinator | TCA (The Composable Architecture) | MVVM is more widely understood; Coordinator pattern separates navigation cleanly |
| Stroke storage | Custom binary format | JSON/PropertyList | 10-20x smaller, faster to parse, streamable |
| AI architecture | Protocol-based bridge | Direct framework calls | Swappable implementations (on-device ↔ cloud) without changing business logic |

---

## 14. Scalability Recommendations

1. **Data partitioning**: Store stroke data per-page in separate files for parallel loading
2. **Lazy loading**: Load stroke metadata only; defer full stroke data until viewport requires it
3. **Tile-based rendering**: Split canvas into 512×512pt tiles; cache rendered tiles in GPU textures
4. **Background indexing**: Search indexing runs as a background task, not on the main thread
5. **Sync batching**: Batch up to 100 changes per sync operation to reduce CloudKit transactions
6. **Pre-fetching**: Predict next page/user action and pre-load nearby content

---

## 15. Future Expansion Ideas

1. **Apple Vision Pro port**: Shared canvas architecture with immersive mode
2. **Web companion**: Note viewing via iCloud web
3. **API for developers**: REST API for notebook content access
4. **Handwriting search**: Full-text search of handwriting via ML
5. **Smart notebooks**: AI-organized notes with auto-tagging
6. **Presentation mode**: Full-screen canvas as a presentation tool
7. **Screen recording**: Time-lapse replay of note creation
8. **Marketplace**: Community templates, stickers, and brush packs
