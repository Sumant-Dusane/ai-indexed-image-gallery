import 'dart:typed_data';

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

  /// Returns full-resolution pixel bytes for [entity] as a [Uint8List].
  ///
  /// Returns null if the file is not locally available.
  Future<Uint8List?> getFullResBytes(AssetEntity entity) async {
    final file = await entity.file;
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Returns the absolute local path for [entity], or null if unavailable.
  Future<String?> getLocalPath(AssetEntity entity) async {
    final file = await entity.file;
    return file?.path;
  }
}
