# Inscribe — Development Roadmap

---

## Phase 0: Architecture & Planning
**Duration:** 1 week
**Status:** ✅ Complete

| Task | Complexity | Owner | Dependencies |
|------|-----------|-------|-------------|
| Architecture document | Medium | Architect | None |
| Data model design | Medium | Architect | Architecture doc |
| Project structure | Low | All | Architecture doc |
| Swift package setup | Low | Lead | Project structure |
| CI/CD pipeline | Medium | DevOps | Repo setup |
| Coding guidelines | Low | Lead | None |

**Deliverables:**
- Complete architecture blueprint
- All docs/ files created
- Xcode project with empty packages
- GitHub repository with CI

**Risks:**
- Minimal — this is a documentation phase

---

## Phase 1: Core Canvas + Pencil Engine + Notebook System
**Duration:** 4-6 weeks
**Status:** 🔜 Ready to start

### Sprint 1.1: Touch Engine & Stroke Pipeline (Week 1)
| Task | Complexity | Notes |
|------|-----------|-------|
| TouchEventProcessor | Medium | Raw UITouch → InkPoint conversion |
| TouchPredictor | Medium | Predicted touch generation |
| PalmRejectionFilter | Medium | Palm classification algorithm |
| StrokeBuilder | Medium | Point interpolation + smoothing |
| Catmull-Rom interpolation | Low | Spline calculation |
| Binary stroke serialization | Medium | Custom binary format read/write |

### Sprint 1.2: Metal Rendering & Brush Engine (Week 2)
| Task | Complexity | Notes |
|------|-----------|-------|
| Metal device/setup | High | Device creation, library, pipeline |
| Ink vertex shader | High | Canvas-space → screen-space transform |
| Ink fragment shader | Medium | Texture sampling, alpha blending |
| Double-buffered rendering | Medium | Frame synchronization |
| Fountain pen brush | High | Variable width, pressure response |
| Pencil brush | Medium | Texture-based pencil simulation |
| Marker brush | Medium | Opacity buildup |
| Highlighter brush | Low | Translucent, fixed width |
| Brush (paint) | High | Bristle simulation |
| Calligraphy pen | High | Angle-dependent width |
| Eraser (pixel & stroke) | Medium | Fragment discard, stroke hit test |

### Sprint 1.3: Pencil Integration (Week 2-3)
| Task | Complexity | Notes |
|------|-----------|-------|
| Pressure curve controller | Medium | Linear, logarithmic, custom |
| Tilt shading engine | Medium | Altitude/azimuth → opacity map |
| Hover preview | Medium | Cursor rendering on hover |
| Squeeze handler (Pencil Pro) | Low | UIPencilInteraction.squeeze |
| Double-tap handler | Low | UIPencilInteraction.doubleTap |
| Barrel roll handler | Low | UITouch.roll |
| Custom PKToolPicker tools | Medium | iOS 18 custom tool registration |

### Sprint 1.4: Infinite Canvas (Week 3)
| Task | Complexity | Notes |
|------|-----------|-------|
| InfiniteCanvasView | Medium | SwiftUI container with MTKView |
| InfiniteCanvasController | Medium | UIKit bridge for PencilKit |
| Zoom controller | Medium | Pinch + programmatic zoom |
| Pan controller | Medium | Drag + momentum scrolling |
| Layer manager | Medium | Static/dynamic/UI layer compositing |
| Background grid rendering | Medium | Grid, dot grid patterns |
| Template system | Low | Built-in + custom templates |

### Sprint 1.5: Notebook System (Week 4)
| Task | Complexity | Notes |
|------|-----------|-------|
| SwiftData models | Medium | Notebook, Page, Section, Tag |
| CRUD operations | Medium | Create, read, update, delete |
| Notebook browser | Medium | Gallery + list views |
| Page thumbnails | Low | Render preview tiles |
| Drag-to-reorder | Medium | UICollectionView reorder |
| Color labels & favorites | Low | Metadata fields + UI |
| Archive functionality | Low | Soft delete pattern |

### Sprint 1.6: Undo/Redo & Selection (Week 4-5)
| Task | Complexity | Notes |
|------|-----------|-------|
| UndoManager | Medium | Stroke-level undo/redo |
| UndoableAction protocol | Low | Action interface |
| Undo grouping | Medium | Transactional undo |
| Lasso selection | High | Freeform path selection |
| Stroke hit testing | Medium | Path intersection |
| Move/copy/delete selection | Medium | Selection manipulation |

### Sprint 1.7: Polish & Integration (Week 5-6)
| Task | Complexity | Notes |
|------|-----------|-------|
| Integration testing | Medium | Cross-module testing |
| Performance profiling | High | Instruments, FPS validation |
| Bug fixing | Medium | Crash fixes, edge cases |
| UI refinement | Medium | Visual polish, transitions |

**Phase 1 Milestone:** Working canvas with all 6 brush types, Pencil support, notebook CRUD, and undo/redo.

---

## Phase 2: PDF Support + Export + Search
**Duration:** 3-4 weeks

### Sprint 2.1: PDF Import & Annotation (Week 1-2)
| Task | Complexity | Notes |
|------|-----------|-------|
| PDF document picker | Low | UIDocumentPickerViewController |
| PDF page extraction | Medium | PDFKit page parsing |
| PDF thumbnail generation | Low | Thumbnail rendering |
| PDFView + drawing overlay | High | Coordinate alignment, scroll sync |
| Highlight extraction | Medium | PDF selection → highlight annotation |
| Image insertion on PDF | Medium | Image overlay, positioning |

### Sprint 2.2: PDF Export & Merge (Week 2-3)
| Task | Complexity | Notes |
|------|-----------|-------|
| Annotated PDF export | High | Stroke → PDF page rendering |
| Export format options | Low | Flatten vs editable layers |
| AirPrint support | Low | UIPrintInteractionController |
| PDF merging | Medium | Multi-document composition |
| PDF splitting | Medium | Page range extraction |

### Sprint 2.3: Search (Week 3-4)
| Task | Complexity | Notes |
|------|-----------|-------|
| FTS5 index setup | Medium | SQLite full-text search |
| Background indexing | Medium | Index queue management |
| Search UI | Medium | Results list, highlighting |
| OCR text extraction | High | Vision framework + stroke processing |

**Phase 2 Milestone:** Full PDF annotation pipeline with export and notebook search.

---

## Phase 3: Cloud Sync + Collaboration
**Duration:** 3-4 weeks

### Sprint 3.1: CloudKit Setup (Week 1)
| Task | Complexity | Notes |
|------|-----------|-------|
| CloudKit container | Low | CKContainer configuration |
| Custom zone management | Medium | Zone creation/deletion |
| Record mapping | Medium | SwiftData → CKRecord mapping |

### Sprint 3.2: Sync Engine (Week 1-2)
| Task | Complexity | Notes |
|------|-----------|-------|
| Change tracking | Medium | Local change log |
| Push/pull operations | High | Bi-directional sync |
| Conflict detection | High | Version vector comparison |
| Conflict resolution | Medium | LWW + three-way merge |

### Sprint 3.3: Background Sync (Week 2-3)
| Task | Complexity | Notes |
|------|-----------|-------|
| BGTaskScheduler setup | Medium | Background task registration |
| Sync state machine | Medium | State transitions, error handling |
| Progress UI | Low | Sync status indicators |

### Sprint 3.4: Collaboration (Week 3-4)
| Task | Complexity | Notes |
|------|-----------|-------|
| Shared notebook model | Medium | Sharing data model |
| Live cursor data model | Medium | Cursor position serialization |
| (Future) WebSocket server | High | Real-time collaboration |

**Phase 3 Milestone:** Reliable iCloud sync across devices with conflict resolution.

---

## Phase 4: AI Features
**Duration:** 3-4 weeks

### Sprint 4.1: AI Bridge Infrastructure (Week 1)
| Task | Complexity | Notes |
|------|-----------|-------|
| AIBridge protocol definitions | Medium | Capability protocols |
| Model management | Medium | Model download/storage |
| Privacy controls | Low | On-device vs cloud toggle |

### Sprint 4.2: Shape Recognition (Week 1-2)
| Task | Complexity | Notes |
|------|-----------|-------|
| Stroke classification | High | ML model for shape detection |
| Shape beautification | High | Auto-correct rough shapes |
| Smart guides | Medium | Alignment guides during drawing |

### Sprint 4.3: Handwriting Recognition (Week 2-3)
| Task | Complexity | Notes |
|------|-----------|-------|
| Vision OCR integration | Medium | VNRecognizeTextRequest |
| Stroke → text conversion | High | Handwriting → text pipeline |
| Searchable handwriting index | Medium | OCR → FTS5 index |

### Sprint 4.4: Advanced AI (Week 3-4)
| Task | Complexity | Notes |
|------|-----------|-------|
| Math expression detection | High | Formula recognition |
| Note summarization | Medium | Text summarization model |
| Smart search | Low | Semantic search integration |

**Phase 4 Milestone:** On-device handwriting recognition, shape beautification, and smart search.

---

## Phase 5: Performance + App Store
**Duration:** 4-5 weeks

### Sprint 5.1: Performance (Week 1-2)
| Task | Complexity | Notes |
|------|-----------|-------|
| Memory profiling | Medium | Reduce memory footprint |
| Startup time optimization | Medium | Lazy loading, pre-warming |
| 10,000 page stress test | High | Verify performance at scale |
| GPU optimization | High | Shader optimization, draw call reduction |
| Battery usage optimization | Medium | Reduce CPU/GPU usage idle |

### Sprint 5.2: Accessibility (Week 2)
| Task | Complexity | Notes |
|------|-----------|-------|
| VoiceOver support | Medium | Accessibility labels, hints |
| Dynamic Type | Low | Font scaling |
| Reduce Motion | Low | Disable animations |
| Switch Control | Medium | Full keyboard navigation |
| Color contrast | Low | WCAG compliance |

### Sprint 5.3: Localization (Week 2-3)
| Task | Complexity | Notes |
|------|-----------|-------|
| String catalog | Medium | All user-facing strings |
| RTL support | Medium | Right-to-left layout |
| Localization: EN, ZH, JA, KO, FR, DE, ES | Medium | High-priority languages |

### Sprint 5.4: App Store (Week 3-4)
| Task | Complexity | Notes |
|------|-----------|-------|
| App icon | Low | Multiple size variants |
| Screenshots & video | Low | App Store assets |
| Privacy policy | Low | Legal documentation |
| App Store metadata | Low | Description, keywords |
| TestFlight beta | Low | Beta testing program |

### Sprint 5.5: Hardening (Week 4-5)
| Task | Complexity | Notes |
|------|-----------|-------|
| Crash reporting | Low | Crashlytics/Telemetry |
| Analytics (opt-in) | Medium | Usage metrics |
| Error recovery | Medium | Graceful error handling |
| Final QA pass | Medium | Full regression testing |

**Phase 5 Milestone:** App Store submission-ready application.

---

## Overall Timeline

```
Week  1:  Phase 0 — Planning
Weeks 2-7:  Phase 1 — Core Canvas + Pencil + Notebook
Weeks 8-11: Phase 2 — PDF + Export + Search
Weeks 12-15: Phase 3 — Cloud Sync + Collaboration
Weeks 16-19: Phase 4 — AI Features
Weeks 20-24: Phase 5 — Performance + App Store
           ↓
      Week 25: App Store Submission
```

**Total estimated duration:** ~6 months from start to submission.

## Key Milestones

| Milestone | Date | Deliverable |
|-----------|------|-------------|
| M1: Architecture complete | Week 1 | All docs/, project structure |
| M2: Canvas drawing | Week 4 | Draw strokes with all brush types |
| M3: Notebook system | Week 6 | Create, organize, browse notebooks |
| M4: PDF annotation | Week 10 | Import, annotate, export PDFs |
| M5: Search | Week 11 | Full-text + handwritten search |
| M6: iCloud sync | Week 14 | Multi-device sync working |
| M7: AI features | Week 18 | Shape recognition, handwriting OCR |
| M8: App Store ready | Week 24 | All metrics green, assets ready |
