import 'package:ai_gallery/core/inference/inference_types.dart';

class DebugProbeResult {
  final int width;
  final int height;
  final int fileSizeBytes;
  final String phash;
  final List<double> clipEmbedding;
  final List<Detection> nonPersonDetections;
  final List<BBox> personBoxes;
  final List<FaceDebugResult> faces;

  const DebugProbeResult({
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    required this.phash,
    required this.clipEmbedding,
    required this.nonPersonDetections,
    required this.personBoxes,
    required this.faces,
  });
}

class FaceDebugResult {
  final BBox bbox;
  final List<double> faceEmbedding;
  final EmotionResult emotion;

  const FaceDebugResult({
    required this.bbox,
    required this.faceEmbedding,
    required this.emotion,
  });
}
