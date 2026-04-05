import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/errors/storage_full_exception.dart';
import 'package:ai_gallery/core/models/indexing_state.dart';
import 'package:ai_gallery/core/platform/native_channel_client.dart';
import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';
import 'package:ai_gallery/services/image_pipeline.dart';
import 'package:flutter/services.dart' show MethodCall;
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';

class IndexingService {
  final PhotosDbRepository _photosDb;
  final ImageIndexingPipeline _pipeline;
  final PhotoRepository _photos;
  final NativeChannelClient _native;
  final void Function(IndexingState) _onStateUpdate;

  bool _isRunning = false;
  bool _paused = false;
  final ListQueue<String> _queue = ListQueue();
  IndexingState _state = const IndexingState();
  Timer? _throttlePoller;

  static const _bgTaskId = 'com.aigallery.indexing';

  IndexingService({
    required PhotosDbRepository photosDb,
    required ImageIndexingPipeline pipeline,
    required PhotoRepository photos,
    required NativeChannelClient native,
    required void Function(IndexingState) onStateUpdate,
  }) : _photosDb = photosDb,
       _pipeline = pipeline,
       _photos = photos,
       _native = native,
       _onStateUpdate = onStateUpdate;

  /// Loads all known assets into the photos table (no inference).
  ///
  /// Uses INSERT OR IGNORE — safe to call on every launch.
  /// Throws [StorageFullException] if the device runs out of space mid-sync;
  /// callers are responsible for catching and surfacing this.
  Future<void> syncPhotoLibrary() async {
    AppLogger.indexing('syncPhotoLibrary started');
    final assets = await _photos.listAllAssets();
    AppLogger.indexing('fetched ${assets.length} assets from library');
    for (final asset in assets) {
      final localPath = await _photos.getLocalPath(asset);
      _photosDb.upsertAsset(asset, localPath);
    }
    _refreshCounts();
    AppLogger.indexing('syncPhotoLibrary done — ${_state.total} rows in DB');
  }

  /// Starts the indexing queue. No-op if already running.
  ///
  /// Throws [StorageFullException] if the device runs out of space during
  /// inference; callers are responsible for catching and surfacing this.
  Future<void> startIndexing() async {
    if (_isRunning) return;
    _isRunning = true;
    _paused = false;
    _throttlePoller?.cancel();
    _throttlePoller = null;

    _queue
      ..clear()
      ..addAll(_photosDb.queryUnindexedQueue());

    AppLogger.indexing('startIndexing — ${_queue.length} unindexed assets queued');
    _refreshCounts();
    _updateState(_state.copyWith(isRunning: true));
    await _registerBackgroundTask();
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

  /// Register the photo library change observer.
  /// Call after [syncPhotoLibrary] completes and permission is granted.
  void registerChangeObserver() {
    PhotoManager.addChangeCallback(_onPhotoLibraryChange);
    PhotoManager.startChangeNotify();
  }

  // photo_manager 3.x fires a bare MethodCall('change') with no added/removed
  // IDs in the payload. Re-sync the full library so new assets are inserted
  // (INSERT OR IGNORE) and can be queued for indexing on the next startIndexing.
  void _onPhotoLibraryChange(MethodCall call) {
    syncPhotoLibrary();
  }

  Future<void> _drainQueue() async {
    while (_queue.isNotEmpty && !_paused) {
      if (await _shouldPauseForThrottle()) {
        pause();
        _startThrottlePoller();
        return;
      }
      final batch = <String>[];
      for (var i = 0; i < 4 && _queue.isNotEmpty; i++) {
        batch.add(_queue.removeFirst());
      }
      await Future.wait(batch.map(_indexAsset));
    }
    if (!_paused) {
      _isRunning = false;
      _updateState(_state.copyWith(isRunning: false, currentPhotoId: null));
      AppLogger.indexing('queue drained — indexing complete');
    }
  }

  void _startThrottlePoller() {
    _throttlePoller = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_isRunning) {
        _throttlePoller?.cancel();
        return;
      }
      if (!await _shouldPauseForThrottle()) {
        _throttlePoller?.cancel();
        await startIndexing();
      }
    });
  }

  /// Returns true if indexing should pause due to low battery or high thermal load.
  Future<bool> _shouldPauseForThrottle() async {
    try {
      final batteryLevel = await _native.getBatteryLevel();
      if (batteryLevel < 0.20) return true;
      final thermal = await _native.getThermalState();
      if (thermal == 'serious' || thermal == 'critical') return true;
    } catch (e) {
      AppLogger.indexing('throttle check failed: $e');
    }
    return false;
  }

  Future<void> _registerBackgroundTask() async {
    await _native.scheduleIndexingTask(); // no-op on Android
    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        _bgTaskId,
        'IndexingWorker',
        frequency: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresCharging: true,
          requiresDeviceIdle: true,
        ),
      );
    }
  }

  Future<void> _indexAsset(String assetId) async {
    _updateState(_state.copyWith(currentPhotoId: assetId));
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) {
        AppLogger.indexing('asset not found — skipping', error: assetId);
        return;
      }

      final pixels = await _photos.getFullResBytes(asset);
      if (pixels == null) {
        AppLogger.indexing('no pixels available — skipping $assetId');
        return;
      }

      AppLogger.indexing('indexing $assetId (${asset.width}×${asset.height})');
      await _pipeline.run(
        assetId: assetId,
        pixels: pixels,
        width: asset.width,
        height: asset.height,
      );
      _incrementIndexed();
    } on StorageFullException {
      // Pause the queue; re-throw so the caller (IndexingNotifier) can surface the error.
      pause();
      rethrow;
    } catch (e, st) {
      AppLogger.indexing('pipeline failed for $assetId', error: e, stackTrace: st);
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
}
