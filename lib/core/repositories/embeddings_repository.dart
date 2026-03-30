import 'dart:typed_data';

import 'package:ai_gallery/core/db/schema.dart';
import 'package:sqlite3/sqlite3.dart';

class EmbeddingsRepository {
  final Database _db;

  EmbeddingsRepository(this._db);

  void savePhotoEmbedding(String photoId, List<double> embedding) {
    _db.execute(
      'INSERT OR REPLACE INTO ${Tables.photoEmbeddings}(photo_id, embedding) VALUES(?, ?)',
      [photoId, _toFloat32Blob(embedding)],
    );
  }

  void saveFaceEmbedding(int faceId, List<double> embedding) {
    _db.execute(
      'INSERT INTO ${Tables.faceEmbeddings}(face_id, embedding) VALUES(?, ?)',
      [faceId, _toFloat32Blob(embedding)],
    );
  }

  static Uint8List _toFloat32Blob(List<double> values) {
    final bd = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      bd.setFloat32(i * 4, values[i], Endian.little);
    }
    return bd.buffer.asUint8List();
  }
}
