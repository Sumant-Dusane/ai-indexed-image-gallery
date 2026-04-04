import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:ai_gallery/core/providers/inference_repository_provider.dart';
import 'package:ai_gallery/core/repositories/detections_repository.dart';
import 'package:ai_gallery/core/repositories/embeddings_repository.dart';
import 'package:ai_gallery/core/repositories/faces_repository.dart';
import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:ai_gallery/core/repositories/photos_db_repository.dart';
import 'package:ai_gallery/services/image_pipeline.dart';
import 'package:ai_gallery/services/indexing_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'indexing_service_provider.g.dart';

@Riverpod(keepAlive: true)
Future<IndexingService> indexingService(Ref ref) async {
  // ref.read (not ref.watch) — both are keepAlive singletons that never
  // change. ref.watch would set up subscriptions that trigger spurious
  // async re-runs of this body, causing init_models() to be called twice.
  final db = await ref.read(databaseProvider.future);
  final inference = await ref.read(inferenceRepositoryProvider.future);

  final photosDb = PhotosDbRepository(db);
  final detections = DetectionsRepository(db);
  final faces = FacesRepository(db);
  final embeddings = EmbeddingsRepository(db);

  final pipeline = ImageIndexingPipeline(
    inference: inference,
    photosDb: photosDb,
    detections: detections,
    faces: faces,
    embeddings: embeddings,
  );

  return IndexingService(
    photosDb: photosDb,
    pipeline: pipeline,
    photos: PhotoRepository(),
    onStateUpdate: (s) =>
        ref.read(indexingNotifierProvider.notifier).updateState(s),
  );
}
