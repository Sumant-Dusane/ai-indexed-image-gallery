import 'package:ai_gallery/core/db/schema.dart';
import 'package:ai_gallery/rust/features/detection/detection_types.dart';
import 'package:sqlite3/sqlite3.dart';

class DetectionsRepository {
  final Database _db;

  DetectionsRepository(this._db);

  void saveAll(String photoId, List<Detection> detections) {
    for (final d in detections) {
      _db.execute(
        'INSERT INTO ${Tables.detections}'
        '(photo_id, label, confidence, bbox_x, bbox_y, bbox_w, bbox_h) '
        'VALUES(?,?,?,?,?,?,?)',
        [photoId, d.label, d.confidence, d.bbox.x, d.bbox.y, d.bbox.w, d.bbox.h],
      );
    }
  }
}
