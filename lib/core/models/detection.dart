import 'package:freezed_annotation/freezed_annotation.dart';

part 'detection.freezed.dart';
part 'detection.g.dart';

@freezed
class Detection with _$Detection {
  const factory Detection({
    int? id,
    required String photoId,
    required String label,
    required double confidence,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
  }) = _Detection;

  factory Detection.fromJson(Map<String, dynamic> json) =>
      _$DetectionFromJson(json);
}
