import 'package:ai_gallery/core/models/indexing_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'indexing_notifier_provider.g.dart';

/// Holds live indexing progress for the UI.
///
/// Updated exclusively by [IndexingService] via the [onStateUpdate] callback
/// injected through [indexingServiceProvider]. UI widgets watch this provider
/// and never mutate it directly.
@riverpod
class IndexingNotifier extends _$IndexingNotifier {
  @override
  IndexingState build() => const IndexingState();

  void updateState(IndexingState newState) => state = newState;
}
