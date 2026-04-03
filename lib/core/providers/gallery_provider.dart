import 'package:ai_gallery/core/db/schema.dart';
import 'package:ai_gallery/core/models/photo_asset.dart';
import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_provider.g.dart';

/// Returns all photos from the DB grouped by month key `'YYYY-MM'`,
/// ordered newest-month first, newest photo first within each month.
@riverpod
Future<Map<String, List<PhotoAsset>>> gallery(Ref ref) async {
  final db = await ref.watch(databaseProvider.future);

  final rows = db.select(
    'SELECT '
    '${Columns.id}, ${Columns.localPath}, ${Columns.takenAt}, '
    '${Columns.width}, ${Columns.height}, ${Columns.mediaType}, '
    '${Columns.phash}, ${Columns.indexedAt}, ${Columns.clipVersion} '
    'FROM ${Tables.photos} '
    'ORDER BY ${Columns.takenAt} DESC',
  );

  print(rows);

  final grouped = <String, List<PhotoAsset>>{};
  for (final row in rows) {
    final asset = _rowToPhotoAsset(row);
    grouped.putIfAbsent(_monthKey(asset.takenAt), () => []).add(asset);
  }
  return grouped;
}

PhotoAsset _rowToPhotoAsset(Map<String, dynamic> row) {
  final takenAtSec = row[Columns.takenAt] as int?;
  final indexedAtSec = row[Columns.indexedAt] as int?;
  return PhotoAsset(
    id: row[Columns.id] as String,
    localPath: row[Columns.localPath] as String?,
    takenAt: takenAtSec != null
        ? DateTime.fromMillisecondsSinceEpoch(takenAtSec * 1000)
        : null,
    width: row[Columns.width] as int?,
    height: row[Columns.height] as int?,
    mediaType: row[Columns.mediaType] as String,
    phash: row[Columns.phash] as String?,
    indexedAt: indexedAtSec != null
        ? DateTime.fromMillisecondsSinceEpoch(indexedAtSec * 1000)
        : null,
    clipVersion: row[Columns.clipVersion] as int? ?? 1,
  );
}

String _monthKey(DateTime? dt) {
  if (dt == null) return 'Unknown';
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
}
