import 'package:ai_gallery/core/errors/storage_full_exception.dart';
import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:ai_gallery/core/providers/photo_permission_provider.dart';
import 'package:ai_gallery/core/providers/storage_check_provider.dart';
import 'package:ai_gallery/core/providers/storage_error_provider.dart';
import 'package:ai_gallery/core/providers/indexing_service_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStartup extends ConsumerStatefulWidget {
  final Widget child;

  const AppStartup({required this.child, super.key});

  @override
  ConsumerState<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<AppStartup> {
  @override
  Widget build(BuildContext context) {
    ref.listen(photoPermissionProvider, (_, next) {
      if (next.hasValue && next.value!.isGranted) _run();
    });
    return widget.child;
  }

  Future<void> _run() async {
    ref.read(storageErrorNotifierProvider.notifier).clearError();

    final storage = await ref.read(storageCheckProvider.future);
    if (!storage.isSufficient) {
      final shortfall = storage.requiredMb - storage.availableMb;
      ref.read(storageErrorNotifierProvider.notifier).setError(
        'Not enough storage to analyse photos. Free up ${shortfall}MB to enable AI search.',
      );
      return;
    }

    await _syncAndStart();
  }

  Future<void> _syncAndStart() async {
    final service = await ref.read(indexingServiceProvider.future);
    try {
      await service.syncPhotoLibrary();
      if (ref.read(indexingNotifierProvider).total > 0) await service.startIndexing();
    } on StorageFullException {
      ref.read(storageErrorNotifierProvider.notifier).setError(
        'Device storage is full. Free up space and try again.',
      );
    }
  }
}
