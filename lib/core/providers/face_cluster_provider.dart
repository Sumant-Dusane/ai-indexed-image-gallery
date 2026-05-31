import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/models/cluster.dart';
import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:ai_gallery/features/people/domain/face_cluster_state.dart';
import 'package:ai_gallery/services/face_cluster_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'face_cluster_provider.g.dart';

final faceClusterProvider = faceClusterNotifierProvider;

@Riverpod(keepAlive: true)
Future<FaceClusterService> faceClusterService(Ref ref) async {
  final db = await ref.read(databaseProvider.future);
  return FaceClusterService(db: db);
}

@riverpod
Future<String?> faceClusterCoverPhotoId(Ref ref, int clusterId) async {
  try {
    final db = await ref.read(databaseProvider.future);
    final rows = db.select(
      '''
      SELECT f.photo_id
      FROM clusters c
      JOIN faces f ON c.cover_face_id = f.id
      WHERE c.id = ?
    ''',
      [clusterId],
    );
    return rows.isEmpty ? null : rows.first['photo_id'] as String;
  } catch (error, stackTrace) {
    AppLogger.faces(
      'failed to load cover photo for cluster $clusterId',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

@riverpod
Future<List<String>> faceClusterPhotoIds(Ref ref, int clusterId) async {
  try {
    final db = await ref.read(databaseProvider.future);
    final rows = db.select(
      '''
      SELECT DISTINCT p.id, p.taken_at
      FROM faces f
      JOIN photos p ON f.photo_id = p.id
      WHERE f.cluster_id = ?
      ORDER BY p.taken_at DESC
    ''',
      [clusterId],
    );
    return [for (final row in rows) row['id'] as String];
  } catch (error, stackTrace) {
    AppLogger.faces(
      'failed to load photos for cluster $clusterId',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

@riverpod
class FaceClusterNotifier extends _$FaceClusterNotifier {
  @override
  FaceClusterState build() => const FaceClusterState();

  Future<void> loadClusters() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final rows = db.select('''
        SELECT id, name, cover_face_id, member_count
        FROM clusters
        ORDER BY
          CASE WHEN name IS NULL THEN 0 ELSE 1 END,
          member_count DESC
      ''');
      state = state.copyWith(
        clusters: [
          for (final row in rows)
            FaceCluster(
              id: row['id'] as int,
              name: row['name'] as String?,
              coverFaceId: row['cover_face_id'] as int?,
              memberCount: row['member_count'] as int,
            ),
        ],
      );
    } catch (error, stackTrace) {
      AppLogger.faces(
        'failed to load face clusters',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> runClustering() async {
    if (state.isClustering) return;
    state = state.copyWith(isClustering: true);
    try {
      final service = await ref.read(faceClusterServiceProvider.future);
      await service.runFullClustering();
      await loadClusters();
    } catch (error, stackTrace) {
      AppLogger.faces(
        'face clustering failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      state = state.copyWith(isClustering: false);
    }
  }

  Future<void> nameCluster(int clusterId, String name) async {
    try {
      final service = await ref.read(faceClusterServiceProvider.future);
      await service.nameCluster(clusterId, name);
      await loadClusters();
    } catch (error, stackTrace) {
      AppLogger.faces(
        'failed to name face cluster $clusterId',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteCluster(int clusterId) async {
    try {
      final service = await ref.read(faceClusterServiceProvider.future);
      await service.deleteCluster(clusterId);
      ref.invalidate(faceClusterCoverPhotoIdProvider(clusterId));
      ref.invalidate(faceClusterPhotoIdsProvider(clusterId));
      await loadClusters();
    } catch (error, stackTrace) {
      AppLogger.faces(
        'failed to delete face cluster $clusterId',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
