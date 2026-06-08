import 'dart:typed_data';

import 'package:ai_gallery/core/providers/face_cluster_provider.dart';
import 'package:ai_gallery/features/people/name_face_sheet.dart';
import 'package:ai_gallery/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class ClusterDetailScreen extends ConsumerStatefulWidget {
  const ClusterDetailScreen({super.key, required this.clusterId});

  final int clusterId;

  @override
  ConsumerState<ClusterDetailScreen> createState() =>
      _ClusterDetailScreenState();
}

class _ClusterDetailScreenState extends ConsumerState<ClusterDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(faceClusterProvider.notifier).loadClusters(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cluster = ref
        .watch(faceClusterProvider)
        .clusters
        .where((cluster) => cluster.id == widget.clusterId)
        .firstOrNull;
    final photoIds = ref.watch(faceClusterPhotoIdsProvider(widget.clusterId));
    final title = cluster?.name ?? 'Unknown Person';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(title),
            actions: [
              IconButton(
                tooltip: 'Edit name',
                icon: const Icon(Icons.edit_outlined),
                onPressed: cluster == null
                    ? null
                    : () async {
                        final result = await showNameFaceSheet(
                          context,
                          cluster: cluster,
                        );
                        if (result == NameFaceSheetResult.deleted &&
                            context.mounted) {
                          context.pop();
                        }
                      },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                '${cluster?.memberCount ?? 0} Photos',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          photoIds.when(
            data: (ids) => ids.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No photos')),
                  )
                : SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                    itemCount: ids.length,
                    itemBuilder: (context, index) =>
                        _PhotoCell(photoId: ids[index]),
                  ),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Error loading photos: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCell extends StatefulWidget {
  const _PhotoCell({required this.photoId});

  final String photoId;

  @override
  State<_PhotoCell> createState() => _PhotoCellState();
}

class _PhotoCellState extends State<_PhotoCell> {
  late Future<Uint8List?> _thumbnail;
  AssetEntity? _asset;
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _PhotoCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _asset = null;
      _thumbnailData = null;
      _thumbnail = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() async {
    final photoId = widget.photoId;
    final asset = await AssetEntity.fromId(photoId);
    if (photoId != widget.photoId) return null;
    _asset = asset;
    final thumbnail = await asset?.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    if (photoId == widget.photoId) {
      _thumbnailData = thumbnail;
    }
    return thumbnail;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(
        photoDetailRouteName,
        pathParameters: {'photoId': widget.photoId},
        extra: switch (_asset) {
          final asset? => (asset: asset, thumbnail: _thumbnailData),
          null => null,
        },
      ),
      child: Hero(
        tag: 'photo_${widget.photoId}',
        child: FutureBuilder<Uint8List?>(
          future: _thumbnail,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return data == null
                ? const ColoredBox(color: Color(0xFFE5E5E5))
                : Image.memory(data, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}
