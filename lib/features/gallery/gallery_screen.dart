import 'dart:typed_data';

import 'package:ai_gallery/core/providers/gallery_provider.dart';
import 'package:ai_gallery/core/providers/storage_error_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryProvider);
    final storageError = ref.watch(storageErrorNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: Column(
        children: [
          if (storageError != null) _StorageErrorStrip(message: storageError),
          Expanded(
            child: galleryAsync.when(
              data: (grouped) => grouped.isEmpty
                  ? const Center(child: Text('No photos'))
                  : _GalleryGrid(grouped: grouped),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading gallery: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageErrorStrip extends StatelessWidget {
  const _StorageErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({required this.grouped});

  final Map<String, List<AssetEntity>> grouped;

  @override
  Widget build(BuildContext context) {
    final months = grouped.keys.toList();
    return CustomScrollView(
      slivers: [
        for (final month in months) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text(month, style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: grouped[month]!.length,
            itemBuilder: (context, index) {
              final asset = grouped[month]![index];
              return _ThumbnailCell(asset: asset);
            },
          ),
        ],
      ],
    );
  }
}

class _ThumbnailCell extends StatelessWidget {
  const _ThumbnailCell({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return Image.memory(data, fit: BoxFit.cover);
        }
        return const ColoredBox(color: Color(0xFF1A1A1A));
      },
    );
  }
}
