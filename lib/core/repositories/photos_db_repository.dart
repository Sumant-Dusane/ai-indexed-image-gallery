import 'package:ai_gallery/core/db/schema.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sqlite3/sqlite3.dart';

class PhotosDbRepository {
  final Database _db;

  PhotosDbRepository(this._db);

  void upsertAsset(AssetEntity asset, String? localPath) {
    _db.execute(
      'INSERT OR IGNORE INTO ${Tables.photos}'
      '(id, local_path, taken_at, width, height, media_type) '
      'VALUES(?,?,?,?,?,?)',
      [
        asset.id,
        localPath,
        asset.createDateTime.millisecondsSinceEpoch ~/ 1000,
        asset.width,
        asset.height,
        asset.type == AssetType.video ? 'video' : 'image',
      ],
    );
  }

  void deleteAssets(List<String> assetIds) {
    if (assetIds.isEmpty) return;
    final placeholders = List.filled(assetIds.length, '?').join(',');
    _db.execute(
      'DELETE FROM ${Tables.photos} WHERE id IN ($placeholders)',
      assetIds,
    );
  }

  List<String> queryUnindexedQueue() {
    return _db
        .select('''
          SELECT id FROM ${Tables.photos}
          WHERE indexed_at IS NULL
          ORDER BY
            CASE WHEN taken_at > (strftime('%s','now') - 7776000) THEN 0 ELSE 1 END,
            taken_at DESC
        ''')
        .map((row) => row[Columns.id] as String)
        .toList();
  }

  int countIndexed() {
    return _db
            .select(
              'SELECT COUNT(*) AS c FROM ${Tables.photos} WHERE indexed_at IS NOT NULL',
            )
            .first['c']
        as int? ??
        0;
  }

  ({int total, int indexed}) countPhotos() {
    final total =
        _db.select('SELECT COUNT(*) AS c FROM ${Tables.photos}').first['c']
            as int? ??
        0;
    final indexed =
        _db
                .select(
                  'SELECT COUNT(*) AS c FROM ${Tables.photos} WHERE indexed_at IS NOT NULL',
                )
                .first['c']
            as int? ??
        0;
    return (total: total, indexed: indexed);
  }

  void setLocalPath(String assetId, String path) {
    _db.execute(
      'UPDATE ${Tables.photos} SET local_path = ? WHERE id = ? AND local_path IS NULL',
      [path, assetId],
    );
  }

  bool hasDuplicate(String phash) {
    return _db.select(
      'SELECT id FROM ${Tables.photos} '
      'WHERE phash = ? AND indexed_at IS NOT NULL',
      [phash],
    ).isNotEmpty;
  }

  void markDuplicate(String assetId, String phash) =>
      _markComplete(assetId, phash);

  void markComplete(String assetId, String phash) =>
      _markComplete(assetId, phash);

  void _markComplete(String assetId, String phash) {
    _db.execute(
      'UPDATE ${Tables.photos} SET indexed_at = ?, phash = ? WHERE id = ?',
      [_unixNow(), phash, assetId],
    );
  }

  static int _unixNow() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
