# docs/schema.md — Database schema

Single SQLite file: `getApplicationDocumentsDirectory()/gallery.db`
sqlite-vec extension must be loaded before any vec0 table is accessed.
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

CREATE VIRTUAL TABLE photo_clip_vss USING vec0(
  photo_id     TEXT NOT NULL,
  embedding    FLOAT[512]
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

CREATE VIRTUAL TABLE face_vss USING vec0(
  face_id      INTEGER NOT NULL,
  embedding    FLOAT[128]
);

CREATE TABLE clusters (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT,              -- user-assigned name, NULL until named
  cover_face_id INTEGER REFERENCES faces(id),
  member_count  INTEGER DEFAULT 0
);

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
SELECT p.id, p.local_path, p.taken_at,
       vec_distance_cosine(pv.embedding, ?) AS score
FROM photo_clip_vss pv
JOIN photos p ON pv.photo_id = p.id
WHERE p.taken_at BETWEEN ? AND ?          -- optional date filter
ORDER BY score ASC
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
SELECT fv.face_id, fv.embedding
FROM face_vss fv
JOIN faces f ON fv.face_id = f.id
```
