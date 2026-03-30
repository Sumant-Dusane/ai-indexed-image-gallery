import 'package:freezed_annotation/freezed_annotation.dart';

part 'indexing_state.freezed.dart';

@freezed
class IndexingState with _$IndexingState {
  const factory IndexingState({
    @Default(0) int total,
    @Default(0) int indexed,
    @Default(false) bool isRunning,
    String? currentPhotoId,
  }) = _IndexingState;
}
