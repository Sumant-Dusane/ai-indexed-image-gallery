# AI Gallery — Session-by-Session Prompt Playbook

## Context
Exact prompts to paste into Claude Code for building the AI Gallery app across ~15 sessions spanning 6 phases. Includes when to clear context, what to verify, and how to recover.

---

## Ground Rules

### When to clear context (`/clear` or new session)
- **Always** between phases (Phase 1 → Phase 2)
- **Always** after committing a working checkpoint
- **Within a phase** if the session has gone on for 20+ tool calls or Claude starts repeating itself / forgetting earlier work
- **After fixing a build error** that took multiple back-and-forth attempts — clear and start fresh with the fix committed

### Before every session
1. Make sure previous work is committed (`git status` clean)
2. Update `CLAUDE.md` current phase line if needed
3. Have the prompt ready — paste it, don't type it interactively

### After every session
1. Run `flutter analyze` — fix any issues before committing
2. Run `dart run build_runner build --delete-conflicting-outputs` if freezed/riverpod files were touched
3. `git add` + `git commit` with a descriptive message
4. Only then clear context or start next session

### If Claude goes off-track
- Say: "Stop. Re-read docs/[relevant].md and lib/[relevant]/CLAUDE.md. The spec says X but you did Y. Fix it."
- If it keeps drifting: commit what's good, clear context, start a focused fix session

---

## Phase 1 — Skeleton (3 sessions)

### Session 1A: Flutter project + core layer

```
Phase 1 — Skeleton. Read docs/stack.md, docs/skeleton.md, docs/schema.md, and lib/core/CLAUDE.md.

Create the Flutter project foundation:
1. pubspec.yaml with all dependencies from docs/stack.md (separate dependencies vs dev_dependencies correctly)
2. lib/main.dart and lib/app.dart — exact structure from docs/skeleton.md
3. lib/router/app_router.dart — GoRouter with StatefulShellRoute, ScaffoldWithNavBar, all routes from docs/skeleton.md
4. lib/core/db/schema.dart — table/column name constants
5. lib/core/models/ — all 5 @freezed model classes from docs/schema.md (photo_asset.dart, detection.dart, face.dart, cluster.dart, search_result.dart)
6. Run build_runner to generate freezed files

Do NOT create database.dart yet (next session). Do NOT create any feature screens yet.
```

**Verify:** `flutter analyze` passes, generated `.freezed.dart` and `.g.dart` files exist for all models.

**Commit, then clear context.**

---

### Session 1B: Database + repositories + feature placeholders

```
Phase 1 — Skeleton continued. Read docs/stack.md, docs/skeleton.md, docs/schema.md, and lib/core/CLAUDE.md.

Previous session created: pubspec.yaml, main.dart, app.dart, router, schema.dart, all freezed models.

Now build:
1. lib/core/db/database.dart — SQLite singleton with sqlite-vec extension loading and migration 001 (all CREATE TABLE/INDEX from docs/schema.md)
2. lib/core/providers/database_provider.dart — @riverpod async provider, keepAlive
3. lib/core/repositories/photo_repository.dart — photo_manager wrapper (list assets, get thumbnail bytes, get full-res bytes)
4. lib/core/repositories/inference_repository.dart — stub wrapper over Rust bridge (all 6 methods return dummy/empty data for now)
5. Placeholder screens in lib/features/: gallery_screen.dart, search_screen.dart, people_screen.dart, onboarding_screen.dart — minimal Scaffolds with AppBar and placeholder text
6. Run build_runner for any new riverpod providers

After this, `flutter run` should launch and show the 3-tab bottom navigation with placeholder screens.
```

**Verify:** App launches on simulator, 3 tabs work, no crashes. `flutter analyze` clean.

**Commit, then clear context.**

---

### Session 1C: Rust crate + flutter_rust_bridge setup

```
Phase 1 — Skeleton continued. Read docs/stack.md, docs/skeleton.md, rust/CLAUDE.md, and docs/models.md (just the "Reference: flutter_rust_bridge v2 setup" section).

Previous sessions created the full Flutter side. Now build the Rust crate:

1. rust/Cargo.toml with all dependencies from docs/stack.md Rust section + rust/CLAUDE.md
2. rust/src/lib.rs — module declarations
3. rust/src/api.rs — all 6 bridge function stubs (todo!()) + init_models() + shared types (Detection, BBox, EmotionResult) from rust/CLAUDE.md
4. Set up flutter_rust_bridge v2 codegen — run `flutter_rust_bridge_codegen generate`
5. Update lib/core/repositories/inference_repository.dart to import the generated Dart bridge and call the real (stubbed) Rust functions
6. Verify the bridge compiles: `flutter build ios --simulator` or `flutter build apk --debug`

Focus on getting the bridge working end-to-end, even though all Rust functions are todo!().
```

**Verify:** `cargo check` passes in rust/. Bridge codegen produces Dart files. Flutter build succeeds (even if Rust functions would panic at runtime).

**Commit. Update CLAUDE.md: Phase 1 → complete. Clear context.**

---

## Phase 2 — Rust Inference (3 sessions)

### Session 2A: CLIP model (image + text embedding)

```
Phase 2 — Rust inference layer. Read docs/models.md and rust/CLAUDE.md.

Phase 1 is committed. Build the CLIP inference module:

1. rust/src/inference/mod.rs — init_models() that stores model_dir path, OnceLock session management
2. rust/src/utils/preprocess.rs — shared resize/normalize helpers
3. rust/src/inference/clip.rs — implement embed_image():
   - Preprocessing: exact steps from docs/models.md MobileCLIP-S1 (image) section
   - ort Session via OnceLock, input tensor [1,3,224,224], L2-normalize output
4. rust/src/inference/clip.rs — implement embed_text():
   - BPE tokenization using tokenizers crate with assets/models/bpe_vocab.json
   - Input tensor [1,77] int32, L2-normalize output
5. Wire both into rust/src/api.rs (replace todo!())

Touch only: rust/src/inference/mod.rs, rust/src/inference/clip.rs, rust/src/utils/preprocess.rs, rust/src/api.rs
```

**Verify:** `cargo check` passes. Ideally write a small Rust test with a dummy image buffer.

**Commit, then clear context.**

---

### Session 2B: YOLO object detection + NMS

```
Phase 2 — Rust inference layer continued. Read docs/models.md and rust/CLAUDE.md.

CLIP module is committed. Build YOLO detection:

1. rust/src/utils/nms.rs — non-maximum suppression (confidence threshold 0.35, IoU threshold 0.45)
2. rust/src/inference/yolo.rs — implement detect_objects():
   - Preprocessing: exact steps from docs/models.md YOLOv8-nano section
   - Letterbox resize to 640x640
   - Parse output [1,84,8400] → apply NMS → scale back to original dims → normalize to 0..1
   - Filter to allowed classes only (list in docs/models.md YOLO class filter)
3. Wire into rust/src/api.rs (replace todo!())

Touch only: rust/src/inference/yolo.rs, rust/src/utils/nms.rs, rust/src/api.rs
```

**Verify:** `cargo check` passes.

**Commit, then clear context.**

---

### Session 2C: Face embedding + emotion + pHash

```
Phase 2 — Rust inference layer continued. Read docs/models.md and rust/CLAUDE.md.

CLIP and YOLO are committed. Build remaining models:

1. rust/src/inference/face.rs — implement embed_face():
   - Crop face from bbox (expand 20%, clamp), resize 112x112
   - Exact preprocessing from docs/models.md MobileFaceNet section
   - L2-normalize 128-dim output
2. rust/src/inference/emotion.rs — implement classify_emotion():
   - Same crop, resize to 224x224
   - Exact preprocessing from docs/models.md EfficientNet-lite section
   - Softmax → argmax → emotion label from EMOTION_LABELS constant
3. rust/src/utils/phash.rs — implement compute_phash():
   - Exact algorithm from docs/models.md pHash section (32x32 grayscale, DCT, 64-bit hash)
4. Wire all into rust/src/api.rs (replace remaining todo!())

Touch only: rust/src/inference/face.rs, rust/src/inference/emotion.rs, rust/src/utils/phash.rs, rust/src/api.rs
```

**Verify:** `cargo check` passes. All 6 bridge functions + init_models implemented. No remaining `todo!()`.

**Commit. Update CLAUDE.md: Phase 2 → complete. Clear context.**

---

## Phase 3 — IndexingService (2 sessions)

### Session 3A: Core indexing pipeline

```
Phase 3 — IndexingService. Read docs/pipeline.md, docs/schema.md, lib/services/CLAUDE.md, and lib/core/CLAUDE.md.

Phases 1 and 2 are committed. Build the indexing pipeline:

1. lib/services/indexing_service.dart — implement IndexingService class:
   - syncPhotoLibrary(): load all photo_manager assets into photos table
   - startIndexing(): build priority queue, process images through 4-step pipeline (DEDUP → PARALLEL INFERENCE → FACE PIPELINE → MARK COMPLETE)
   - pause(): stop processing, persist position
   - Concurrency: 4 images parallel, cap 8 Rust calls
   - Use exact SQL from docs/schema.md
2. lib/core/providers/indexing_provider.dart — @riverpod IndexingNotifier with IndexingState (@freezed from docs/pipeline.md)
3. Run build_runner

Touch only: lib/services/indexing_service.dart, lib/core/providers/indexing_provider.dart
Do NOT build background tasks yet (next session).
```

**Verify:** `flutter analyze` clean. Provider generates correctly.

**Commit, then clear context.**

---

### Session 3B: Background tasks + delta indexing + gallery provider

```
Phase 3 — IndexingService continued. Read docs/pipeline.md and lib/core/CLAUDE.md.

Core pipeline is committed. Now add:

1. Background task registration in lib/services/indexing_service.dart:
   - iOS BGProcessingTask setup (exact config from docs/pipeline.md)
   - Android WorkManager setup (exact config from docs/pipeline.md)
2. Delta indexing: photo_manager change observer (onAssetsAdded, onAssetsDeleted)
3. Throttling: battery and thermal checks from docs/pipeline.md
4. lib/core/providers/gallery_provider.dart — @riverpod provider that queries photos grouped by month
5. Update lib/features/gallery/gallery_screen.dart to actually display photo thumbnails using galleryProvider (basic grid, no polish)

Touch only: lib/services/indexing_service.dart, lib/core/providers/gallery_provider.dart, lib/features/gallery/gallery_screen.dart
```

**Verify:** App launches, gallery shows real photos. Indexing starts in foreground. `flutter analyze` clean.

**Commit. Update CLAUDE.md: Phase 3 → complete. Clear context.**

---

## Phase 4 — QueryService + Search UI (2 sessions)

### Session 4A: QueryService

```
Phase 4 — QueryService. Read docs/search.md, docs/schema.md, and lib/services/CLAUDE.md.

Phases 1-3 are committed. Build the search pipeline:

1. lib/services/query_service.dart — implement QueryService:
   - Step 1: Parse intent (date parsing, emotion mapping, person name matching) — exact patterns from docs/search.md
   - Step 2: Encode text via Rust bridge
   - Step 3+4: Vector search with metadata filters — use exact SQL from docs/search.md
   - Step 5: Re-rank (70% semantic + 30% recency) — exact formula from docs/search.md
   - Step 6: Return top 50
2. lib/core/providers/search_provider.dart — @riverpod SearchNotifier with SearchState (@freezed from docs/search.md), 400ms debounce
3. Run build_runner

Touch only: lib/services/query_service.dart, lib/core/providers/search_provider.dart
```

**Verify:** `flutter analyze` clean. Provider generates correctly.

**Commit, then clear context.**

---

### Session 4B: Search UI

```
Phase 4 — Search UI. Read docs/ui-spec.md (SearchScreen section) and lib/features/search/CLAUDE.md.

QueryService is committed. Build the search screen:

1. lib/features/search/search_screen.dart — full search UI from docs/ui-spec.md
2. lib/features/search/search_bar.dart — reusable search input widget
3. lib/features/search/search_results_grid.dart — 3-col results grid
4. lib/features/search/search_empty_state.dart — suggestion chips + no-results state
5. All screens consume searchProvider and indexingProvider — do NOT implement any search logic here

Touch only files in lib/features/search/
```

**Verify:** Search tab works. Typing a query returns results from indexed photos. Suggestion chips display.

**Commit. Update CLAUDE.md: Phase 4 → complete. Clear context.**

---

## Phase 5 — Face Clustering + People (2 sessions)

### Session 5A: FaceClusterService

```
Phase 5 — Face clustering. Read docs/clustering.md, docs/schema.md, and lib/services/CLAUDE.md.

Phases 1-4 are committed. Build DBSCAN clustering:

1. lib/services/face_cluster_service.dart — implement FaceClusterService:
   - runFullClustering(): DBSCAN with epsilon=0.4, minPts=3 — exact algorithm from docs/clustering.md
   - runIncrementalClustering(): nearest centroid assignment
   - nameCluster(): update cluster name
   - assignNewFace(): assign or leave as noise
   - All heavy work in compute() isolate
2. lib/core/providers/face_cluster_provider.dart — @riverpod FaceClusterNotifier with FaceClusterState (@freezed from docs/clustering.md)
3. Run build_runner

Touch only: lib/services/face_cluster_service.dart, lib/core/providers/face_cluster_provider.dart
```

**Verify:** `flutter analyze` clean.

**Commit, then clear context.**

---

### Session 5B: People UI

```
Phase 5 — People UI. Read docs/ui-spec.md (PeopleScreen, ClusterDetailScreen, NameFaceSheet sections) and lib/features/people/CLAUDE.md.

FaceClusterService is committed. Build the people screens:

1. lib/features/people/people_screen.dart — cluster grid from docs/ui-spec.md (unnamed first, then by member count)
2. lib/features/people/cluster_detail_screen.dart — photo grid for one cluster
3. lib/features/people/name_face_sheet.dart — bottom sheet to name a cluster
4. All screens consume faceClusterProvider — do NOT implement clustering logic here

Touch only files in lib/features/people/
```

**Verify:** People tab shows face clusters. Tapping a cluster shows its photos. Naming works.

**Commit. Update CLAUDE.md: Phase 5 → complete. Clear context.**

---

## Phase 6 — UI Polish + Onboarding (2-3 sessions)

### Session 6A: Gallery + Photo Detail real UI

```
Phase 6 — UI polish. Read docs/ui-spec.md (GalleryScreen, PhotoDetailScreen sections) and lib/features/gallery/CLAUDE.md.

Phases 1-5 are committed. Polish the gallery:

1. lib/features/gallery/gallery_screen.dart — full implementation from docs/ui-spec.md:
   - CustomScrollView, SliverAppBar, month-grouped SliverGrid, 3-col, 2px gap
   - Search bar row that navigates to /search
   - Indexing banner when in progress
2. lib/features/gallery/gallery_grid_cell.dart — thumbnail cell with Hero tag
3. lib/features/gallery/photo_detail_screen.dart — full-screen with InteractiveViewer, info sheet, detection chips, emotion chip, person chip

Touch only files in lib/features/gallery/
```

**Verify:** Gallery looks like iOS Photos. Photo detail shows detected labels, emotions, people.

**Commit, then clear context.**

---

### Session 6B: Onboarding + theme

```
Phase 6 — Onboarding. Read docs/ui-spec.md (OnboardingScreen, Theme sections) and lib/features/onboarding/CLAUDE.md.

Gallery is polished. Build onboarding:

1. lib/features/onboarding/onboarding_screen.dart — full implementation from docs/ui-spec.md:
   - Progress bar, counter text, 3 phase checkmarks
   - SharedPreferences onboarding_complete flag
   - "Skip for now" → navigate to gallery, indexing continues in background
2. Update lib/app.dart theme to match docs/ui-spec.md Theme section exactly (light + dark)
3. Update router redirect: check onboarding_complete, route to onboarding or gallery

Touch only: lib/features/onboarding/onboarding_screen.dart, lib/app.dart, lib/router/app_router.dart
```

**Verify:** Fresh install shows onboarding. Skip works. App theme matches iOS Photos aesthetic. Dark mode works.

**Commit. Update CLAUDE.md: Phase 6 → complete. Clear context.**

---

### Session 6C (if needed): Bug fixes + integration testing

```
Final polish session. Do NOT read any docs unless I point you to one.

Run the app end-to-end and fix any issues I report. I will describe bugs one at a time. For each bug:
1. Read the relevant source file
2. Read the relevant spec doc if the fix involves spec behavior
3. Fix it
4. Confirm the fix doesn't break other things

Do not refactor or improve anything I haven't asked about.
```

---

## Emergency / Fix Sessions

### When a build breaks between phases

```
The app is failing to build. Here is the error:

[paste error]

Read the file(s) mentioned in the error and fix the issue. Do not change anything else. Do not refactor.
```

### When Claude drifted from spec

```
Stop. Read docs/[relevant].md. Compare it against the current implementation in [file path]. The spec says [X] but the code does [Y]. Fix the code to match the spec exactly. Do not change the spec.
```

### When you want to override a spec

```
I want to change [specific thing] from [old] to [new]. This contradicts docs/[file].md. Update the doc first, then update the code to match. Show me the doc change before changing code.
```

---

## Tracking Template (copy for personal notes)

```
## Phase 1 — Skeleton
- [x] 1A: Flutter project + core layer → commit: ___
- [x] 1B: Database + repos + placeholders → commit: ___
- [x] 1C: Rust crate + bridge → commit: ___
- [x] Update CLAUDE.md phase line

## Phase 2 — Rust Inference
- [ ] 2A: CLIP (embed_image, embed_text) → commit: ___
- [ ] 2B: YOLO (detect_objects + NMS) → commit: ___
- [ ] 2C: Face + emotion + pHash → commit: ___
- [ ] Update CLAUDE.md phase line

## Phase 3 — IndexingService`
- [ ] 3A: Core pipeline → commit: ___
- [ ] 3B: Background tasks + gallery wiring → commit: ___
- [ ] Update CLAUDE.md phase line

## Phase 4 — QueryService + Search
- [ ] 4A: QueryService → commit: ___
- [ ] 4B: Search UI → commit: ___
- [ ] Update CLAUDE.md phase line

## Phase 5 — Clustering + People
- [ ] 5A: FaceClusterService → commit: ___
- [ ] 5B: People UI → commit: ___
- [ ] Update CLAUDE.md phase line

## Phase 6 — Polish
- [ ] 6A: Gallery + Photo Detail → commit: ___
- [ ] 6B: Onboarding + theme → commit: ___
- [ ] 6C: Bug fixes (if needed) → commit: ___
- [ ] Update CLAUDE.md phase line
```
