import 'dart:typed_data';

import 'package:ai_gallery/core/inference/inference_types.dart';

/// Mutable data carrier passed through the [IndexingHandler] chain.
///
/// Handlers read the inputs and write their outputs into this object.
/// The immutable fields ([assetId], [pixels], [width], [height]) are set
/// once at chain entry and never modified.
class ImageProcessingContext {
  final String assetId;
  final Uint8List pixels;
  final int width;
  final int height;

  /// Computed by [DedupHandler]. A `null` value means a duplicate was found
  /// and the chain was short-circuited — subsequent handlers must not run.
  String? phash;

  /// Populated by [InferenceHandler] with detected person bounding boxes.
  /// Consumed by [FaceHandler].
  List<BBox> personBboxes = const [];

  ImageProcessingContext({
    required this.assetId,
    required this.pixels,
    required this.width,
    required this.height,
  });
}
