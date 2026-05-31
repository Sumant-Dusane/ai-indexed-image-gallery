import 'dart:typed_data';

import 'package:ai_gallery/core/models/cluster.dart';
import 'package:ai_gallery/core/providers/face_cluster_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(faceClusterProvider.notifier).loadClusters(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = ref.watch(faceClusterProvider);
    final clusters = [...clusterState.clusters]
      ..sort((a, b) {
        final unnamedOrder = (a.name == null ? 0 : 1).compareTo(
          b.name == null ? 0 : 1,
        );
        return unnamedOrder != 0
            ? unnamedOrder
            : b.memberCount.compareTo(a.memberCount);
      });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('People')),
          if (clusterState.isClustering)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (clusters.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No people found')),
            )
          else
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: clusters.length,
              itemBuilder: (context, index) =>
                  _ClusterCard(cluster: clusters[index]),
            ),
        ],
      ),
    );
  }
}

class _ClusterCard extends ConsumerWidget {
  const _ClusterCard({required this.cluster});

  final FaceCluster cluster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoId = ref.watch(faceClusterCoverPhotoIdProvider(cluster.id));
    final isUnnamed = cluster.name == null;

    return GestureDetector(
      onTap: () => context.push('/people/${cluster.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          photoId.when(
            data: (id) => id == null
                ? const _ThumbnailPlaceholder()
                : _AssetThumbnail(photoId: id),
            loading: () => const _ThumbnailPlaceholder(),
            error: (_, __) => const _ThumbnailPlaceholder(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 7),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Text(
                cluster.name ?? 'Who is this?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnnamed ? Colors.amber : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({required this.photoId});

  final String photoId;

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _thumbnail = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() async {
    final asset = await AssetEntity.fromId(widget.photoId);
    return asset?.thumbnailDataWithSize(const ThumbnailSize(200, 200));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnail,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return data == null
            ? const _ThumbnailPlaceholder()
            : Image.memory(data, fit: BoxFit.cover);
      },
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainer);
  }
}
