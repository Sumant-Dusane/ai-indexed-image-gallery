import 'dart:typed_data';

import 'package:ai_gallery/core/models/search_result.dart';
import 'package:ai_gallery/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class SearchResultsGrid extends StatelessWidget {
  const SearchResultsGrid({super.key, required this.results});

  final List<SearchResult> results;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _SearchThumbnailCell(photoId: result.photoId);
      },
    );
  }
}

class _SearchThumbnailCell extends StatefulWidget {
  const _SearchThumbnailCell({required this.photoId});

  final String photoId;

  @override
  State<_SearchThumbnailCell> createState() => _SearchThumbnailCellState();
}

class _SearchThumbnailCellState extends State<_SearchThumbnailCell> {
  late Future<Uint8List?> _thumbnail;
  AssetEntity? _asset;
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _SearchThumbnailCell oldWidget) {
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
