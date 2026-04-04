import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/providers/photo_permission_provider.dart';
import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_provider.g.dart';

/// Returns all device photos grouped by month key `'YYYY-MM'`,
/// ordered newest-month first, newest photo first within each month.
///
/// Reads directly from the photo library — no DB required. This means the
/// grid is populated the moment the user grants permission, before any
/// AI indexing has run.
///
/// Returns an empty map if permission is not authorized or limited — the
/// router redirect will have already navigated away from the gallery in
/// that case, so this is only a race-condition guard on first launch.
@riverpod
Future<Map<String, List<AssetEntity>>> gallery(Ref ref) async {
  final permission = await ref.watch(photoPermissionProvider.future);
  if (!permission.isGranted) return {};

  AppLogger.gallery('loading assets from photo library');
  final assets = await PhotoRepository().listAllAssets();
  AppLogger.gallery('loaded ${assets.length} assets from photo library');

  final grouped = <String, List<AssetEntity>>{};
  for (final asset in assets) {
    final key = _monthKey(asset.createDateTime);
    grouped.putIfAbsent(key, () => []).add(asset);
  }
  AppLogger.gallery('grouped into ${grouped.length} month buckets');
  return grouped;
}

String _monthKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
