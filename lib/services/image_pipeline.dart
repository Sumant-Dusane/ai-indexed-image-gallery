import 'dart:typed_data';

import 'package:ai_gallery/core/repositories/detections_repository.dart';
import 'package:ai_gallery/core/repositories/embeddings_repository.dart';
import 'package:ai_gallery/core/repositories/faces_repository.dart';
import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';

import 'pipeline/dedup_handler.dart';
import 'pipeline/face_handler.dart';
import 'pipeline/image_processing_context.dart';
import 'pipeline/inference_handler.dart';
import 'pipeline/indexing_handler.dart';
import 'pipeline/mark_complete_handler.dart';

class ImageIndexingPipeline {
  final IndexingHandler _chain;

  ImageIndexingPipeline({
    required InferenceRepository inference,
    required PhotosDbRepository photosDb,
    required DetectionsRepository detections,
    required FacesRepository faces,
    required EmbeddingsRepository embeddings,
  }) : _chain = _buildChain(
         inference: inference,
         photosDb: photosDb,
         detections: detections,
         faces: faces,
         embeddings: embeddings,
       );

  Future<void> run({
    required String assetId,
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    return _chain.handle(
      ImageProcessingContext(
        assetId: assetId,
        pixels: pixels,
        width: width,
        height: height,
      ),
    );
  }

  static IndexingHandler _buildChain({
    required InferenceRepository inference,
    required PhotosDbRepository photosDb,
    required DetectionsRepository detections,
    required FacesRepository faces,
    required EmbeddingsRepository embeddings,
  }) {
    final head = DedupHandler(photos: photosDb, inference: inference);
    head
        .setNext(
          InferenceHandler(
            inference: inference,
            detections: detections,
            embeddings: embeddings,
          ),
        )
        .setNext(
          FaceHandler(
            inference: inference,
            faces: faces,
            embeddings: embeddings,
          ),
        )
        .setNext(MarkCompleteHandler(photos: photosDb));
    return head;
  }
}
