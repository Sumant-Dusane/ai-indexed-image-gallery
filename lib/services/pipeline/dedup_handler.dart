import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';

import 'image_processing_context.dart';
import 'indexing_handler.dart';

class DedupHandler extends IndexingHandler {
  final PhotosDbRepository _photos;
  final InferenceRepository _inference;

  DedupHandler({required PhotosDbRepository photos, required InferenceRepository inference})
      : _photos = photos,
        _inference = inference;

  @override
  Future<void> handle(ImageProcessingContext ctx) async {
    final phash = await _inference.computePhash(
      pixels: ctx.pixels,
      width: ctx.width,
      height: ctx.height,
    );

    if (_photos.hasDuplicate(phash)) {
      _photos.markDuplicate(ctx.assetId, phash);
      return; // short-circuit — skip inference
    }

    ctx.phash = phash;
    await forward(ctx);
  }
}
