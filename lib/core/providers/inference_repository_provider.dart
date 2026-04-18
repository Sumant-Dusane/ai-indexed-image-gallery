import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_repository_provider.g.dart';

@Riverpod(keepAlive: true)
Future<InferenceRepository> inferenceRepository(Ref ref) async {
  final repo = InferenceRepository();
  await repo.initModels();
  return repo;
}
