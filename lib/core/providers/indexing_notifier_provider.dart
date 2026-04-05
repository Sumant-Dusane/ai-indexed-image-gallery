import 'package:ai_gallery/core/models/indexing_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'indexing_notifier_provider.g.dart';

@riverpod
class IndexingNotifier extends _$IndexingNotifier {
  @override
  IndexingState build() => const IndexingState();

  void updateState(IndexingState newState) => state = newState;
}
