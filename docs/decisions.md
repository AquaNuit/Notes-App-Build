# Inscribe — Architecture Decision Records

## ADR-001: SwiftData + File Storage for Persistence

**Status:** Accepted
**Date:** 2026-07-09

### Context
Need to store notebook metadata, page information, and stroke data. Two main options: pure SwiftData (or CoreData) for everything, or a hybrid approach with SwiftData for metadata and binary files for strokes.

### Decision
Use SwiftData for metadata (notebooks, pages, tags, stroke metadata) and custom binary file format for stroke point data stored on the filesystem.

### Rationale
- Stroke data is large (thousands of points) and binary format is 10-20x smaller than JSON/Plist
- SwiftData is not optimized for large binary blobs — storing strokes as Data in SwiftData would slow down queries
- File-based strokes can be memory-mapped for fast access
- SwiftData provides reactive UI updates (@Query) for metadata changes
- Metadata queries remain fast regardless of stroke count

### Consequences
- Need a separate StrokeFileManager for file I/O
- File paths stored in SwiftData reference the on-disk stroke data
- Backup must include both SwiftData store and files directory
- Slightly more complex than a single-store approach

---

## ADR-002: Metal + PencilKit Hybrid Rendering

**Status:** Accepted
**Date:** 2026-07-09

### Context
Need low-latency ink rendering with advanced brush effects (fountain pen, calligraphy, variable width). PencilKit provides great baseline performance but limited customization.

### Decision
Use a hybrid approach:
- **Custom Metal pipeline** for advanced brush rendering (fountain pen, calligraphy, marker with opacity buildup)
- **PKCanvasView fallback** for basic tools (pen, highlighter) to leverage system optimizations
- **PKToolPicker** for the tool selection UI (with custom tool registration via iOS 18 APIs)

### Rationale
- Custom Metal allows brush effects impossible in PencilKit (bristle simulation, angle-dependent width)
- PencilKit is highly optimized for basic strokes and handles palm rejection, coalescing out of the box
- PKToolPicker provides a professional, familiar tool selection UI
- iOS 18 allows custom tools in PKToolPicker

### Consequences
- Two rendering paths to maintain
- Need to sync tool state between custom and PencilKit paths
- More initial development time but superior brush quality
- iOS 18+ custom tool APIs reduce the UI surface we need to build

---

## ADR-003: Infinite Canvas with Virtual Pages

**Status:** Accepted
**Date:** 2026-07-09

### Context
Users expect both infinite scrolling (whiteboard mode) and page-bound notebooks (page mode). These are conflicting models.

### Decision
Implement an infinite canvas at the core. Page mode is a **viewport constraint** applied to the infinite canvas — the canvas renders a fixed-size region and shows page breaks. Switching between modes is a viewport resize operation.

### Rationale
- Single rendering engine for both modes
- Users can freely arrange content across pages without content clipping
- Page mode is a UX layer on top of the infinite canvas, not a different data model
- Easier to implement zoom-to-fit and other navigation features

### Consequences
- Touch events are always in canvas coordinates, simplifying transforms
- Page backgrounds are rendered as layers on the infinite canvas
- Export logic needs to clip to page boundaries

---

## ADR-004: CloudKit Custom Zones for Sync

**Status:** Accepted
**Date:** 2026-07-09

### Context
Need offline-first sync across Apple devices. Options: CloudKit with default zones, custom zones, or record sharing.

### Decision
Use **CloudKit custom zones** with change tokens for deterministic sync. Each notebook gets its own custom zone.

### Rationale
- Custom zones provide change tracking via change tokens
- Offline-first: all writes to local storage, sync happens asynchronously
- Deterministic conflict resolution (Last-Write-Wins)
- No server-side code needed
- Free tier is generous for note data

### Consequences
- Initial sync setup is more complex than default zones
- Need to manage zone creation/deletion with notebook lifecycle
- Sync state machine needed for reliable operation
- 100 custom zone limit per app (acceptable — each notebook = 1 zone, 500 zones with entitlement request)

---

## ADR-005: MVVM + Coordinator Architecture

**Status:** Accepted
**Date:** 2026-07-09

### Context
Need a clean separation between SwiftUI views and business logic, with navigable, testable architecture.

### Decision
Use **MVVM with Coordinator pattern**. ViewModels are `@Observable` classes (iOS 17+), Coordinators handle navigation logic.

### Rationale
- MVVM is the most widely understood pattern for SwiftUI
- @Observable (iOS 17+) provides reactive bindings without Combine overhead
- Coordinator pattern decouples navigation from views — important for deep linking, Stage Manager, and Split View
- ViewModels are testable without UI dependency
- Team familiarity with MVVM reduces onboarding time

### Consequences
- More boilerplate than simple View structs
- Need to manage Coordinator lifecycle with scene state
- Navigation state is centralized in Coordinators (easier debugging)

---

## ADR-006: Custom Binary Stroke Format

**Status:** Accepted
**Date:** 2026-07-09

### Context
Strokes consist of thousands of points with pressure, tilt, roll, and timestamp data. Storage format affects performance, file size, and sync bandwidth.

### Decision
Use a **custom binary format** with a header, stroke metadata blocks, and packed point data. Magic number for validation, version field for forward compatibility.

### Rationale
- 10-20x smaller than JSON; 3-5x smaller than Plist
- Memory-mappable for instant access without parsing
- Streamable — can render strokes as they load
- Version field allows format evolution
- Custom serialization is trivial with `Data` + `withUnsafeBytes`

### Consequences
- Need custom serialization/deserialization code
- Cannot inspect stroke files with standard tools (need a debug utility)
- Format must be documented for future developers
- Migration code needed if format changes

---

## ADR-007: Protocol-Based AI Bridge

**Status:** Accepted
**Date:** 2026-07-09

### Context
AI features will be added over time. Different features may use on-device (CoreML, Vision) or cloud-based models. Implementation details should be swappable.

### Decision
Define **protocols** for each AI capability (HandwritingRecognition, ShapeClassification, MathSolving, etc.) with a dependency-injected implementation provider.

### Rationale
- Swappable implementations (on-device ↔ cloud) without changing business logic
- Can implement stubs/mocks for testing
- Easy to add new AI providers (Apple, Google, OpenAI) behind the same interface
- Compile-time safety for AI feature contracts

### Consequences
- Additional abstraction layer
- Need to design protocols upfront to avoid breaking changes
- Performance overhead of protocol dispatch (negligible)
