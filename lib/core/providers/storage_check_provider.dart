import 'package:ai_gallery/core/platform/native_channel_client.dart';
import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_check_provider.g.dart';

typedef StorageCheckResult = ({
  bool isSufficient,
  int requiredMb,
  int availableMb,
});

@riverpod
Future<StorageCheckResult> storageCheck(Ref ref) async {
  final client = ref.read(nativeChannelClientProvider);
  final db = await ref.read(databaseProvider.future);

  final freeBytes = await client.getFreeBytes();
  final (:total, :indexed) = PhotosDbRepository(db).countPhotos();
  final unindexed = total - indexed;

  final requiredBytes = unindexed * 3 * 1024 + 90 * 1024 * 1024;

  return (
    isSufficient: freeBytes >= requiredBytes,
    requiredMb: (requiredBytes / (1024 * 1024)).ceil(),
    availableMb: (freeBytes / (1024 * 1024)).floor(),
  );
}
