# docs/pipeline.md — Indexing pipeline (Phase 3)

Owned by: `lib/services/indexing_service.dart`
State exposed via: `lib/core/providers/indexing_provider.dart`

---

## IndexingService public API

```dart
class IndexingService {
  // Call once on app start. Loads all known assets into photos table (no inference yet).
  Future<void> syncPhotoLibrary();

  // Start the indexing queue. Safe to call multiple times — checks isRunning guard.
  Future<void> startIndexing();

  // Pause. Persists queue position. Resumes from same point on next startIndexing().
  void pause();

  // Called by photo library change observer — queues new assets immediately.
  Future<void> onAssetsAdded(List<String> assetIds);

  // Called on deletion — removes all rows for that asset.
  Future<void> onAssetsDeleted(List<String> assetIds);
}
```

---

## IndexingProvider state shape

```dart
@freezed
class IndexingState with _$IndexingState {
  const factory IndexingState({
    @Default(0) int total,
    @Default(0) int indexed,
    @Default(false) bool isRunning,
    String? currentPhotoId,
  }) = _IndexingState;
}

// Expose via riverpod_generator:
@riverpod
class IndexingNotifier extends _$IndexingNotifier {
  @override
  IndexingState build() => const IndexingState();

  void updateState(IndexingState newState) => state = newState;
}
```

---

## Startup trigger — where and when to call sync + start

`syncAndStart()` is triggered from a single central location: **`appRouterProvider`** (`lib/router/app_router.dart`).

A `ref.listen` on `photoPermissionProvider` fires `syncAndStart()` the moment permission resolves to granted, on every app launch. This covers both first launch and subsequent launches without screen-level coordination.

```dart
// In appRouterProvider, alongside the existing permission listener:
ref.listen(photoPermissionProvider, (_, next) {
  if (!next.hasValue) return;
  if (next.value!.isGranted) {
    ref.read(indexingNotifierProvider.notifier).syncAndStart();
  }
});
```

`syncAndStart()` runs in the background — **the gallery grid does not wait for it**.
`galleryProvider` reads directly from `photo_manager` so photos appear immediately on launch.
The DB is populated by `syncPhotoLibrary()` in the background for AI search (Phase 4+).

`syncAndStart()` is a method on `IndexingNotifier` that:
1. Awaits `photoPermissionProvider` to ensure `requestPermissionExtend()` has completed before listing assets
2. Calls `syncPhotoLibrary()`
3. Calls `startIndexing()` only if `state.total > 0` (skips if the library is empty)

```dart
Future<void> syncAndStart() async {
  final permission = await ref.read(photoPermissionProvider.future);
  if (!permission.isGranted) return;
  final service = await ref.read(indexingServiceProvider.future);
  await service.syncPhotoLibrary();
  if (state.total > 0) await service.startIndexing();
}
```

Both underlying calls are safe to repeat:
- `syncPhotoLibrary()` uses INSERT OR IGNORE — re-running never duplicates rows
- `startIndexing()` has an `isRunning` guard — calling it while already running is a no-op

---

## Queue priority order (first-install batch)

Build the queue once at `startIndexing()` from photos WHERE indexed_at IS NULL:

```
Priority 1: taken_at > now - 90 days         (most recent, user searches these first)
Priority 2: taken_at <= now - 90 days        (oldest last)

Within each priority: ORDER BY taken_at DESC
```

---

## Per-image pipeline — implement exactly this order

```
STEP 1 — DEDUP
  Input:  asset id
  Action: fetch full-res pixel bytes from photo_manager
          compute pHash via Rust bridge: computePHash(pixels, w, h)
          query: SELECT id FROM photos WHERE phash = ? AND indexed_at IS NOT NULL
  If duplicate found:
    UPDATE photos SET indexed_at = unixNow(), phash = ? WHERE id = ?
    return (skip inference)

STEP 2 — PARALLEL INFERENCE
  Run these two concurrently (Future.wait):

  Task A — CLIP embedding:
    call Rust: embedImage(pixels, w, h) → List<double> length 512
    upsert into photo_clip_vss (photo_id, embedding)

  Task B — YOLO detection:
    call Rust: detectObjects(pixels, w, h) → List<Detection>
    insert all non-person detections into detections table
    collect person bounding boxes → pass to Step 3

STEP 3 — FACE PIPELINE
  Only runs if Task B returned ≥ 1 person box.
  For each person bounding box, run concurrently:

  Task C — face embed:
    call Rust: embedFace(pixels, w, h, bbox) → List<double> length 128
    insert into faces table (photo_id, bbox fields, cluster_id=NULL)
    insert into face_vss (face_id, embedding)

  Task D — emotion:
    call Rust: classifyEmotion(pixels, w, h, bbox) → String
    UPDATE faces SET emotion = ?, emotion_conf = ? WHERE id = <new face id>

STEP 4 — MARK COMPLETE
  UPDATE photos SET indexed_at = unixNow(), phash = ? WHERE id = ?
```

---

## Concurrency model

- Process 4 images in parallel (use Dart Isolate pool or `compute()` x4)
- Each image's Steps 2A+2B are concurrent within that image's isolate
- Each image's Steps 3C+3D per face are concurrent within that image's isolate
- Cap total concurrent Rust calls at 8 (4 images × 2 parallel tasks max)

---

## Throttling rules

```dart
// Check before dequeuing next batch:
if (batteryLevel < 0.20) pause();
if (thermalState == ThermalState.serious) pause();  // iOS only

// Resume automatically when constraints clear (poll every 60s)
```

---

## Background task registration

### iOS — BGProcessingTask
- Identifier: `com.aigallery.indexing`
- Requires: `requiresExternalPower = true`, `requiresNetworkConnectivity = false`
- Register in AppDelegate, schedule after `startIndexing()` is called
- On expiration handler: call `pause()` then `task.setTaskCompleted(success: false)`

### Android — WorkManager
- Constraints: `requiresCharging = true`, `requiresDeviceIdle = true`
- Worker class: `IndexingWorker`
- Enqueue as `PeriodicWorkRequest` with 1-hour minimum interval
- On `doWork()`: call `startIndexing()`, run for max 9 minutes (WorkManager limit), then pause

---

## Delta indexing (ongoing, after initial index)

```dart
// In photo_manager change observer callback:
void _onPhotoLibraryChange(ChangeNotifyEvent event) {
  final added   = event.addedIds;
  final removed = event.removedIds;
  if (added.isNotEmpty)   indexingService.onAssetsAdded(added);
  if (removed.isNotEmpty) indexingService.onAssetsDeleted(removed);
}
```

`onAssetsAdded`: insert new rows into photos table, push to FRONT of queue (priority above all).
`onAssetsDeleted`: DELETE FROM photos WHERE id IN (...) — cascade handles child tables.

---

<!-- VIDEO HANDLING — Deferred to future phase. Do not implement.

## Video handling

- Applies only to assets where `media_type = 'video'`
- Extract frames at 1fps using platform FFmpegKit (add `ffmpeg_kit_flutter` package)
- Only index a frame if pHash distance to previous frame > 8 (scene change)
- Store each indexed frame as a synthetic photo_id: `{asset_id}_f{frame_ms}`
- Insert into photos table with same asset's taken_at
- Max 60 frames per video regardless of length

-->
