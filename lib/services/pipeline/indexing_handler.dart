import 'image_processing_context.dart';

abstract class IndexingHandler {
  IndexingHandler? _next;

  IndexingHandler setNext(IndexingHandler next) => _next = next;

  Future<void> handle(ImageProcessingContext context);

  Future<void> forward(ImageProcessingContext context) =>
      _next?.handle(context) ?? Future.value();
}
