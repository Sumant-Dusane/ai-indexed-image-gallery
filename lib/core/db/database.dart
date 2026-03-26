import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vector/sqlite_vector.dart';

class AppDatabase {
  AppDatabase._();

  /// Opens the DB, loads the sqlite_vector extension, runs pending migrations,
  /// and initialises vector indexes. Returns the ready-to-use [Database].
  static Future<Database> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/gallery.db';

    final db = sqlite3.open(path);

    // Load vector extension immediately after open — must happen before any
    // vec0-dependent SQL.
    sqlite3.loadSqliteVectorExtension();

    _runMigrations(db);

    // Initialise vector indexes for both embedding tables (idempotent call).
    db.execute(
      "SELECT vector_init('photo_embeddings', 'embedding', "
      "'type=FLOAT32,dimension=512,distance=COSINE')",
    );
    db.execute(
      "SELECT vector_init('face_embeddings', 'embedding', "
      "'type=FLOAT32,dimension=128,distance=COSINE')",
    );

    return db;
  }

  static void _runMigrations(Database db) {
    // Create a migrations tracking table if it doesn't exist.
    db.execute('''
      CREATE TABLE IF NOT EXISTS _migrations (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL
      )
    ''');

    final applied = db
        .select('SELECT version FROM _migrations ORDER BY version')
        .map((r) => r['version'] as int)
        .toSet();

    if (!applied.contains(1)) {
      _migration001(db);
      db.execute('INSERT INTO _migrations(version, applied_at) VALUES(1, ?)', [
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ]);
    }
  }

  static void _migration001(Database db) {
    db.execute('''
      CREATE TABLE photos (
        id           TEXT PRIMARY KEY,
        local_path   TEXT,
        taken_at     INTEGER,
        width        INTEGER,
        height       INTEGER,
        media_type   TEXT CHECK(media_type IN ('image','video')),
        phash        TEXT,
        indexed_at   INTEGER,
        clip_version INTEGER DEFAULT 1
      )
    ''');

    db.execute('''
      CREATE TABLE photo_embeddings (
        photo_id  TEXT PRIMARY KEY REFERENCES photos(id) ON DELETE CASCADE,
        embedding BLOB NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE detections (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id     TEXT NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
        label        TEXT NOT NULL,
        confidence   REAL NOT NULL,
        bbox_x       REAL, bbox_y REAL,
        bbox_w       REAL, bbox_h REAL
      )
    ''');

    db.execute('''
      CREATE TABLE clusters (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT,
        cover_face_id INTEGER REFERENCES faces(id),
        member_count  INTEGER DEFAULT 0
      )
    ''');

    db.execute('''
      CREATE TABLE faces (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id     TEXT NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
        cluster_id   INTEGER REFERENCES clusters(id),
        emotion      TEXT CHECK(emotion IN
                     ('happy','sad','angry','surprised','fear','disgust','neutral')),
        emotion_conf REAL,
        bbox_x       REAL, bbox_y REAL,
        bbox_w       REAL, bbox_h REAL
      )
    ''');

    db.execute('''
      CREATE TABLE face_embeddings (
        face_id   INTEGER PRIMARY KEY REFERENCES faces(id) ON DELETE CASCADE,
        embedding BLOB NOT NULL
      )
    ''');

    db.execute('CREATE INDEX idx_photos_taken_at   ON photos(taken_at)');
    db.execute('CREATE INDEX idx_photos_indexed_at ON photos(indexed_at)');
    db.execute('CREATE INDEX idx_photos_phash      ON photos(phash)');
    db.execute('CREATE INDEX idx_detections_label  ON detections(label)');
    db.execute('CREATE INDEX idx_detections_photo  ON detections(photo_id)');
    db.execute('CREATE INDEX idx_faces_cluster     ON faces(cluster_id)');
    db.execute('CREATE INDEX idx_faces_photo       ON faces(photo_id)');
    db.execute('CREATE INDEX idx_faces_emotion     ON faces(emotion)');
  }
}
