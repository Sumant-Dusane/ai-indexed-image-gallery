/// Bounding box with normalised 0..1 coordinates.
class BBox {
  final double x;
  final double y;
  final double w;
  final double h;

  const BBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BBox &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          w == other.w &&
          h == other.h;
}

/// YOLO object detection result.
class Detection {
  final String label;
  final double confidence;
  final BBox bbox;

  const Detection({
    required this.label,
    required this.confidence,
    required this.bbox,
  });

  @override
  int get hashCode => Object.hash(label, confidence, bbox);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Detection &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          confidence == other.confidence &&
          bbox == other.bbox;
}

/// Emotion classification result from the emotion model.
class EmotionResult {
  final String label;
  final double confidence;

  const EmotionResult({required this.label, required this.confidence});

  @override
  int get hashCode => Object.hash(label, confidence);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmotionResult &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          confidence == other.confidence;
}
