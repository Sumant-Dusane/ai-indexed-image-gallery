import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_permission_provider.g.dart';

extension PermissionStateX on PermissionState {
  bool get isGranted =>
      this == PermissionState.authorized || this == PermissionState.limited;
}

/// Requests photo library permission once and caches the result.
///
/// The router's redirect reads this to gate all main routes — screens never
/// need to check permission themselves. Invalidate this provider (e.g. on
/// app resume from Settings) to trigger a fresh permission check and
/// re-run the router redirect.
@riverpod
Future<PermissionState> photoPermission(Ref ref) async {
  return PhotoRepository().requestPermission();
}
