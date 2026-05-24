import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/inference/inference_types.dart';
import 'package:ai_gallery/core/repositories/embeddings_repository.dart';
import 'package:ai_gallery/core/repositories/faces_repository.dart';
import 'package:ai_gallery/core/repositories/inference_repository.dart';

import 'image_processing_context.dart';
import 'indexing_handler.dart';

class FaceHandler extends IndexingHandler {
  final InferenceRepository _inference;
  final FacesRepository _faces;
  final EmbeddingsRepository _embeddings;

  FaceHandler({
    required InferenceRepository inference,
    required FacesRepository faces,
    required EmbeddingsRepository embeddings,
  }) : _inference = inference,
       _faces = faces,
       _embeddings = embeddings;

  @override
  Future<void> handle(ImageProcessingContext ctx) async {
    if (ctx.personBboxes.isEmpty) {
      await forward(ctx);
      return;
    }
    AppLogger.faces(
      '[face] processing ${ctx.personBboxes.length} face(s) for ${ctx.assetId}',
    );
    await Future.wait(ctx.personBboxes.map((bbox) => _processFace(ctx, bbox)));
    AppLogger.faces('[face] done for ${ctx.assetId}');
    await forward(ctx);
  }

  Future<void> _processFace(ImageProcessingContext ctx, BBox bbox) async {
    final faceId = _faces.insertFace(ctx.assetId, bbox);

    await Future.wait([
      _embedFace(ctx, bbox, faceId),
      _classifyEmotion(ctx, bbox, faceId),
    ]);
  }

  Future<void> _embedFace(
    ImageProcessingContext ctx,
    BBox bbox,
    int faceId,
  ) async {
    final emb = await _inference.embedFace(
      pixels: ctx.pixels,
      width: ctx.width,
      height: ctx.height,
      bbox: bbox,
    );
    _embeddings.saveFaceEmbedding(faceId, emb);
  }

  Future<void> _classifyEmotion(
    ImageProcessingContext ctx,
    BBox bbox,
    int faceId,
  ) async {
    final result = await _inference.classifyEmotion(
      pixels: ctx.pixels,
      width: ctx.width,
      height: ctx.height,
      bbox: bbox,
    );
    _faces.saveEmotion(faceId, result.label, result.confidence);
  }
}
