# docs/schema.md — Database schema

Single SQLite file: `getApplicationDocumentsDirectory()/gallery.db`
Open DB via `sqlite3` package. Call `sqlite3.loadSqliteVectorExtension()` immediately after open.
Then call `vector_init()` on each embedding table (see below) before first read or write.
Run migrations in order. Never modify a migration — add a new one.

---

## Migration 001 — initial schema

```sql
CREATE TABLE photos (
  id           TEXT PRIMARY KEY,   -- photo_manager asset id
  local_path   TEXT,
  taken_at     INTEGER,            -- unix timestamp seconds
  width        INTEGER,
  height       INTEGER,
  media_type   TEXT CHECK(media_type IN ('image','video')),
  phash        TEXT,               -- 64-bit perceptual hash as hex string
  indexed_at   INTEGER,            -- unix timestamp, NULL = not yet indexed
  clip_version INTEGER DEFAULT 1   -- bump to force re-index after model update
);

CREATE TABLE photo_embeddings (
  photo_id  TEXT PRIMARY KEY REFERENCES photos(id) ON DELETE CASCADE,
  embedding BLOB NOT NULL   -- FLOAT[512] stored as raw little-endian float32 bytes
);

CREATE TABLE detections (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  photo_id     TEXT NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
  label        TEXT NOT NULL,      -- YOLO class label, lowercase
  confidence   REAL NOT NULL,
  bbox_x       REAL, bbox_y REAL,  -- normalised 0..1 relative to image dims
  bbox_w       REAL, bbox_h       REAL
);

CREATE TABLE faces (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  photo_id     TEXT NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
  cluster_id   INTEGER REFERENCES clusters(id),   -- NULL until DBSCAN runs
  emotion      TEXT CHECK(emotion IN
               ('happy','sad','angry','surprised','fear','disgust','neutral')),
  emotion_conf REAL,
  bbox_x       REAL, bbox_y REAL,
  bbox_w       REAL, bbox_h REAL
);

CREATE TABLE face_embeddings (
  face_id   INTEGER PRIMARY KEY REFERENCES faces(id) ON DELETE CASCADE,
  embedding BLOB NOT NULL   -- FLOAT[128] stored as raw little-endian float32 bytes
);

CREATE TABLE clusters (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT,              -- user-assigned name, NULL until named
  cover_face_id INTEGER REFERENCES faces(id),
  member_count  INTEGER DEFAULT 0
);

-- After creating tables, call on every new DB connection (not in migration SQL):
-- db.select("SELECT vector_init('photo_embeddings', 'embedding', 'type=FLOAT32,dimension=512,distance=COSINE')");
-- db.select("SELECT vector_init('face_embeddings',  'embedding', 'type=FLOAT32,dimension=128,distance=COSINE')");
-- vector_quantize() is persistent (call once after bulk insert, not on every open).

CREATE INDEX idx_photos_taken_at    ON photos(taken_at);
CREATE INDEX idx_photos_indexed_at  ON photos(indexed_at);
CREATE INDEX idx_photos_phash       ON photos(phash);
CREATE INDEX idx_detections_label   ON detections(label);
CREATE INDEX idx_detections_photo   ON detections(photo_id);
CREATE INDEX idx_faces_cluster      ON faces(cluster_id);
CREATE INDEX idx_faces_photo        ON faces(photo_id);
CREATE INDEX idx_faces_emotion      ON faces(emotion);
```

---

## Dart model classes — freezed, exact field names

These map 1:1 to the schema. Do not add fields not listed here.
All models use `@freezed`. Generate with `dart run build_runner build --delete-conflicting-outputs`.

```dart
@freezed
class PhotoAsset with _$PhotoAsset {
  const factory PhotoAsset({
    required String id,
    String? localPath,
    DateTime? takenAt,
    int? width,
    int? height,
    required String mediaType,
    String? phash,
    DateTime? indexedAt,
    @Default(1) int clipVersion,
  }) = _PhotoAsset;

  factory PhotoAsset.fromJson(Map<String, dynamic> json) =>
      _$PhotoAssetFromJson(json);
}

@freezed
class Detection with _$Detection {
  const factory Detection({
    int? id,
    required String photoId,
    required String label,
    required double confidence,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
  }) = _Detection;

  factory Detection.fromJson(Map<String, dynamic> json) =>
      _$DetectionFromJson(json);
}

@freezed
class Face with _$Face {
  const factory Face({
    int? id,
    required String photoId,
    int? clusterId,
    String? emotion,
    double? emotionConf,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
  }) = _Face;

  factory Face.fromJson(Map<String, dynamic> json) => _$FaceFromJson(json);
}

@freezed
class FaceCluster with _$FaceCluster {
  const factory FaceCluster({
    required int id,
    String? name,
    int? coverFaceId,
    @Default(0) int memberCount,
  }) = _FaceCluster;

  factory FaceCluster.fromJson(Map<String, dynamic> json) =>
      _$FaceClusterFromJson(json);
}

@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    required String photoId,
    required String localPath,
    DateTime? takenAt,
    required double score,
  }) = _SearchResult;

  factory SearchResult.fromJson(Map<String, dynamic> json) =>
      _$SearchResultFromJson(json);
}
```

---

## DB Repositories

All SQL lives in `lib/core/repositories/`. Handlers and services never write raw SQL directly.

| File | Tables owned | Callers |
|---|---|---|
| `photos_db_repository.dart` | `photos` | `IndexingService`, `DedupHandler`, `MarkCompleteHandler` |
| `detections_repository.dart` | `detections` | `InferenceHandler` |
| `faces_repository.dart` | `faces` | `FaceHandler` |
| `embeddings_repository.dart` | `photo_embeddings`, `face_embeddings` | `InferenceHandler`, `FaceHandler` |

---

## Common queries — copy these, do not rewrite

**Photos pending indexing (priority order):**
```sql
SELECT id, local_path, taken_at, media_type
FROM photos
WHERE indexed_at IS NULL
ORDER BY
  CASE WHEN taken_at > (strftime('%s','now') - 7776000) THEN 0 ELSE 1 END,
  taken_at DESC
```

**Vector search with metadata filter:**
```sql
-- Exact search (use before vector_quantize() is called, or when <1000 photos):
SELECT p.id, p.local_path, p.taken_at, v.distance AS score
FROM vector_full_scan('photo_embeddings', 'embedding', ?, 200) AS v
JOIN photo_embeddings pe ON v.rowid = pe.rowid
JOIN photos p ON pe.photo_id = p.id
WHERE p.taken_at BETWEEN ? AND ?          -- optional date filter
ORDER BY v.distance ASC
LIMIT 200

-- ANN search (after vector_quantize() has been called on photo_embeddings):
SELECT p.id, p.local_path, p.taken_at, v.distance AS score
FROM vector_quantize_scan('photo_embeddings', 'embedding', ?, 200) AS v
JOIN photo_embeddings pe ON v.rowid = pe.rowid
JOIN photos p ON pe.photo_id = p.id
WHERE p.taken_at BETWEEN ? AND ?
ORDER BY v.distance ASC
LIMIT 200
```

**Photos by cluster:**
```sql
SELECT DISTINCT p.id, p.local_path, p.taken_at
FROM faces f
JOIN photos p ON f.photo_id = p.id
WHERE f.cluster_id = ?
ORDER BY p.taken_at DESC
```

**All face embeddings for DBSCAN:**
```sql
SELECT fe.face_id, fe.embedding
FROM face_embeddings fe
JOIN faces f ON fe.face_id = f.id
```
