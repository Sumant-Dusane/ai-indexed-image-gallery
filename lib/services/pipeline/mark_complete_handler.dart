import 'package:ai_gallery/core/repositories/photos_db_repository.dart';

import 'image_processing_context.dart';
import 'indexing_handler.dart';

class MarkCompleteHandler extends IndexingHandler {
  final PhotosDbRepository _photos;

  MarkCompleteHandler({required PhotosDbRepository photos}) : _photos = photos;

  @override
  Future<void> handle(ImageProcessingContext ctx) async {
    _photos.markComplete(ctx.assetId, ctx.phash!);
  }
}
