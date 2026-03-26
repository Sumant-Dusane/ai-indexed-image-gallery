import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_repository_provider.g.dart';

@Riverpod(keepAlive: true)
Future<InferenceRepository> inferenceRepository(Ref ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final modelDir = '${dir.path}/models';
  final repo = InferenceRepository();
  await repo.initModels(modelDir);
  return repo;
}
