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
class IndexingState {
  final int total;        // total photos in library
  final int indexed;      // photos with indexed_at != NULL
  final bool isRunning;
  final String? currentPhotoId;
}

// Expose as StreamProvider<IndexingState>
```

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

## Video handling

- Applies only to assets where `media_type = 'video'`
- Extract frames at 1fps using platform FFmpegKit (add `ffmpeg_kit_flutter` package)
- Only index a frame if pHash distance to previous frame > 8 (scene change)
- Store each indexed frame as a synthetic photo_id: `{asset_id}_f{frame_ms}`
- Insert into photos table with same asset's taken_at
- Max 60 frames per video regardless of length
