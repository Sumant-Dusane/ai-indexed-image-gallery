import 'package:ai_gallery/core/models/cluster.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'face_cluster_state.freezed.dart';

@freezed
class FaceClusterState with _$FaceClusterState {
  const factory FaceClusterState({
    @Default([]) List<FaceCluster> clusters,
    @Default(false) bool isClustering,
  }) = _FaceClusterState;
}
