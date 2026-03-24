# CLAUDE.md — Core layer

Before working here, read: `docs/schema.md` (tables, models, queries) and `docs/stack.md` (packages).

---

## What lives here

```
lib/core/
  db/
    database.dart              ← SQLite singleton, migration runner, sqlite-vec loader
    schema.dart                ← all table/column name constants (strings only, no logic)
  models/                      ← @freezed data classes only, no business logic
    photo_asset.dart
    detection.dart
    face.dart
    cluster.dart
    search_result.dart
  providers/
    database_provider.dart     ← @riverpod Database provider (async, singleton)
    indexing_provider.dart     ← @riverpod IndexingNotifier
    search_provider.dart       ← @riverpod SearchNotifier
    gallery_provider.dart      ← @riverpod Future<Map<String, List<PhotoAsset>>>
    face_cluster_provider.dart ← @riverpod FaceClusterNotifier
  repositories/
    photo_repository.dart      ← photo_manager wrapper: list assets, get pixel bytes
    inference_repository.dart  ← thin wrapper over Rust bridge, injectable/mockable
```

## database.dart rules

- Expose via a `@riverpod` async provider (singleton — use `keepAlive: true`)
- Run all migrations in order on first open — never skip, never re-run
- Load sqlite-vec extension immediately after opening DB, before creating vec0 tables
- All queries return plain Dart maps — model mapping happens in repositories, not here

## schema.dart rules

- Only string constants for table names, column names
- No SQL strings here — SQL lives in repositories and `docs/schema.md`
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

- Exact fields defined in `docs/schema.md` — do not add fields not listed there
- All models use `@freezed` annotation (see `docs/schema.md` for exact definitions)
- Each model includes `factory ModelName.fromJson(Map<String, dynamic> json) => _$ModelNameFromJson(json);`
- Run `dart run build_runner build --delete-conflicting-outputs` after changes

## Providers

- All providers use `@riverpod` annotation from `riverpod_generator`
- Notifiers extend `_$NotifierName` (generated base class)
- No classic `StateNotifierProvider` or `StreamProvider` declarations
- See phase-specific docs for provider state shapes:
  - `docs/pipeline.md` → IndexingNotifier + IndexingState
  - `docs/search.md` → SearchNotifier + SearchState
  - `docs/clustering.md` → FaceClusterNotifier + FaceClusterState
