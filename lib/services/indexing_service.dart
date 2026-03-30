import 'dart:collection';

import 'package:ai_gallery/core/models/indexing_state.dart';
import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';
import 'package:ai_gallery/services/image_pipeline.dart';
import 'package:photo_manager/photo_manager.dart';

class IndexingService {
  final PhotosDbRepository _photosDb;
  final ImageIndexingPipeline _pipeline;
  final PhotoRepository _photos;
  final void Function(IndexingState) _onStateUpdate;

  bool _isRunning = false;
  bool _paused = false;
  final ListQueue<String> _queue = ListQueue();
  IndexingState _state = const IndexingState();

  IndexingService({
    required PhotosDbRepository photosDb,
    required ImageIndexingPipeline pipeline,
    required PhotoRepository photos,
    required void Function(IndexingState) onStateUpdate,
  })  : _photosDb = photosDb,
        _pipeline = pipeline,
        _photos = photos,
        _onStateUpdate = onStateUpdate;

  Future<void> syncPhotoLibrary() async {
    final assets = await _photos.listAllAssets();
    for (final asset in assets) {
      final localPath = await _photos.getLocalPath(asset);
      _photosDb.upsertAsset(asset, localPath);
    }
    _refreshCounts();
  }

  Future<void> startIndexing() async {
    if (_isRunning) return;
    _isRunning = true;
    _paused = false;

    _queue
      ..clear()
      ..addAll(_photosDb.queryUnindexedQueue());

    _refreshCounts();
    _updateState(_state.copyWith(isRunning: true));
    await _drainQueue();
  }

  void pause() {
    _paused = true;
    _isRunning = false;
    _updateState(_state.copyWith(isRunning: false, currentPhotoId: null));
  }

  Future<void> onAssetsAdded(List<String> assetIds) async {
    for (final id in assetIds) {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) continue;
      final localPath = await _photos.getLocalPath(asset);
      _photosDb.upsertAsset(asset, localPath);
      _queue.addFirst(id);
    }
    _refreshCounts();
  }

  Future<void> onAssetsDeleted(List<String> assetIds) async {
    _photosDb.deleteAssets(assetIds);
    _queue.removeWhere(assetIds.contains);
    _refreshCounts();
  }

  Future<void> _drainQueue() async {
    while (_queue.isNotEmpty && !_paused) {
      final batch = <String>[];
      for (var i = 0; i < 4 && _queue.isNotEmpty; i++) {
        batch.add(_queue.removeFirst());
      }
      await Future.wait(batch.map(_indexAsset));
    }
    if (!_paused) {
      _isRunning = false;
      _updateState(_state.copyWith(isRunning: false, currentPhotoId: null));
    }
  }

  Future<void> _indexAsset(String assetId) async {
    _updateState(_state.copyWith(currentPhotoId: assetId));
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) { _warn('asset $assetId not found'); return; }

      final pixels = await _photos.getFullResBytes(asset);
      if (pixels == null) { _warn('no pixels for $assetId'); return; }

      await _pipeline.run(
        assetId: assetId,
        pixels: pixels,
        width: asset.width,
        height: asset.height,
      );
      _incrementIndexed();
    } catch (e, st) {
      _warn('pipeline failed for $assetId: $e\n$st');
    }
  }

  void _refreshCounts() {
    final (:total, :indexed) = _photosDb.countPhotos();
    _updateState(_state.copyWith(total: total, indexed: indexed));
  }

  void _incrementIndexed() =>
      _updateState(_state.copyWith(indexed: _state.indexed + 1));

  void _updateState(IndexingState s) {
    _state = s;
    _onStateUpdate(s);
  }

  static void _warn(String msg) => print('[IndexingService] WARNING: $msg'); // ignore: avoid_print
}
