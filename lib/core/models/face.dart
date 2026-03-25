import 'package:freezed_annotation/freezed_annotation.dart';

part 'face.freezed.dart';
part 'face.g.dart';

@freezed
class Face with _$Face {
  const factory Face({
    int? id,
    required String photoId,
    int? clusterId,
    String? emotion,
    double? emotionConf,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
  }) = _Face;

  factory Face.fromJson(Map<String, dynamic> json) => _$FaceFromJson(json);
}
