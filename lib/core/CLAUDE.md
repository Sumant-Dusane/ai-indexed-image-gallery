# CLAUDE.md — Core layer

Read before any work in lib/core/.
Schema reference: @docs/schema.md
Stack reference: @docs/stack.md

---

## What lives here

```
lib/core/
  db/
    database.dart              ← SQLite singleton, migration runner, sqlite-vec loader
    schema.dart                ← all table/column name constants (strings only, no logic)
  models/                      ← data classes only, no business logic
    photo_asset.dart
    detection.dart
    face.dart
    cluster.dart
    search_result.dart
  providers/
    indexing_provider.dart     ← StreamProvider<IndexingState>
    search_provider.dart       ← StateNotifierProvider<SearchNotifier, SearchState>
    gallery_provider.dart      ← FutureProvider<Map<String, List<PhotoAsset>>>
    face_cluster_provider.dart ← StateNotifierProvider<ClusterNotifier, FaceClusterState>
  repositories/
    inference_repository.dart  ← thin wrapper over Rust bridge, injectable/mockable
```

## database.dart rules

- Expose a single `Database get db` getter (lazy init, singleton)
- Run all migrations in order on first open — never skip, never re-run
- Load sqlite-vec extension immediately after opening DB
- Extension path: platform-specific, resolved via `DynamicLibrary.open()`
- All queries return plain Dart maps — model mapping happens in repositories, not here

## schema.dart rules

- Only string constants for table names, column names
- No SQL strings here — SQL lives in repositories and docs/schema.md
- Example:
  ```dart
  class Tables {
    static const photos = 'photos';
    static const detections = 'detections';
    static const faces = 'faces';
    static const clusters = 'clusters';
  }
  class Columns {
    static const photoId = 'photo_id';
    static const indexedAt = 'indexed_at';
    // ...
  }
  ```

## Model classes

Exact fields defined in @docs/schema.md — do not add fields not listed there.
All models are immutable (`final` fields, `copyWith` method, no setters).
Use `freezed` package if already in pubspec; otherwise plain Dart classes.
