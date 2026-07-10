# Inscribe — Coding Guidelines

## 1. Swift Style

### 1.1 Naming

- **Types** (structs, classes, enums, protocols): `PascalCase` — `StrokeBuilder`, `InkPoint`
- **Properties, methods, parameters**: `camelCase` — `strokeWidth`, `process(touch:)`
- **Protocols**: Adjective-based when describing capability (`Renderable`, `Persistable`), noun-based when describing type (`StrokeDataSource`)
- **Bool properties**: Adjective or `is` prefix — `isVisible`, `isArchived`, `enabled`
- **Constants**: `camelCase` — `defaultStrokeWidth`, NOT `kDefaultStrokeWidth` or `DEFAULT_STROKE_WIDTH`

### 1.2 Formatting

- 4-space indentation (Xcode default)
- Opening braces on same line
- `guard` early returns preferred over nested `if` blocks
- Prefer `let` over `var` — all properties should be `let` unless mutation is required
- Use `private(set)` for read-only public properties

### 1.3 Organization

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Protocol Conformance
```

## 2. Architecture Rules

### 2.1 Dependency Flow

```
View → ViewModel → Service/Repository → Model
```

- Views must not contain business logic
- ViewModels must not import UIKit
- Models must not depend on ViewModels or Views
- Services must be protocol-based and injected

### 2.2 State Management

- Use `@Observable` for ViewModels (iOS 17+) — avoid `ObservableObject` for new code
- Use `@Environment` for app-wide dependencies (not singletons)
- Use Combine publishers only for async operations, not for state binding
- Canvas state updates must use `actor` isolation to prevent data races

### 2.3 Concurrency

- Use Swift `async/await` for all async operations
- Use `@MainActor` on ViewModels and Views
- Use `actor` for SyncEngine, StrokeFileManager (shared mutable state)
- Background operations (indexing, sync) must use Task.detached or model actors

## 3. Performance Guidelines

### 3.1 Rendering

- No UIKit layout passes during touch events
- Precompute geometry in background before dispatching to GPU
- Use `MTKMeshBufferAllocator` for GPU buffer management
- Cache rendered tiles — only re-render when content changes
- Profile with Instruments before optimizing

### 3.2 Data

- Load stroke metadata before stroke point data
- Memory-map large stroke files instead of reading entire file
- Batch SwiftData saves (50+ operations per batch)
- Cache thumbnail images on disk with LRU eviction

## 4. Error Handling

```swift
// Use typed error enums rather than strings
enum StrokeError: LocalizedError {
    case serializationFailed(String)
    case invalidPointData
    case fileNotFound(UUID)
}

// Propagate errors, don't swallow them
func loadStroke(id: UUID) throws -> Stroke { ... }
```

## 5. Testing Guidelines

- Unit tests must not depend on external files
- Mock all protocol dependencies
- Test edge cases: empty strokes, single-point strokes, maximum pressure
- Performance tests must run on device, not simulator
- Aim for 80%+ code coverage on Core and Rendering modules

## 6. Git Conventions

### 6.1 Branch Naming

- `feat/canvas-metal-rendering`
- `fix/palm-rejection-crash`
- `refactor/stroke-serialization`
- `docs/phase-1-planning`

### 6.2 Commit Messages

```
type(scope): brief description

[optional body with details]
```

Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`

Examples:
- `feat(canvas): implement dual-layer Metal rendering`
- `fix(pencil): handle Pencil Pro squeeze gesture correctly`

### 6.3 PR Requirements

- All tests pass
- SwiftLint passes with project rules
- At least one reviewer
- PR description links to relevant docs/decisions
