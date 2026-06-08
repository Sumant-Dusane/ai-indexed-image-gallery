import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/models/detection.dart';
import 'package:ai_gallery/core/providers/indexing_service_provider.dart';
import 'package:ai_gallery/core/providers/photo_detail_provider.dart';
import 'package:ai_gallery/services/indexing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoDetailScreen extends ConsumerStatefulWidget {
  const PhotoDetailScreen({
    super.key,
    required this.photoId,
    this.initialAsset,
    this.initialThumbnail,
  });

  final String photoId;
  final AssetEntity? initialAsset;
  final Uint8List? initialThumbnail;

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late Future<AssetEntity?> _asset;
  IndexingService? _indexingService;

  @override
  void initState() {
    super.initState();
    _asset = widget.initialAsset == null
        ? AssetEntity.fromId(widget.photoId)
        : Future.value(widget.initialAsset);
    unawaited(_pauseForegroundIndexing());
  }

  Future<void> _pauseForegroundIndexing() async {
    final service = await ref.read(indexingServiceProvider.future);
    if (!mounted) return;
    service.pauseForInteractiveUse();
    _indexingService = service;
  }

  @override
  void dispose() {
    _indexingService?.resumeAfterInteractiveUse();
    super.dispose();
  }

  Future<void> _toggleFavorite(AssetEntity asset) async {
    try {
      final editor = PhotoManager.editor;
      final updated = await (Platform.isIOS
          ? editor.darwin.favoriteAsset(
              entity: asset,
              favorite: !asset.isFavorite,
            )
          : editor.android.favoriteAsset(
              entity: asset,
              favorite: !asset.isFavorite,
            ));
      if (mounted) {
        setState(() => _asset = Future.value(updated));
      }
    } catch (error, stackTrace) {
      AppLogger.gallery(
        'failed to update favorite for photo ${widget.photoId}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<AssetEntity?>(
        future: _asset,
        builder: (context, snapshot) {
          final asset = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (asset == null) {
            return const Center(
              child: Text(
                'Photo unavailable',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return _PhotoDetailContent(
            asset: asset,
            initialThumbnail: widget.initialThumbnail,
            onToggleFavorite: () => _toggleFavorite(asset),
          );
        },
      ),
    );
  }
}

class _PhotoDetailContent extends ConsumerStatefulWidget {
  const _PhotoDetailContent({
    required this.asset,
    required this.initialThumbnail,
    required this.onToggleFavorite,
  });

  final AssetEntity asset;
  final Uint8List? initialThumbnail;
  final VoidCallback onToggleFavorite;

  @override
  ConsumerState<_PhotoDetailContent> createState() =>
      _PhotoDetailContentState();
}

class _PhotoDetailContentState extends ConsumerState<_PhotoDetailContent> {
  bool _loadMetadata = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _loadMetadata = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final metadata = _loadMetadata
        ? ref.watch(photoDetailMetadataProvider(asset.id))
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsedSize = (80 / constraints.maxHeight).clamp(0.1, 0.2);
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: asset.type == AssetType.video
                  ? _VideoPreview(asset: asset)
                  : Hero(
                      tag: 'photo_${asset.id}',
                      child: _PhotoViewer(
                        asset: asset,
                        initialThumbnail: widget.initialThumbnail,
                      ),
                    ),
            ),
            _TopBar(
              isFavorite: asset.isFavorite,
              onToggleFavorite: widget.onToggleFavorite,
            ),
            DraggableScrollableSheet(
              initialChildSize: collapsedSize,
              minChildSize: collapsedSize,
              maxChildSize: 0.62,
              snap: true,
              builder: (context, scrollController) {
                return _InfoSheet(
                  asset: asset,
                  metadata: metadata,
                  scrollController: scrollController,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.asset, required this.initialThumbnail});

  final AssetEntity asset;
  final Uint8List? initialThumbnail;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  Uint8List? _displayThumbnail;
  Future<File?>? _file;
  PMCancelToken? _fileCancelToken;
  bool _displayThumbnailScheduled = false;
  int? _decodeWidth;
  int? _decodeHeight;

  @override
  void initState() {
    super.initState();
    _displayThumbnail = widget.initialThumbnail;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleDisplayThumbnailLoad();
  }

  void _scheduleDisplayThumbnailLoad() {
    if (_displayThumbnailScheduled) return;
    _displayThumbnailScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadDisplayThumbnail());
    });
  }

  @override
  void didUpdateWidget(covariant _PhotoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      unawaited(_fileCancelToken?.cancelRequest());
      _fileCancelToken = null;
      _file = null;
      _displayThumbnail = widget.initialThumbnail;
      _displayThumbnailScheduled = false;
      _scheduleDisplayThumbnailLoad();
    }
  }

  @override
  void dispose() {
    unawaited(_fileCancelToken?.cancelRequest());
    super.dispose();
  }

  Future<void> _loadDisplayThumbnail() async {
    final asset = widget.asset;
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final frameSize = _fittedFrameSize(size);
    final width = (frameSize.width * pixelRatio).round();
    final height = (frameSize.height * pixelRatio).round();
    final thumbnail = await asset.thumbnailDataWithSize(
      ThumbnailSize(width, height),
    );
    if (!mounted || thumbnail == null || asset.id != widget.asset.id) return;
    setState(() => _displayThumbnail = thumbnail);
  }

  void _loadFullResolution(ScaleUpdateDetails details) {
    if (details.scale <= 1.01 || _file != null) return;
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final maxWidth = (size.width * pixelRatio * 3).round();
    final maxHeight = (size.height * pixelRatio * 3).round();
    _decodeWidth = widget.asset.width > 0
        ? widget.asset.width.clamp(1, maxWidth)
        : maxWidth;
    _decodeHeight = widget.asset.height > 0
        ? widget.asset.height.clamp(1, maxHeight)
        : maxHeight;
    _fileCancelToken = PMCancelToken();
    setState(() {
      _file = widget.asset.loadFile(
        isOrigin: false,
        cancelToken: _fileCancelToken,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameSize = _fittedFrameSize(constraints.biggest);
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          clipBehavior: Clip.none,
          onInteractionUpdate: _loadFullResolution,
          child: SizedBox(
            width: frameSize.width,
            height: frameSize.height,
            child: _buildImage(),
          ),
        );
      },
    );
  }

  Size _fittedFrameSize(Size availableSize) {
    if (availableSize.isEmpty ||
        widget.asset.width <= 0 ||
        widget.asset.height <= 0) {
      return availableSize;
    }
    return applyBoxFit(
      BoxFit.contain,
      Size(widget.asset.width.toDouble(), widget.asset.height.toDouble()),
      availableSize,
    ).destination;
  }

  Widget _buildImage() {
    final preview = switch (_displayThumbnail) {
      final thumbnail? => Image.memory(
        thumbnail,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
      null => const _LoadingIndicator(),
    };
    final file = _file;
    if (file == null) return preview;
    return FutureBuilder<File?>(
      future: file,
      builder: (context, snapshot) {
        final loadedFile = snapshot.data;
        if (loadedFile == null) return preview;
        return Image.file(
          loadedFile,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          cacheWidth: _decodeWidth,
          cacheHeight: _decodeHeight,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(1080, 1080)),
          builder: (context, snapshot) {
            final thumbnail = snapshot.data;
            if (thumbnail == null) {
              return const _LoadingIndicator();
            }
            return Image.memory(thumbnail, fit: BoxFit.contain);
          },
        ),
        const Icon(Icons.play_circle_fill, color: Colors.white70, size: 72),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 28,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isFavorite, required this.onToggleFavorite});

  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: context.pop,
              ),
              const Spacer(),
              const IconButton(
                tooltip: 'Share unavailable',
                color: Colors.white54,
                icon: Icon(Icons.ios_share),
                onPressed: null,
              ),
              IconButton(
                tooltip: isFavorite ? 'Remove from favorites' : 'Favorite',
                color: Colors.white,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: onToggleFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.asset,
    required this.metadata,
    required this.scrollController,
  });

  final AssetEntity asset;
  final AsyncValue<PhotoDetailMetadata>? metadata;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatDate(asset.createDateTime),
            style: theme.textTheme.titleSmall,
          ),
          if (_location(asset) case final location?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                location,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 14),
          metadata?.when(
                data: (detail) => detail.isIndexed
                    ? _MetadataChips(metadata: detail)
                    : const Text('Still analysing this photo…'),
                loading: () => const Text('Loading photo details…'),
                error: (_, __) => const Text('Photo details unavailable'),
              ) ??
              const Text('Loading photo details…'),
        ],
      ),
    );
  }
}

class _MetadataChips extends StatelessWidget {
  const _MetadataChips({required this.metadata});

  final PhotoDetailMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final detection in metadata.detections)
        _DetailChip(label: _detectionLabel(detection)),
      if (metadata.emotion case final emotion?
          when (metadata.emotionConfidence ?? 0) > 0.6)
        _DetailChip(label: '${_emotionEmoji(emotion)} ${_titleCase(emotion)}'),
      if (metadata.clusterId case final clusterId?
          when metadata.clusterName != null)
        _DetailChip(
          label: '👤 ${metadata.clusterName!}',
          onPressed: () => context.push('/people/$clusterId'),
        ),
    ];

    if (chips.isEmpty) {
      return const Text('No detected details');
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelWidget = Text(label, style: const TextStyle(fontSize: 12));
    final backgroundColor = theme.colorScheme.surfaceContainerHighest;
    if (onPressed == null) {
      return Chip(
        label: labelWidget,
        backgroundColor: backgroundColor,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );
    }
    return ActionChip(
      label: labelWidget,
      backgroundColor: backgroundColor,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
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
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${date.day} ${months[date.month - 1]} ${date.year}, '
      '$hour:$minute $period';
}

String? _location(AssetEntity asset) {
  final latitude = asset.latitude;
  final longitude = asset.longitude;
  if (latitude == null || longitude == null) return null;
  return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}

String _detectionLabel(Detection detection) => _titleCase(detection.label);

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _emotionEmoji(String emotion) => switch (emotion) {
  'happy' => '😊',
  'sad' => '😢',
  'angry' => '😠',
  'surprised' => '😮',
  'fear' => '😨',
  'disgust' => '🤢',
  _ => '😐',
};
