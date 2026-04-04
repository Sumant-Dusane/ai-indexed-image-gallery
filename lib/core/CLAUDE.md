# CLAUDE.md — Core layer

Before working here, read: `docs/schema.md` (tables, models, queries) and `docs/stack.md` (packages).

---

## What lives here

```
lib/core/
  db/
    database.dart              ← SQLite singleton, migration runner, sqlite_vector loader
    schema.dart                ← all table/column name constants (strings only, no logic)
  debug/
    app_logger.dart            ← static debug logger, flag-controlled per category
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
    gallery_provider.dart      ← @riverpod Future<Map<String, List<AssetEntity>>> (waits on photoPermissionProvider, then reads photo_manager directly — no DB)
    photo_permission_provider.dart ← @riverpod Future<PermissionState> — requests photo library permission once; router redirect reads this to gate all main routes
    face_cluster_provider.dart ← @riverpod FaceClusterNotifier
  repositories/
    photo_repository.dart      ← photo_manager wrapper: list assets, get pixel bytes
    inference_repository.dart  ← thin wrapper over Rust bridge, injectable/mockable
```

## database.dart rules

- Expose via a `@riverpod` async provider (singleton — use `keepAlive: true`)
- Run all migrations in order on first open — never skip, never re-run
- Open DB via `sqlite3` package; call `sqlite3.loadSqliteVectorExtension()` immediately after open
- Call `vector_init()` for each embedding table (see `docs/schema.md`) before first use
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

## AppLogger

- Located at `lib/core/debug/app_logger.dart` — static class, zero dependencies
- Always a no-op in release builds (`kDebugMode = false`)
- One `LogCategory` value per subsystem: `gallery`, `indexing`, `pipeline`, `database`, `search`, `faces`
- Use the shorthand: `AppLogger.indexing('msg')` or the generic `AppLogger.log(LogCategory.x, 'msg')`
- Supports `error:` and `stackTrace:` named params on every call
- Silence a subsystem at runtime: `AppLogger.disable(LogCategory.pipeline)`
- Add a new subsystem: add a value to `LogCategory`, a shorthand method, and a `_label` case — nothing else
- Never use `print()` or `debugPrint()` directly — route everything through `AppLogger`

## Providers

- All providers use `@riverpod` annotation from `riverpod_generator`
- Notifiers extend `_$NotifierName` (generated base class)
- No classic `StateNotifierProvider` or `StreamProvider` declarations
- See phase-specific docs for provider state shapes:
  - `docs/pipeline.md` → IndexingNotifier + IndexingState
  - `docs/search.md` → SearchNotifier + SearchState
  - `docs/clustering.md` → FaceClusterNotifier + FaceClusterState
