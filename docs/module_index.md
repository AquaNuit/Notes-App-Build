# Inscribe — Module Index

## Module Dependency Graph

```
App
 └── UI (navigation, tool palette, modals)
      ├── Canvas (infinite canvas, layers, zoom, pan)
      │    ├── Rendering (Metal, ink pipeline, brush engine)
      │    │    ├── Pencil (pressure, tilt, hover, tools)
      │    │    └── Core (touch engine, geometry, coordinate space)
      │    └── Core
      ├── PDF (import, annotate, export)
      │    ├── Rendering (PDF page rendering)
      │    └── Core (coordinate transforms)
      ├── Documents (notebook, page, section, tags)
      │    ├── Storage (SwiftData, file manager)
      │    │    ├── Core (data models, serialization)
      │    │    └── Sync (CloudKit, conflict resolution)
      │    └── Search (indexing, OCR, FTS)
      │         └── Core
      ├── Settings (preferences, pencil, cloud, AI)
      │    └── Core
      ├── Components (reusable UI components)
      └── Extensions (Swift standard lib extensions)
```

## Module Descriptions

### App Module
**Path:** `Inscribe/App/`
**Responsibility:** Application entry point, scene lifecycle, dependency injection container.
**Depends on:** All feature modules
**Dependencies:** UIKit, SwiftUI

### Core Module
**Path:** `Inscribe/Core/`
**Responsibility:** Foundational data types, geometry math, touch processing, undo/redo engine.
**Key protocols:** `TouchProcessor`, `StrokeBuilder`, `UndoableAction`
**Depends on:** Nothing internal
**Dependencies:** UIKit, CoreGraphics

### Canvas Module
**Path:** `Inscribe/Canvas/`
**Responsibility:** Infinite canvas management, layer compositing, zoom/pan handling, background rendering.
**Depends on:** Core (geometry, coordinate space), Rendering (for display)
**Dependencies:** SwiftUI, UIKit

### Rendering Module
**Path:** `Inscribe/Rendering/`
**Responsibility:** Metal pipeline management, brush geometry generation, stroke caching, texture management.
**Depends on:** Core (InkPoint, Stroke models)
**Dependencies:** Metal, MetalKit, CoreGraphics

### Pencil Module
**Path:** `Inscribe/Pencil/`
**Responsibility:** Apple Pencil interaction handling, pressure curve management, tilt shading, hover preview, tool picker customization.
**Depends on:** Core (touch data)
**Dependencies:** PencilKit, UIKit

### Documents Module
**Path:** `Inscribe/Documents/`
**Responsibility:** Notebook/section/page CRUD, tagging, smart collections, template system.
**Depends on:** Storage (persistence layer)
**Dependencies:** SwiftData

### PDF Module
**Path:** `Inscribe/PDF/`
**Responsibility:** PDF import, annotation overlay, highlight extraction, export with annotations, merge/split operations.
**Depends on:** Core (coordinate transforms), Canvas (for annotation rendering)
**Dependencies:** PDFKit, UIKit

### Storage Module
**Path:** `Inscribe/Storage/`
**Responsibility:** SwiftData model definitions, file-based stroke storage, disk/memory caching, backup/restore.
**Depends on:** Core (data serialization formats)
**Dependencies:** SwiftData, CloudKit

### Sync Module
**Path:** `Inscribe/Sync/`
**Responsibility:** CloudKit sync engine, conflict resolution, background sync scheduling, sync state machine.
**Depends on:** Storage (data models), Documents (change tracking)
**Dependencies:** CloudKit, BackgroundTasks

### Search Module
**Path:** `Inscribe/Search/`
**Responsibility:** Full-text search via FTS5, OCR via Vision framework, index management, search query parsing.
**Depends on:** Core (text extraction), Documents (searchable entities)
**Dependencies:** SQLite (via GRDB or custom), Vision

### UI Module
**Path:** `Inscribe/UI/`
**Responsibility:** Sidebar navigation, floating tool palette, inspector panel, notebook browser, canvas overlays, modals.
**Depends on:** All feature modules (orchestrates feature views)
**Dependencies:** SwiftUI

### Components Module
**Path:** `Inscribe/Components/`
**Responsibility:** Reusable UI components: buttons, sliders, pickers, thumbnails, loading states.
**Depends on:** Nothing feature-specific
**Dependencies:** SwiftUI

### Settings Module
**Path:** `Inscribe/Settings/`
**Responsibility:** User preferences, pencil configuration, cloud settings, AI feature toggles.
**Depends on:** Core (settings storage)
**Dependencies:** SwiftUI

### Extensions Module
**Path:** `Inscribe/Extensions/`
**Responsibility:** Swift standard library and UIKit extensions for common operations.
**Depends on:** Nothing
**Dependencies:** UIKit, CoreGraphics

### Utilities Module
**Path:** `Inscribe/Utilities/`
**Responsibility:** Logging, performance monitoring, memory warnings, background tasks, haptics.
**Depends on:** Nothing
**Dependencies:** OSLog, UIKit

## Package Organization (SPM)

The project should be organized as a single Xcode project with multiple Swift packages:

```
Inscribe.xcodeproj
├── Inscribe (Main App Target)
│   Depends on:
│   ├── InscribeCore (internal package)
│   ├── InscribeCanvas (internal package)
│   ├── InscribeRendering (internal package)
│   ├── InscribePencil (internal package)
│   ├── InscribeDocuments (internal package)
│   ├── InscribePDF (internal package)
│   ├── InscribeStorage (internal package)
│   ├── InscribeSync (internal package)
│   ├── InscribeSearch (internal package)
│   ├── InscribeUI (internal package)
│   └── InscribeUtilities (internal package)
├── InscribeCore
├── InscribeCanvas
├── InscribeRendering
├── InscribePencil
├── InscribeDocuments
├── InscribePDF
├── InscribeStorage
├── InscribeSync
├── InscribeSearch
├── InscribeUI
└── InscribeUtilities
```

Each Swift package has:
- `Sources/` — implementation files
- `Tests/` — unit tests
- `Package.swift` — manifest (can use Xcode-generated)
