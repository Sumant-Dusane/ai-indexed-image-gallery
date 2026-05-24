# AGENTS.md — AI Gallery

Offline AI photo search app. Flutter + ONNX Runtime. Zero network calls. Zero data leaves device.
iOS 16+ and Android 10+.

---

## Current phase

**Phase 3 — Indexing Service**
_(Update this line when a phase is committed.)_

---

## Before writing any code — read the relevant docs

You MUST read the relevant doc files using the Read tool before starting work.
Only read docs listed for the current phase — do not preemptively read all docs.

| File path | When to read |
|---|---|
| `docs/stack.md` | **Every session** — locked tech decisions |
| `docs/skeleton.md` | Phase 1 — app foundation, init sequence, file list |
| `docs/schema.md` | Any DB work, indexing, search |
| `docs/models.md` | Any inference work |
| `docs/pipeline.md` | Phase 3 — IndexingService |
| `docs/search.md` | Phase 4 — QueryService |
| `docs/ui-spec.md` | Phase 4, 5, 6 — any UI work |
| `docs/clustering.md` | Phase 5 — FaceClusterService |

Also read the `AGENTS.md` inside the directory you are about to modify (e.g., `lib/core/AGENTS.md`, `lib/services/AGENTS.md`).

---

## Spec compliance — enforce before and after every change

The `docs/` files are the single source of truth. Before writing code and after completing a change:

1. **If the user's request contradicts a spec** (different schema, different provider shape, different function signature, etc.) → **stop and warn**: quote the conflicting spec line, ask whether to stick with the spec or override it.
2. **If the user explicitly chooses to override** → update the relevant `docs/` file first so the spec matches the new decision, then write the code. Never leave code and docs out of sync.
3. **If you discover your own code diverges from a spec during or after implementation** → fix the code to match the spec, or flag it to the user if the spec seems wrong.

This rule applies to everything in `docs/`: schema, function signatures, preprocessing values, provider shapes, UI layouts, pipeline steps, and stack decisions.

---

## Hard constraints — always apply, never override

- Zero network calls after install. No HTTP client. No Firebase. No analytics. No Crashlytics.
- State management: `riverpod_generator` with `@riverpod` annotations only. No classic `StateNotifierProvider` / `StreamProvider` declarations. No bloc, cubit, get_it.
- Data classes: `freezed` with `@freezed` annotations for all model classes. No plain Dart data classes.
- `InferenceRepository` is the single app-facing inference seam. Callers must not invoke ONNX sessions directly.
- Flutter/Dart owns model loading, preprocessing, postprocessing, and pHash through the inference layer.
- Never block the UI thread. All heavy inference, pixel math, and DB writes must run off the UI isolate where supported.
- No full-resolution images in SQLite — embeddings and metadata only.
- Do not create tables, models, or providers not defined in `docs/schema.md`.
- Do not modify files in `docs/` unless the user explicitly overrides a spec decision (see "Spec compliance" above).
- After creating or modifying `@freezed` models or `@riverpod` providers, run: `dart run build_runner build --delete-conflicting-outputs`

---

## Error handling — consistent across all phases

- Model file missing at init → throw, show fatal error screen
- Single image inference failure → log warning, skip image, continue queue
- Photo library permission denied → show permission request screen, block until granted
- DB migration failure → throw, show fatal error screen
- Never catch and swallow errors silently — always log at minimum

---

## Folder ownership

```
lib/core/           → DB singleton, freezed models, riverpod providers, repositories
lib/features/       → one folder per screen, each has its own AGENTS.md
lib/services/       → IndexingService, QueryService, FaceClusterService
docs/               → spec files — only modify when user explicitly overrides a decision
```

Each directory with an `AGENTS.md` — read it before modifying files in that directory.

---

## Starting a session

1. State which phase you are working on
2. Read `docs/stack.md` + the phase-relevant docs (see table above)
3. Read the `AGENTS.md` files for directories you will modify
4. Scope work to specific files — do not touch other phases
