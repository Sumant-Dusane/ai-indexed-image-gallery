# docs/playbook.md — Delivery playbook

Phase roadmap for AI Gallery. The active phase remains declared in `AGENTS.md`.
Future phases are planning entries only: do not implement them until they become
active or the user explicitly requests the work.

---

## Phase 1 — App foundation

Spec: `docs/skeleton.md`

- Flutter app shell, router, permissions, SQLite schema, and placeholder screens
- Gallery thumbnails load directly from `photo_manager`

## Phase 2 — Inference repository

Spec: `docs/models.md`

- Bundled ONNX model loading
- Dart-owned preprocessing, postprocessing, and pHash
- `InferenceRepository` remains the only app-facing inference entry point

## Phase 3 — Indexing service

Spec: `docs/pipeline.md`

- Photo library sync, indexing queue, deduplication, embeddings, detections, and faces
- Foreground progress plus iOS `BGProcessingTask` and Android `WorkManager` scheduling

## Phase 4 — Search

Specs: `docs/search.md`, `docs/ui-spec.md`

- Rule-based query parsing, vector search, metadata filters, and search UI

## Phase 5 — Face clustering

Specs: `docs/clustering.md`, `docs/ui-spec.md`

- DBSCAN face clustering, incremental assignment, naming, and People UI

## Phase 6 — UI polish and onboarding

Spec: `docs/ui-spec.md`

- Photos-style gallery polish, onboarding, indexing progress, and storage messaging

## Phase 7 — Isolate-backed background indexing architecture

Status: proposed future phase

Specs to update when this phase starts: `docs/pipeline.md`, `docs/models.md`,
`docs/stack.md` only if the implementation requires a new package.

### Goal

Keep search indexing responsive without competing with interactive gallery use.
OS background execution and Dart isolate execution must work together:

- iOS `BGProcessingTask` and Android `WorkManager` decide when deferred work may run.
- A bounded Dart isolate pool keeps CPU-heavy preprocessing and postprocessing off
  the UI isolate during both foreground and OS-scheduled indexing.

### Current gap

`IndexingService` processes four assets concurrently with `Future.wait`, but
async concurrency is not isolate separation. Full-resolution file reads, image
decode, pixel conversion, and parts of inference orchestration can still compete
with UI rendering.

### Target architecture

1. Keep photo-library access on the main Flutter isolate where platform-channel
   plugin constraints require it.
2. Materialise one image at a time per worker budget, then transfer bytes with
   `TransferableTypedData`.
3. Run decode, resize, RGB conversion, tensor preparation, and pure-Dart
   postprocessing in a bounded isolate pool.
4. Define an explicit inference-isolate strategy after validating whether
   `flutter_onnxruntime` sessions can be created and safely retained per worker.
   Do not transfer ONNX session objects between isolates.
5. Keep SQLite ownership explicit. Prefer one DB writer on the service isolate
   receiving structured results from workers; do not share SQLite connection
   objects across isolates.
6. Preserve foreground interactive pausing: stop dequeuing new work while photo
   detail is open, allow the active item to settle, and resume afterward.
7. Continue unfinished work through iOS `BGProcessingTask` and Android
   `WorkManager`; do not assume either OS will run tasks immediately.

### Investigation checklist

- Benchmark one-, two-, and four-worker configurations on physical iOS and Android devices.
- Measure UI frame times, peak memory, thermal state, battery impact, and photos indexed per minute.
- Verify ONNX Runtime worker-session behavior on both platforms before selecting
  the final inference topology.
- Verify that platform-channel photo loading remains stable when invoked during
  OS background execution.
- Verify cancellation and app lifecycle handling: foreground, background,
  termination, task expiration, and resume.

### Acceptance criteria

- No full-resolution image decode, RGB conversion loop, or tensor preparation
  runs on the UI isolate where isolate execution is supported.
- Gallery scrolling and photo-detail navigation remain smooth while foreground
  indexing is active.
- Indexing resumes after interactive pauses and after app relaunch without
  duplicate DB rows or lost queue progress.
- iOS and Android background jobs continue indexing within platform limits and
  complete cleanly on expiration.
- Worker concurrency is bounded by measured memory and thermal limits, not only
  theoretical throughput.
- Single-image failures are logged and skipped without stopping the queue.

### Out of scope

- Video frame extraction. Keep the deferred video-handling plan separate.
- Network services, analytics, cloud queues, or remote model execution.

