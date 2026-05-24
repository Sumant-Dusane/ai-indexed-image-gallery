import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/platform/native_channel_client.dart';
import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:ai_gallery/core/providers/photo_permission_provider.dart';
import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_check_provider.g.dart';

const _bytesPerPhoto = 3 * 1024;

typedef StorageCheckResult = ({
  bool isSufficient,
  int requiredMb,
  int availableMb,
});

@riverpod
Future<StorageCheckResult> storageCheck(Ref ref) async {
  final permission = await ref.read(photoPermissionProvider.future);
  if (!permission.isGranted) {
    AppLogger.indexing('storage check skipped — permission not granted');
    return (isSufficient: false, requiredMb: 0, availableMb: 0);
  }

  final client = ref.read(nativeChannelClientProvider);
  final db = await ref.read(databaseProvider.future);

  final freeBytes = await client.getFreeBytes();
  final totalAssets = await PhotoRepository().getAssetCount();
  final alreadyIndexed = PhotosDbRepository(db).countIndexed();
  final unindexed = (totalAssets - alreadyIndexed).clamp(0, totalAssets);
  final requiredBytes = unindexed * _bytesPerPhoto;

  AppLogger.indexing(
    'storage check — free: ${freeBytes >> 20}MB, '
    'unindexed: $unindexed ($totalAssets total, $alreadyIndexed indexed), '
    'required: ${(requiredBytes / (1024 * 1024)).ceil()}MB',
  );

  return (
    isSufficient: freeBytes >= requiredBytes,
    requiredMb: (requiredBytes / (1024 * 1024)).ceil(),
    availableMb: (freeBytes / (1024 * 1024)).floor(),
  );
}
