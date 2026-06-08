import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/models/detection.dart';
import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_detail_provider.g.dart';

typedef PhotoDetailMetadata = ({
  bool isIndexed,
  List<Detection> detections,
  String? emotion,
  double? emotionConfidence,
  int? clusterId,
  String? clusterName,
});

@riverpod
Future<PhotoDetailMetadata> photoDetailMetadata(Ref ref, String photoId) async {
  try {
    final db = await ref.read(databaseProvider.future);
    final photoRows = db.select('SELECT indexed_at FROM photos WHERE id = ?', [
      photoId,
    ]);
    final detectionRows = db.select(
      '''
      SELECT id, photo_id, label, confidence, bbox_x, bbox_y, bbox_w, bbox_h
      FROM detections
      WHERE photo_id = ?
      ORDER BY confidence DESC
      ''',
      [photoId],
    );
    final emotionRows = db.select(
      '''
      SELECT emotion, emotion_conf
      FROM faces
      WHERE photo_id = ? AND emotion IS NOT NULL
      ORDER BY emotion_conf DESC
      LIMIT 1
      ''',
      [photoId],
    );
    final clusterRows = db.select(
      '''
      SELECT c.id, c.name
      FROM faces f
      JOIN clusters c ON f.cluster_id = c.id
      WHERE f.photo_id = ? AND c.name IS NOT NULL
      ORDER BY c.name
      LIMIT 1
      ''',
      [photoId],
    );

    final emotion = emotionRows.firstOrNull;
    final cluster = clusterRows.firstOrNull;
    return (
      isIndexed: photoRows.isNotEmpty && photoRows.first['indexed_at'] != null,
      detections: [
        for (final row in detectionRows)
          Detection(
            id: row['id'] as int,
            photoId: row['photo_id'] as String,
            label: row['label'] as String,
            confidence: (row['confidence'] as num).toDouble(),
            bboxX: (row['bbox_x'] as num).toDouble(),
            bboxY: (row['bbox_y'] as num).toDouble(),
            bboxW: (row['bbox_w'] as num).toDouble(),
            bboxH: (row['bbox_h'] as num).toDouble(),
          ),
      ],
      emotion: emotion?['emotion'] as String?,
      emotionConfidence: (emotion?['emotion_conf'] as num?)?.toDouble(),
      clusterId: cluster?['id'] as int?,
      clusterName: cluster?['name'] as String?,
    );
  } catch (error, stackTrace) {
    AppLogger.gallery(
      'failed to load detail metadata for photo $photoId',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
