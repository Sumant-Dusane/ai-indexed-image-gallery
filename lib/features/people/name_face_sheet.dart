import 'dart:typed_data';

import 'package:ai_gallery/core/models/cluster.dart';
import 'package:ai_gallery/core/providers/face_cluster_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

enum NameFaceSheetResult { saved, deleted }

Future<NameFaceSheetResult?> showNameFaceSheet(
  BuildContext context, {
  required FaceCluster cluster,
}) {
  return showModalBottomSheet<NameFaceSheetResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => NameFaceSheet(cluster: cluster),
  );
}

class NameFaceSheet extends ConsumerStatefulWidget {
  const NameFaceSheet({super.key, required this.cluster});

  final FaceCluster cluster;

  @override
  ConsumerState<NameFaceSheet> createState() => _NameFaceSheetState();
}

class _NameFaceSheetState extends ConsumerState<NameFaceSheet> {
  late final TextEditingController _controller;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.cluster.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(faceClusterProvider.notifier)
          .nameCluster(widget.cluster.id, _controller.text);
      if (mounted) Navigator.pop(context, NameFaceSheetResult.saved);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete cluster?'),
        content: const Text(
          'This removes the group from People. Its photos stay in your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(faceClusterProvider.notifier)
          .deleteCluster(widget.cluster.id);
      if (mounted) Navigator.pop(context, NameFaceSheetResult.deleted);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not update cluster: $error')));
  }

  @override
  Widget build(BuildContext context) {
    final photoId = ref.watch(
      faceClusterCoverPhotoIdProvider(widget.cluster.id),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          photoId.when(
            data: (id) => _CoverFace(photoId: id),
            loading: () => const _CoverFace(photoId: null),
            error: (_, __) => const _CoverFace(photoId: null),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter name'),
            onSubmitted: (_) => _isSaving ? null : _save(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Save'),
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _delete,
            child: Text(
              'Delete cluster',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverFace extends StatefulWidget {
  const _CoverFace({required this.photoId});

  final String? photoId;

  @override
  State<_CoverFace> createState() => _CoverFaceState();
}

class _CoverFaceState extends State<_CoverFace> {
  Future<Uint8List?>? _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _CoverFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _thumbnail = _loadThumbnail();
    }
  }

  Future<Uint8List?>? _loadThumbnail() async {
    final photoId = widget.photoId;
    if (photoId == null) return null;
    final asset = await AssetEntity.fromId(photoId);
    return asset?.thumbnailDataWithSize(const ThumbnailSize(160, 160));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnail,
      builder: (context, snapshot) => CircleAvatar(
        radius: 40,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        backgroundImage: snapshot.data == null
            ? null
            : MemoryImage(snapshot.data!),
        child: snapshot.data == null ? const Icon(Icons.person_outline) : null,
      ),
    );
  }
}
