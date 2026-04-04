import 'package:ai_gallery/core/models/indexing_state.dart';
import 'package:ai_gallery/core/providers/indexing_service_provider.dart';
import 'package:ai_gallery/core/providers/photo_permission_provider.dart';
import 'package:photo_manager/photo_manager.dart';
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

  /// Sync the photo library then start the indexing queue.
  /// Safe to call on every launch — sync is INSERT OR IGNORE,
  /// startIndexing has an isRunning guard.
  Future<void> syncAndStart() async {
    final permission = await ref.read(photoPermissionProvider.future);
    if (!permission.isGranted) return;
    final service = await ref.read(indexingServiceProvider.future);
    await service.syncPhotoLibrary();
    if (state.total > 0) await service.startIndexing();
  }
}
