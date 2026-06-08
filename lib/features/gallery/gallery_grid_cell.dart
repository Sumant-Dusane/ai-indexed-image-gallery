import 'dart:typed_data';

import 'package:ai_gallery/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryGridCell extends StatefulWidget {
  const GalleryGridCell({super.key, required this.asset});

  final AssetEntity asset;

  @override
  State<GalleryGridCell> createState() => _GalleryGridCellState();
}

class _GalleryGridCellState extends State<GalleryGridCell> {
  late Future<Uint8List?> _thumbnail;
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant GalleryGridCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnailData = null;
      _thumbnail = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() async {
    final asset = widget.asset;
    final thumbnail = await asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    if (asset.id == widget.asset.id) {
      _thumbnailData = thumbnail;
    }
    return thumbnail;
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;
    return GestureDetector(
      onTap: isVideo
          ? null
          : () => context.pushNamed(
              photoDetailRouteName,
              pathParameters: {'photoId': widget.asset.id},
              extra: (asset: widget.asset, thumbnail: _thumbnailData),
            ),
      child: Hero(
        tag: 'photo_${widget.asset.id}',
        child: FutureBuilder<Uint8List?>(
          future: _thumbnail,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final thumbnail = data == null
                ? const ColoredBox(color: Color(0xFFE5E5E5))
                : Image.memory(data, fit: BoxFit.cover);
            if (!isVideo) return thumbnail;
            return Stack(
              fit: StackFit.expand,
              children: [
                thumbnail,
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: _VideoDurationBadge(
                    duration: widget.asset.videoDuration,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VideoDurationBadge extends StatelessWidget {
  const _VideoDurationBadge({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          _formatVideoDuration(duration),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _formatVideoDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ Duration.secondsPerHour;
  final minutes =
      totalSeconds.remainder(Duration.secondsPerHour) ~/
      Duration.secondsPerMinute;
  final seconds = totalSeconds.remainder(Duration.secondsPerMinute);
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$minuteText:$secondText';
  return '${hours.toString().padLeft(2, '0')}:$minuteText:$secondText';
}
