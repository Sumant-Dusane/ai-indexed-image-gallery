import 'package:ai_gallery/core/repositories/detections_repository.dart';
import 'package:ai_gallery/core/repositories/embeddings_repository.dart';
import 'package:ai_gallery/core/repositories/faces_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';
import 'package:ai_gallery/rust/features/detection/detection_types.dart';
import 'package:ai_gallery/rust/shared/types/bbox.dart';
import 'package:sqlite3/sqlite3.dart';

/// A single face's captured data.
typedef FaceCapture = ({
  int id,
  BBox bbox,
  String? emotion,
  double? emotionConf,
});

/// Captures CLIP and face embeddings instead of persisting them.
class CapturingEmbeddingsRepository extends EmbeddingsRepository {
  List<double>? photoEmbedding;
  final Map<int, List<double>> faceEmbeddings = {};

  CapturingEmbeddingsRepository() : super(sqlite3.openInMemory());

  @override
  void savePhotoEmbedding(String photoId, List<double> embedding) {
    photoEmbedding = embedding;
  }

  @override
  void saveFaceEmbedding(int faceId, List<double> embedding) {
    faceEmbeddings[faceId] = embedding;
  }
}

/// Captures YOLO non-person detections instead of persisting them.
class CapturingDetectionsRepository extends DetectionsRepository {
  final List<Detection> captured = [];

  CapturingDetectionsRepository() : super(sqlite3.openInMemory());

  @override
  void saveAll(String photoId, List<Detection> detections) {
    captured.addAll(detections);
  }
}

/// Captures face bbox and emotion results instead of persisting them.
class CapturingFacesRepository extends FacesRepository {
  final List<FaceCapture> captures = [];
  int _nextId = 1;

  CapturingFacesRepository() : super(sqlite3.openInMemory());

  @override
  int insertFace(String photoId, BBox bbox) {
    final id = _nextId++;
    captures.add((id: id, bbox: bbox, emotion: null, emotionConf: null));
    return id;
  }

  @override
  void saveEmotion(int faceId, String emotion, double confidence) {
    final idx = captures.indexWhere((f) => f.id == faceId);
    if (idx >= 0) {
      final existing = captures[idx];
      captures[idx] = (
        id: existing.id,
        bbox: existing.bbox,
        emotion: emotion,
        emotionConf: confidence,
      );
    }
  }
}

/// No-op photos repo: always reports no duplicate so inference always runs.
/// Captures the phash that MarkCompleteHandler writes.
class NullPhotosDbRepository extends PhotosDbRepository {
  String? capturedPhash;

  NullPhotosDbRepository() : super(sqlite3.openInMemory());

  @override
  bool hasDuplicate(String phash) => false;

  @override
  void markDuplicate(String assetId, String phash) {
    capturedPhash = phash;
  }

  @override
  void markComplete(String assetId, String phash) {
    capturedPhash = phash;
  }
}
