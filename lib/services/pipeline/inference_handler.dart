import 'package:ai_gallery/core/repositories/detections_repository.dart';
import 'package:ai_gallery/core/repositories/embeddings_repository.dart';
import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:ai_gallery/rust/shared/types/bbox.dart';

import 'image_processing_context.dart';
import 'indexing_handler.dart';

class InferenceHandler extends IndexingHandler {
  final InferenceRepository _inference;
  final DetectionsRepository _detections;
  final EmbeddingsRepository _embeddings;

  InferenceHandler({
    required InferenceRepository inference,
    required DetectionsRepository detections,
    required EmbeddingsRepository embeddings,
  }) : _inference = inference,
       _detections = detections,
       _embeddings = embeddings;

  @override
  Future<void> handle(ImageProcessingContext ctx) async {
    List<BBox>? personBboxes;

    await Future.wait([
      _runClip(ctx),
      _runYolo(ctx, onPersonBboxes: (b) => personBboxes = b),
    ]);

    ctx.personBboxes = personBboxes ?? const [];
    await forward(ctx);
  }

  Future<void> _runClip(ImageProcessingContext ctx) async {
    final embedding = await _inference.embedImage(
      pixels: ctx.pixels,
      width: ctx.width,
      height: ctx.height,
    );
    _embeddings.savePhotoEmbedding(ctx.assetId, embedding);
  }

  Future<void> _runYolo(
    ImageProcessingContext ctx, {
    required void Function(List<BBox>) onPersonBboxes,
  }) async {
    final detected = await _inference.detectObjects(
      pixels: ctx.pixels,
      width: ctx.width,
      height: ctx.height,
    );

    final nonPersons = detected
        .where((d) => d.label.toLowerCase() != 'person')
        .toList();
    _detections.saveAll(ctx.assetId, nonPersons);

    onPersonBboxes(
      detected
          .where((d) => d.label.toLowerCase() == 'person')
          .map((d) => d.bbox)
          .toList(),
    );
  }
}
