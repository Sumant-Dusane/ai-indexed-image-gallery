import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui';

import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/errors/storage_full_exception.dart';
import 'package:ai_gallery/core/models/indexing_state.dart';
import 'package:ai_gallery/core/platform/native_channel_client.dart';
import 'package:ai_gallery/core/providers/indexing_service_provider.dart';
import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';
import 'package:ai_gallery/features/debug_probe/utils/constants.dart';
import 'package:ai_gallery/services/image_pipeline.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';

const _backgroundChannel = 'com.aigallery/background';
const _backgroundPauseMethod = 'pauseIndexing';
const _backgroundStartMethod = 'startIndexing';
const _backgroundCompleteMethod = 'completeIndexingTask';
const _androidBackgroundRunLimit = Duration(minutes: 9);

@pragma('vm:entry-point')
void indexingTaskDispatcher() {
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task, inputData) async {
    AppLogger.indexing('background indexing task triggered: $task');
    final container = ProviderContainer();
    try {
      final service = await container.read(indexingServiceProvider.future);
      await service.syncPhotoLibrary();
      final indexing = service._startIndexing(scheduleBackgroundTask: false);
      final timeout = Completer<void>();
      final timer = Timer(_androidBackgroundRunLimit, () {
        AppLogger.indexing('background indexing time limit reached');
        service.pause();
        timeout.complete();
      });
      await Future.any([indexing, timeout.future]);
      timer.cancel();
      await indexing;
      return true;
    } catch (e, st) {
      AppLogger.indexing(
        'background indexing task failed',
        error: e,
        stackTrace: st,
      );
      return false;
    } finally {
      container.dispose();
    }
  });
}

class IndexingService {
  final PhotosDbRepository _photosDb;
  final ImageIndexingPipeline _pipeline;
  final PhotoRepository _photos;
  final NativeChannelClient _native;
  final void Function(IndexingState) _onStateUpdate;
  final Future<void> Function()? _onIndexingComplete;
  final MethodChannel _bgChannel = const MethodChannel(_backgroundChannel);

  bool _isRunning = false;
  bool _paused = false;
  bool _observerRegistered = false;
  bool _workmanagerInitialized = false;
  int _interactivePauseCount = 0;
  bool _resumeAfterInteractivePause = false;
  final ListQueue<String> _queue = ListQueue();
  IndexingState _state = const IndexingState();
  Future<void>? _drainFuture;
  Timer? _throttlePoller;
  Set<String> _knownAssetIds = <String>{};

  static const _bgTaskId = 'com.aigallery.indexing';
  static const _androidTaskName = 'IndexingWorker';

  IndexingService({
    required PhotosDbRepository photosDb,
    required ImageIndexingPipeline pipeline,
    required PhotoRepository photos,
    required NativeChannelClient native,
    required void Function(IndexingState) onStateUpdate,
    Future<void> Function()? onIndexingComplete,
  }) : _photosDb = photosDb,
       _pipeline = pipeline,
       _photos = photos,
       _native = native,
       _onStateUpdate = onStateUpdate,
       _onIndexingComplete = onIndexingComplete;

  /// Loads all known assets into the photos table (no inference).
  ///
  /// Uses INSERT OR IGNORE — safe to call on every launch.
  /// Throws [StorageFullException] if the device runs out of space mid-sync;
  /// callers are responsible for catching and surfacing this.
  Future<void> syncPhotoLibrary() async {
    AppLogger.indexing('syncPhotoLibrary started');
    _registerBackgroundPauseHandler();
    await _registerChangeObserver();
    final assets = await _photos.listAllAssets();
    AppLogger.indexing('fetched ${assets.length} assets from library');
    _knownAssetIds = assets.map((asset) => asset.id).toSet();
    for (final asset in assets) {
      // localPath is left null here — no entity.file call, no iOS temp write.
      // The path is populated during _indexAsset when we already need the bytes.
      _photosDb.upsertAsset(asset, null);
    }
    _refreshCounts();
    AppLogger.indexing('syncPhotoLibrary done — ${_state.total} rows in DB');
  }

  /// Starts the indexing queue. No-op if already running.
  ///
  /// Throws [StorageFullException] if the device runs out of space during
  /// inference; callers are responsible for catching and surfacing this.
  Future<void> startIndexing() => _startIndexing(scheduleBackgroundTask: true);

  Future<void> _startIndexing({required bool scheduleBackgroundTask}) async {
    if (scheduleBackgroundTask && _interactivePauseCount > 0) {
      _resumeAfterInteractivePause = true;
      return;
    }
    if (_isRunning || _drainFuture != null) return;
    _isRunning = true;
    _paused = false;
    _throttlePoller?.cancel();
    _throttlePoller = null;

    final unindexedQueue = _photosDb.queryUnindexedQueue();
    final queuedAssets = kDebugLimitedIndexingEnabled
        ? unindexedQueue.take(kDebugIndexLimit)
        : unindexedQueue;
    _queue
      ..clear()
      ..addAll(queuedAssets);

    AppLogger.indexing(
      'startIndexing — ${_queue.length} unindexed assets queued'
      '${kDebugLimitedIndexingEnabled ? ' (debug limit $kDebugIndexLimit)' : ''}',
    );
    _refreshCounts();
    _updateState(_state.copyWith(isRunning: true));
    if (scheduleBackgroundTask) {
      await _registerBackgroundTask();
    }
    final drain = _drainQueue(runCompletionHook: _queue.isNotEmpty);
    _drainFuture = drain;
    try {
      await drain;
    } finally {
      if (identical(_drainFuture, drain)) {
        _drainFuture = null;
      }
      if (!_paused && !_isRunning && _queue.isNotEmpty) {
        unawaited(startIndexing());
      }
    }
  }

  void pause() => _pause(resumeAfterInteractiveUse: false);

  void pauseForInteractiveUse() {
    _interactivePauseCount++;
    if (_interactivePauseCount > 1 || !_isRunning) return;
    _pause(resumeAfterInteractiveUse: true);
  }

  void resumeAfterInteractiveUse() {
    if (_interactivePauseCount == 0) return;
    _interactivePauseCount--;
    if (_interactivePauseCount > 0 || !_resumeAfterInteractivePause) return;

    _resumeAfterInteractivePause = false;
    _paused = false;
    if (_drainFuture != null) {
      _isRunning = true;
      _updateState(_state.copyWith(isRunning: true));
    } else {
      unawaited(startIndexing());
    }
  }

  void _pause({required bool resumeAfterInteractiveUse}) {
    _paused = true;
    _isRunning = false;
    if (resumeAfterInteractiveUse) {
      _resumeAfterInteractivePause = true;
    } else {
      _resumeAfterInteractivePause = false;
    }
    _updateState(_state.copyWith(isRunning: false, currentPhotoId: null));
  }

  Future<void> onAssetsAdded(List<String> assetIds) async {
    for (final id in assetIds) {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) continue;
      // localPath populated during indexing — no temp write here.
      _photosDb.upsertAsset(asset, null);
      _knownAssetIds.add(id);
      if (!_queue.contains(id)) {
        _queue.addFirst(id);
      }
    }
    _refreshCounts();
    if (!_isRunning && !_paused && _queue.isNotEmpty) {
      unawaited(startIndexing());
    }
  }

  Future<void> onAssetsDeleted(List<String> assetIds) async {
    _photosDb.deleteAssets(assetIds);
    _queue.removeWhere(assetIds.contains);
    _knownAssetIds.removeAll(assetIds);
    _refreshCounts();
  }

  Future<void> registerChangeObserver() => _registerChangeObserver();

  Future<void> _registerChangeObserver() async {
    if (_observerRegistered) return;
    PhotoManager.addChangeCallback(_onPhotoLibraryChange);
    await PhotoManager.startChangeNotify();
    _observerRegistered = true;
  }

  void _registerBackgroundPauseHandler() {
    _bgChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case _backgroundPauseMethod:
          AppLogger.indexing('received background pause request');
          pause();
          return null;
        case _backgroundStartMethod:
          await _runIosBackgroundIndexing();
          return null;
      }
      return null;
    });
  }

  Future<void> _runIosBackgroundIndexing() async {
    AppLogger.indexing('iOS background indexing task triggered');
    var success = false;
    try {
      await syncPhotoLibrary();
      await _startIndexing(scheduleBackgroundTask: false);
      success = true;
    } catch (e, st) {
      AppLogger.indexing(
        'iOS background indexing task failed',
        error: e,
        stackTrace: st,
      );
    } finally {
      await _bgChannel.invokeMethod<void>(_backgroundCompleteMethod, success);
    }
  }

  void _onPhotoLibraryChange(MethodCall call) {
    if (call.method != 'change') return;
    unawaited(_reconcilePhotoLibraryDelta());
  }

  Future<void> _reconcilePhotoLibraryDelta() async {
    try {
      final assets = await _photos.listAllAssets();
      final latestIds = assets.map((asset) => asset.id).toSet();
      final addedIds = latestIds
          .difference(_knownAssetIds)
          .toList(growable: false);
      final deletedIds = _knownAssetIds
          .difference(latestIds)
          .toList(growable: false);

      if (addedIds.isNotEmpty) {
        AppLogger.indexing('photo library delta: ${addedIds.length} added');
        await onAssetsAdded(addedIds);
      }
      if (deletedIds.isNotEmpty) {
        AppLogger.indexing('photo library delta: ${deletedIds.length} deleted');
        await onAssetsDeleted(deletedIds);
      }

      _knownAssetIds = latestIds;
    } catch (e, st) {
      AppLogger.indexing(
        'failed to reconcile photo library delta',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _drainQueue({required bool runCompletionHook}) async {
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
      if (runCompletionHook) {
        await _runCompletionHook();
      }
    }
  }

  Future<void> _runCompletionHook() async {
    final hook = _onIndexingComplete;
    if (hook == null) return;
    try {
      await hook();
    } catch (e, st) {
      AppLogger.indexing(
        'post-indexing completion hook failed',
        error: e,
        stackTrace: st,
      );
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
      if (thermal == 'serious') return true;
    } catch (e) {
      AppLogger.indexing('throttle check failed: $e');
    }
    return false;
  }

  Future<void> _registerBackgroundTask() async {
    if (Platform.isIOS) {
      await _native.scheduleIndexingTask();
      return;
    }

    if (!_workmanagerInitialized) {
      await Workmanager().initialize(indexingTaskDispatcher);
      _workmanagerInitialized = true;
    }

    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        _bgTaskId,
        _androidTaskName,
        frequency: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
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

      final result = await _photos.getFullResBytesAndPath(asset);
      if (result == null) {
        AppLogger.indexing('no pixels available — skipping $assetId');
        return;
      }

      // Persist path now that entity.file has been called anyway for bytes.
      _photosDb.setLocalPath(assetId, result.path);

      final decoded = await _photos.decodeToRgb(result.bytes);
      AppLogger.indexing(
        'indexing $assetId (${decoded.width}x${decoded.height})',
      );
      await _pipeline.run(
        assetId: assetId,
        pixels: decoded.pixels,
        width: decoded.width,
        height: decoded.height,
      );
      _incrementIndexed();
    } on StorageFullException {
      // Pause the queue; re-throw so the caller (IndexingNotifier) can surface the error.
      pause();
      rethrow;
    } catch (e, st) {
      AppLogger.indexing(
        'pipeline failed for $assetId',
        error: e,
        stackTrace: st,
      );
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
