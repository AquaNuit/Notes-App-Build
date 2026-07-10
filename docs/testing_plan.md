# Inscribe — Performance & Testing Plan

---

## 1. Unit Testing Plan

### 1.1 Core Module Tests

| Test File | What to Test |
|-----------|-------------|
| `InkPointTests.swift` | Point creation, equality, encoding/decoding, pressure clamping |
| `StrokeTests.swift` | Bounds calculation, point insertion, serialization round-trip |
| `StrokeBuilderTests.swift` | Point interpolation, pressure mapping, begin/append/end lifecycle |
| `BezierPathBuilderTests.swift` | Catmull-Rom to Cubic Bézier conversion, smoothness checks |
| `TouchPredictorTests.swift` | Predicted point generation, line extension accuracy |
| `PalmRejectionFilterTests.swift` | Touch classification (pencil vs finger vs palm) |
| `UndoManagerTests.swift` | Register/undo/redo, grouping, memory limits |
| `BinaryStrokeFormatTests.swift` | Serialization round-trip, version compatibility, corruption detection |
| `CoordinateTransformTests.swift` | Canvas ↔ Screen transforms, zoom/pan matrix |
| `ShapeRecognizerTests.swift` | Stroke classification (line, circle, rect, etc.) |

### 1.2 Rendering Module Tests

| Test File | What to Test |
|-----------|-------------|
| `StrokeVertexGeneratorTests.swift` | Triangle strip generation, vertex count, bounds |
| `BrushDefinitionTests.swift` | Parameter validation, width calculation for each brush |
| `FountainPenBrushTests.swift` | Pressure → width curve, angle response |
| `MarkerBrushTests.swift` | Opacity accumulation between overlapping strokes |
| `StrokeCacheTests.swift` | LRU eviction, memory limits, cache hit/miss |
| `TextureGeneratorTests.swift` | Procedural texture size, contents |

### 1.3 Canvas Module Tests

| Test File | What to Test |
|-----------|-------------|
| `ZoomControllerTests.swift` | Min/max clamping, scale limits, animated zoom |
| `PanControllerTests.swift` | Momentum calculation, boundary conditions |
| `LayerManagerTests.swift` | Layer ordering, visibility toggles, compositing |

### 1.4 Storage Module Tests

| Test File | What to Test |
|-----------|-------------|
| `StrokeFileManagerTests.swift` | File creation, read/write, deletion, error handling |
| `SwiftDataModelTests.swift` | Model creation, relationships, queries, in-memory store |
| `DiskCacheTests.swift` | LRU eviction, size limits, expiry |
| `MediaFileManagerTests.swift` | Image/audio file storage, path management |

### 1.5 Documents Module Tests

| Test File | What to Test |
|-----------|-------------|
| `NotebookManagerTests.swift` | CRUD operations, fetch, archive, search |
| `PageManagerTests.swift` | Create/delete/move/duplicate, ordering |
| `TagManagerTests.swift` | Tag assignment, filtering by tag |
| `SmartCollectionEngineTests.swift` | Rule evaluation, predicate parsing |

### 1.6 Sync Module Tests

| Test File | What to Test |
|-----------|-------------|
| `SyncStateMachineTests.swift` | State transitions, error states |
| `ConflictResolverTests.swift` | LWW correctness, three-way merge |
| `ChangeTrackingTests.swift` | Change recording, ordering, deduplication |

---

## 2. Integration Testing Plan

| Test | What It Verifies |
|------|-----------------|
| Touch → Stroke → Render pipeline | Full drawing lifecycle: touch → inkpoint → stroke → metal geometry → display |
| Notebook → Page → Stroke persistence | Create notebook, add page, draw strokes, restart app, verify content |
| PDF import + annotation + export | Import PDF, annotate with strokes, export, verify annotation fidelity |
| Undo/Redo with persistence | Draw, undo, save, reload, verify undo state persists |
| Canvas zoom + pan + draw | Zoom in, draw, verify stroke coordinates remain correct |
| iPad orientation changes | Rotate, verify canvas content and tool palette positions |

---

## 3. Performance Testing Plan

| Test | Metric | Tool |
|------|--------|------|
| Stroke rendering latency | < 10ms | Instruments (Metal System Trace) |
| Canvas scroll FPS | 120 FPS sustained | Instruments (Core Animation) |
| Page load time (1000 strokes) | < 500ms | Custom benchmark in XCTest |
| Notebook list load (10k items) | < 1s | OS_signpost + os_log |
| PDF import (100 pages) | < 3s | XCTest measure |
| Memory with 10k pages loaded | < 200MB | Instruments (Allocations) |
| Sync 1000 changes | < 5s | Custom integration benchmark |
| Battery usage (1hr drawing) | < 10% | Energy Log in Xcode |
| App cold start time | < 2s | Xcode Organizer (Launch Time) |
| Crash-free rate | > 99.9% | Crashlytics (production) |

---

## 4. Testing Tools

| Tool | Purpose |
|------|---------|
| XCTest | Unit + integration tests |
| XCUITest | UI automation testing |
| Instruments | Performance profiling |
| OSLog / OS_signpost | Custom instrumentation |
| Swift Testing (iOS 18+) | Parameterized tests |
