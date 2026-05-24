import 'package:ai_gallery/core/db/schema.dart';
import 'package:ai_gallery/core/inference/inference_types.dart';
import 'package:sqlite3/sqlite3.dart';

class FacesRepository {
  final Database _db;

  FacesRepository(this._db);

  int insertFace(String photoId, BBox bbox) {
    _db.execute(
      'INSERT INTO ${Tables.faces}(photo_id, bbox_x, bbox_y, bbox_w, bbox_h) VALUES(?,?,?,?,?)',
      [photoId, bbox.x, bbox.y, bbox.w, bbox.h],
    );
    return _db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
  }

  void saveEmotion(int faceId, String emotion, double confidence) {
    _db.execute(
      'UPDATE ${Tables.faces} SET emotion = ?, emotion_conf = ? WHERE id = ?',
      [emotion, confidence, faceId],
    );
  }
}
