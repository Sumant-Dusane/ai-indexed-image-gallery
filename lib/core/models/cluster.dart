import 'package:freezed_annotation/freezed_annotation.dart';

part 'cluster.freezed.dart';
part 'cluster.g.dart';

@freezed
class FaceCluster with _$FaceCluster {
  const factory FaceCluster({
    required int id,
    String? name,
    int? coverFaceId,
    @Default(0) int memberCount,
  }) = _FaceCluster;

  factory FaceCluster.fromJson(Map<String, dynamic> json) =>
      _$FaceClusterFromJson(json);
}
