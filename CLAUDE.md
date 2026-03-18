# CLAUDE.md — AI Gallery (root)

Offline AI photo search app. Flutter + Rust. Zero network calls. Zero data leaves device.
iOS 16+ and Android 10+.

---

## Current phase
**Phase 1 — Skeleton**
Update this line manually when a phase completes and is committed.

## Phase checklist
- [ ] Phase 1 — Flutter skeleton, Rust crate init, SQLite schema, photo_manager wiring
- [ ] Phase 2 — Rust inference layer (all 4 models, 6 bridge functions)
- [ ] Phase 3 — IndexingService + background task registration
- [ ] Phase 4 — QueryService + search UI
- [ ] Phase 5 — Face clustering + People screen
- [ ] Phase 6 — UI polish, onboarding, detail screen

---

## Docs — read the relevant file(s) before starting any task

| Doc | When to read |
|---|---|
| `@docs/stack.md` | Any session — locked tech decisions |
| `@docs/schema.md` | Any DB work, indexing, search |
| `@docs/models.md` | Any Rust/inference work |
| `@docs/pipeline.md` | Phase 3 — IndexingService |
| `@docs/search.md` | Phase 4 — QueryService |
| `@docs/ui-spec.md` | Phase 4, 5, 6 — any UI work |
| `@docs/clustering.md` | Phase 5 — FaceClusterService |

---

## Hard constraints — always apply, never override

- Zero network calls after install. No HTTP client. No Firebase. No analytics. No Crashlytics.
- Riverpod only for state management. No bloc, no cubit, no get_it.
- Rust handles all ML inference. Dart never calls ONNX directly.
- Dart passes raw pixel bytes to Rust. Rust never imports photo_manager.
- Never block the UI thread. All inference and DB writes in background isolates or Rust threads.
- No full-resolution images in SQLite — embeddings and metadata only.
- Do not create tables, models, or providers not defined in docs/schema.md.

---

## Folder ownership — each feature owns its own files

```
lib/core/           → DB singleton, base models, shared providers
lib/features/       → one folder per screen, each has its own CLAUDE.md
lib/services/       → IndexingService, QueryService, FaceClusterService
rust/src/           → all inference logic, bridge functions
docs/               → spec files, read with @ before starting a task
```

---

## Starting a session — always do this

1. State which phase you are working on
2. Reference the relevant docs with @
3. Scope the task to specific files — do not touch other phases

Example prompt to start Phase 3:
```
@docs/schema.md @docs/pipeline.md
Phase 1 and 2 are committed. Build Phase 3 — IndexingService only.
Touch only: lib/services/indexing_service.dart and lib/core/providers/indexing_provider.dart
```
