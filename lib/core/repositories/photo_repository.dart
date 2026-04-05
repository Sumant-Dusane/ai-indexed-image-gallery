import 'package:ai_gallery/core/errors/storage_full_exception.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

/// Wraps [photo_manager] to provide asset listing and pixel byte access.
/// All methods are async and must not be called on the UI thread directly —
/// the caller is responsible for running them in a background isolate when
/// needed for heavy work.
class PhotoRepository {
  /// Requests photo library permission.
  ///
  /// Returns the [PermissionState]. Callers should check the result and show
  /// the appropriate UI if permission is not [PermissionState.authorized] or
  /// [PermissionState.limited].
  Future<PermissionState> requestPermission() async {
    return PhotoManager.requestPermissionExtend();
  }

  /// Returns the total number of assets in the photo library.
  ///
  /// Uses [AssetPathEntity.assetCountAsync] — much faster than loading all
  /// assets, suitable for pre-indexing storage estimates.
  Future<int> getAssetCount() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );
    if (albums.isEmpty) return 0;
    return albums.first.assetCountAsync;
  }

  /// Returns all image and video assets from the photo library, sorted by
  /// creation date descending (newest first).
  ///
  /// Loads all assets in a single call — suitable for Phase 1 bootstrapping.
  /// Later phases should page with [loadAssetPage].
  Future<List<AssetEntity>> listAllAssets() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (albums.isEmpty) return [];

    // The first album returned with [RequestType.common] is the "all assets"
    // album on both iOS and Android.
    final all = albums.first;
    final count = await all.assetCountAsync;
    return all.getAssetListRange(start: 0, end: count);
  }

  /// Loads a page of assets for incremental loading.
  Future<List<AssetEntity>> loadAssetPage({
    required AssetPathEntity album,
    required int page,
    int pageSize = 80,
  }) async {
    return album.getAssetListPaged(page: page, size: pageSize);
  }

  /// Returns compressed thumbnail bytes for [entity] at 200×200 px.
  ///
  /// Returns null if the asset cannot be read (e.g., iCloud placeholder not
  /// yet downloaded).
  Future<Uint8List?> getThumbnailBytes(AssetEntity entity) async {
    return entity.thumbnailDataWithSize(const ThumbnailSize(200, 200));
  }

  /// Returns full-resolution pixel bytes and the local path for [entity].
  ///
  /// Calls [entity.file] exactly once — on iOS this materialises a temp copy,
  /// so callers must not also call [getLocalPath] for the same asset.
  /// Returns null if the file is not locally available.
  /// Throws [StorageFullException] if the device has no free storage space.
  Future<({Uint8List bytes, String path})?> getFullResBytesAndPath(
    AssetEntity entity,
  ) async {
    try {
      final file = await entity.file;
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return (bytes: bytes, path: file.path);
    } on PlatformException catch (e) {
      if (_isStorageFull(e)) throw StorageFullException(e.message ?? 'Device storage is full');
      rethrow;
    }
  }

  /// Returns true if [e] indicates the device has no free storage space.
  ///
  /// iOS: NSCocoaErrorDomain code 640 = NSFileWriteOutOfSpaceError.
  /// Android / fallback: message-based detection.
  bool _isStorageFull(PlatformException e) {
    if (e.code.contains('640')) return true;
    final msg = (e.message ?? '').toLowerCase();
    return msg.contains('out of space') || msg.contains('no space left');
  }
}
