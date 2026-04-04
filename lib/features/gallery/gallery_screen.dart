import 'dart:typed_data';

import 'package:ai_gallery/core/models/photo_asset.dart';
import 'package:ai_gallery/core/providers/gallery_provider.dart';
import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    // Sync + index on every launch to catch photos added while the app was closed.
    // On first launch this is a no-op until onboarding triggers it (Phase 6).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(indexingNotifierProvider.notifier).syncAndStart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final galleryAsync = ref.watch(galleryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: galleryAsync.when(
        data: (grouped) => grouped.isEmpty
            ? const Center(child: Text('No photos'))
            : _GalleryGrid(grouped: grouped),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading gallery: $e')),
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({required this.grouped});

  final Map<String, List<PhotoAsset>> grouped;

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
              final photo = grouped[month]![index];
              return _ThumbnailCell(photo: photo);
            },
          ),
        ],
      ],
    );
  }
}

class _ThumbnailCell extends StatelessWidget {
  const _ThumbnailCell({required this.photo});

  final PhotoAsset photo;

  @override
  Widget build(BuildContext context) {
    final entity = AssetEntity(
      id: photo.id,
      typeInt: photo.mediaType == 'video' ? 2 : 1,
      width: photo.width ?? 0,
      height: photo.height ?? 0,
    );
    return FutureBuilder<Uint8List?>(
      future: entity.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
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
