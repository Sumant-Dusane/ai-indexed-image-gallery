import 'dart:typed_data';

import 'package:ai_gallery/core/providers/gallery_provider.dart';
import 'package:ai_gallery/core/providers/blocking_error_provider.dart';
import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryProvider);
    final storageError = ref.watch(blockingErrorNotifierProvider);
    final indexingState = ref.watch(indexingNotifierProvider);

    return Scaffold(
      body: galleryAsync.when(
        data: (grouped) => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Library'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _SearchBar(onTap: () => context.go('/search')),
                ),
              ),
            ),
            if (indexingState.isRunning)
              SliverToBoxAdapter(
                child: _IndexingBanner(
                  indexed: indexingState.indexed,
                  total: indexingState.total,
                ),
              ),
            if (storageError != null)
              SliverToBoxAdapter(
                child: _StorageErrorStrip(message: storageError),
              ),
            if (grouped.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No photos')),
              )
            else
              ..._buildMonthSlivers(grouped),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading gallery: $e')),
      ),
    );
  }

  List<Widget> _buildMonthSlivers(Map<String, List<AssetEntity>> grouped) {
    final months = grouped.entries.toList(growable: false);
    return [
      for (final month in months) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              _formatMonthLabel(month.key),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: month.value.length,
          itemBuilder: (context, index) {
            final asset = month.value[index];
            return _ThumbnailCell(asset: asset);
          },
        ),
      ],
    ];
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Search',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexingBanner extends StatelessWidget {
  const _IndexingBanner({required this.indexed, required this.total});

  final int indexed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Analysing your library… $indexed of $total',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
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

class _ThumbnailCell extends StatelessWidget {
  const _ThumbnailCell({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/photo/${asset.id}'),
      child: Hero(
        tag: 'photo_${asset.id}',
        child: FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data != null) {
              return Image.memory(data, fit: BoxFit.cover);
            }
            return const ColoredBox(color: Color(0xFFE5E5E5));
          },
        ),
      ),
    );
  }
}

String _formatMonthLabel(String key) {
  final parts = key.split('-');
  final year = int.tryParse(parts.isNotEmpty ? parts.first : '');
  final month = int.tryParse(parts.length > 1 ? parts[1] : '');
  if (year == null || month == null || month < 1 || month > 12) return key;

  const monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${monthNames[month - 1]} $year';
}
