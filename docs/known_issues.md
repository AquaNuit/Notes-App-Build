# Inscribe — Known Issues & Risk Register

> **Last Updated:** 2026-07-09

---

## Risk Register

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
|----|------|-----------|--------|------------|-------|
| R-001 | SwiftData performance degrades with 10,000+ pages | Medium | High | Hybrid storage (metadata in SwiftData, strokes on filesystem); profile at Phase 5 | Lead |
| R-002 | Metal rendering pipeline has high initial complexity | High | Medium | Start with PencilKit fallback, add Metal incrementally; use WWDC sample code | Rendering |
| R-003 | CloudKit custom zone limits (100 by default, 500 with request) | Low | Medium | Each notebook = 1 zone; request entitlement increase before Phase 3 | Backend |
| R-004 | Apple Pencil Pro features depend on specific hardware | Medium | Low | Graceful degradation: check capabilities at runtime, hide unavailable features | Pencil |
| R-005 | PDF annotation coordinate systems misalign | High | Medium | Extensive testing with multi-page PDFs; unit test coordinate transforms | PDF |
| R-006 | Binary stroke format becomes incompatible with future features | Medium | Medium | Version field in header; write migration code when format changes | Storage |
| R-007 | offline-first sync conflicts with concurrent edits | Medium | High | LWW with metadata merge; conflict notification UI for unresolvable cases | Sync |
| R-008 | App rejected for PencilKit usage outside approved contexts | Low | High | Use PencilKit for basic tools, Metal for advanced brushes — comply with App Store guidelines | Legal |
| R-009 | Memory pressure with large imported PDFs | Medium | Medium | Page-level lazy loading; render PDF tiles at display resolution only | PDF |
| R-010 | Team continuity when multiple AI agents hand off | Medium | Medium | agent_handoff.md must be updated every session; all decisions in decisions.md | All |

---

## Known Bugs

| ID | Bug | Module | Severity | Status | Reported |
|----|-----|--------|----------|--------|----------|
| — | No bugs yet (project in planning) | — | — | — | — |

---

## Performance Limitations

| Area | Current Limit | Target | Notes |
|------|-------------|--------|-------|
| Pages per notebook | N/A (not built) | 10,000+ | Test at Phase 5 |
| Strokes per page | N/A (not built) | 10,000+ | Spatial indexing required |
| PDF size | N/A (not built) | 500MB+ | Lazy page loading |
| Canvas zoom range | N/A (not built) | 10% - 3200% | Smooth at all levels |
| Undo history | N/A (not built) | 500+ actions | Memory-limited at extreme |

---

## Technical Debt Tracking

| Debt | Module | Impact | Planned Resolution |
|------|--------|--------|-------------------|
| — | — | — | — |
