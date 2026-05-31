import 'dart:math' as math;

import 'package:ai_gallery/core/constants/yolo_detection_labels.dart';
import 'package:ai_gallery/core/inference/image_tensor_utils.dart';
import 'package:ai_gallery/core/inference/inference_types.dart';

const _anchors = 8400;
const _rows = 84;
const _confidenceThreshold = 0.35;
const _iouThreshold = 0.45;

List<Detection> parseYoloOutput(
  List<double> raw,
  LetterboxResult letterbox,
  int width,
  int height,
) {
  if (raw.length != _rows * _anchors) {
    throw StateError(
      'Unexpected YOLO output size: ${raw.length} '
      '(expected ${_rows * _anchors})',
    );
  }

  final rawDetections = <_RawDetection>[];
  for (var i = 0; i < _anchors; i++) {
    final cx = raw[i];
    final cy = raw[_anchors + i];
    final w = raw[2 * _anchors + i];
    final h = raw[3 * _anchors + i];

    var classIdx = 0;
    var confidence = raw[4 * _anchors + i];
    for (var j = 1; j < 80; j++) {
      final score = raw[(4 + j) * _anchors + i];
      if (score > confidence) {
        classIdx = j;
        confidence = score;
      }
    }

    if (confidence < _confidenceThreshold) continue;
    final label = YoloDetectionLabels.retainedByClassIndex[classIdx];
    if (label == null) continue;

    rawDetections.add(
      _RawDetection(
        classIdx: classIdx,
        label: label,
        confidence: confidence,
        x1: cx - w / 2.0,
        y1: cy - h / 2.0,
        x2: cx + w / 2.0,
        y2: cy + h / 2.0,
      ),
    );
  }

  final kept = _applyNms(rawDetections);
  final origW = width.toDouble();
  final origH = height.toDouble();
  return kept
      .map((d) {
        final x1 = ((d.x1 - letterbox.padX) / letterbox.scale).clamp(
          0.0,
          origW,
        );
        final y1 = ((d.y1 - letterbox.padY) / letterbox.scale).clamp(
          0.0,
          origH,
        );
        final x2 = ((d.x2 - letterbox.padX) / letterbox.scale).clamp(
          0.0,
          origW,
        );
        final y2 = ((d.y2 - letterbox.padY) / letterbox.scale).clamp(
          0.0,
          origH,
        );
        return Detection(
          label: d.label,
          confidence: d.confidence,
          bbox: BBox(
            x: x1 / origW,
            y: y1 / origH,
            w: (x2 - x1) / origW,
            h: (y2 - y1) / origH,
          ),
        );
      })
      .toList(growable: false);
}

List<_RawDetection> _applyNms(List<_RawDetection> detections) {
  detections.sort((a, b) => b.confidence.compareTo(a.confidence));
  final suppressed = List<bool>.filled(detections.length, false);

  for (var i = 0; i < detections.length; i++) {
    if (suppressed[i]) continue;
    for (var j = i + 1; j < detections.length; j++) {
      if (suppressed[j]) continue;
      if (detections[i].classIdx == detections[j].classIdx &&
          _iou(detections[i], detections[j]) >= _iouThreshold) {
        suppressed[j] = true;
      }
    }
  }

  final kept = <_RawDetection>[];
  for (var i = 0; i < detections.length; i++) {
    if (!suppressed[i]) kept.add(detections[i]);
  }
  return kept;
}

double _iou(_RawDetection a, _RawDetection b) {
  final ix1 = math.max(a.x1, b.x1);
  final iy1 = math.max(a.y1, b.y1);
  final ix2 = math.min(a.x2, b.x2);
  final iy2 = math.min(a.y2, b.y2);
  final inter = math.max(0.0, ix2 - ix1) * math.max(0.0, iy2 - iy1);
  if (inter == 0.0) return 0.0;
  final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
  final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
  return inter / (areaA + areaB - inter);
}

class _RawDetection {
  final int classIdx;
  final String label;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const _RawDetection({
    required this.classIdx,
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
}
