import 'package:ai_gallery/core/inference/inference_types.dart';

/// Base for every probe pipeline step. [elapsed] is the wall-clock time
/// for that specific step (parallel steps measure independently).
abstract class DebugProbeStep {
  final Duration elapsed;
  const DebugProbeStep({required this.elapsed});
}

/// Image decoded from the photo library.
class ImageLoadStep extends DebugProbeStep {
  final int width;
  final int height;
  final int fileSizeBytes;

  const ImageLoadStep({
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    required super.elapsed,
  });
}

/// pHash computed.
class PHashStep extends DebugProbeStep {
  final String phash;

  const PHashStep({required this.phash, required super.elapsed});
}

/// MobileCLIP image embedding computed.
class ClipStep extends DebugProbeStep {
  final List<double> embedding;

  const ClipStep({required this.embedding, required super.elapsed});
}

/// YOLOv8 detection completed.
/// [personDetections] are fed to the face pipeline.
class YoloStep extends DebugProbeStep {
  final List<Detection> nonPersonDetections;
  final List<Detection> personDetections;

  const YoloStep({
    required this.nonPersonDetections,
    required this.personDetections,
    required super.elapsed,
  });
}

/// MobileFaceNet + EfficientNet-B0 completed for one person.
/// [elapsed] is the wall-clock time (max of the two parallel tasks).
class FaceStep extends DebugProbeStep {
  final int faceIndex;
  final BBox bbox;
  final List<double> faceEmbedding;
  final Duration faceNetElapsed;
  final Duration emotionElapsed;
  final EmotionResult emotion;

  const FaceStep({
    required this.faceIndex,
    required this.bbox,
    required this.faceEmbedding,
    required this.faceNetElapsed,
    required this.emotionElapsed,
    required this.emotion,
    required super.elapsed,
  });
}
