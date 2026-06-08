import 'package:ai_gallery/core/providers/blocking_error_provider.dart';
import 'package:ai_gallery/core/providers/gallery_provider.dart';
import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:ai_gallery/features/gallery/gallery_grid_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  static const _gridSpacing = 2.0;
  static const _columnCount = 3;
  static const _topBarHeight = 160.0;

  String? _visibleMonth;
  double _gridCellExtent = 0;

  @override
  Widget build(BuildContext context) {
    final galleryAsync = ref.watch(galleryProvider);
    final storageError = ref.watch(blockingErrorNotifierProvider);
    final indexingState = ref.watch(indexingNotifierProvider);

    return Scaffold(
      body: galleryAsync.when(
        data: (grouped) {
          final assets = [
            for (final monthAssets in grouped.values) ...monthAssets,
          ];
          _gridCellExtent =
              (MediaQuery.sizeOf(context).width -
                  (_columnCount - 1) * _gridSpacing) /
              _columnCount;
          final visibleMonth =
              _visibleMonth ??
              _monthLabelForOffset(
                scrollOffset: 0,
                viewportExtent: MediaQuery.sizeOf(context).height,
                assets: assets,
              );

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _updateVisibleMonth(
                notification.metrics.pixels,
                notification.metrics.viewportDimension,
                assets,
              );
              return false;
            },
            child: CustomScrollView(
              reverse: true,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (assets.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No photos')),
                  )
                else
                  SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _columnCount,
                          crossAxisSpacing: _gridSpacing,
                          mainAxisSpacing: _gridSpacing,
                        ),
                    itemCount: assets.length,
                    itemBuilder: (context, index) =>
                        GalleryGridCell(asset: assets[index]),
                  ),
                if (storageError != null)
                  SliverToBoxAdapter(
                    child: _StorageErrorStrip(message: storageError),
                  ),
                if (indexingState.isRunning)
                  SliverToBoxAdapter(
                    child: _IndexingBanner(
                      indexed: indexingState.indexed,
                      total: indexingState.total,
                      onTap: () => context.push('/indexing-progress'),
                    ),
                  ),
                _GallerySliverAppBar(
                  monthLabel: visibleMonth,
                  onSearch: () => context.go('/search'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading gallery: $e')),
      ),
    );
  }

  void _updateVisibleMonth(
    double scrollOffset,
    double viewportExtent,
    List<AssetEntity> assets,
  ) {
    if (_gridCellExtent <= 0 || assets.isEmpty) return;

    final month = _monthLabelForOffset(
      scrollOffset: scrollOffset,
      viewportExtent: viewportExtent,
      assets: assets,
    );
    if (month != _visibleMonth) {
      setState(() => _visibleMonth = month);
    }
  }

  String _monthLabelForOffset({
    required double scrollOffset,
    required double viewportExtent,
    required List<AssetEntity> assets,
  }) {
    if (assets.isEmpty) return '';

    final overlayOffset = (viewportExtent - _topBarHeight).clamp(
      0,
      double.infinity,
    );
    final row =
        ((scrollOffset + overlayOffset) / (_gridCellExtent + _gridSpacing))
            .floor();
    final index = (row * _columnCount).clamp(0, assets.length - 1);
    return _monthLabelForAssets(assets, index);
  }
}

class _GallerySliverAppBar extends StatelessWidget {
  const _GallerySliverAppBar({
    required this.monthLabel,
    required this.onSearch,
  });

  final String monthLabel;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 152,
      collapsedHeight: 136,
      toolbarHeight: 88,
      flexibleSpace: const _GalleryTopFade(),
      titleSpacing: 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _GallerySearchBar(onTap: onSearch),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                Text(
                  monthLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Search',
            color: Colors.white,
            onPressed: onSearch,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }
}

class _GallerySearchBar extends StatelessWidget {
  const _GallerySearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const SizedBox(
          height: 36,
          child: Row(
            children: [
              SizedBox(width: 12),
              Icon(Icons.search, size: 18, color: Colors.black54),
              SizedBox(width: 8),
              Text(
                'Search',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryTopFade extends StatelessWidget {
  const _GalleryTopFade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.72),
              Colors.black.withValues(alpha: 0.48),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexingBanner extends StatelessWidget {
  const _IndexingBanner({
    required this.indexed,
    required this.total,
    required this.onTap,
  });

  final int indexed;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
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
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
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

String _monthLabelForAssets(List<AssetEntity> assets, int index) {
  if (assets.isEmpty) return '';
  final date = assets[index].createDateTime;
  return _formatMonthLabel(
    '${date.year}-${date.month.toString().padLeft(2, '0')}',
  );
}
