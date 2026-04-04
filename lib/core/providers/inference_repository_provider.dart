import 'dart:io';

import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_repository_provider.g.dart';

@Riverpod(keepAlive: true)
Future<InferenceRepository> inferenceRepository(Ref ref) async {
  final modelDir = await _prepareModelDir();
  final repo = InferenceRepository();
  await repo.initModels(modelDir);
  return repo;
}

/// Copies .onnx and .json files from the asset bundle to the documents
/// directory (first launch only) and returns the directory path.
Future<String> _prepareModelDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final modelDir = Directory('${dir.path}/models');
  await modelDir.create(recursive: true);

  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final assets = manifest.listAssets().where(
    (k) =>
        k.startsWith('assets/models/') &&
        (k.endsWith('.onnx') || k.endsWith('.json')),
  );

  for (final asset in assets) {
    final dest = File('${modelDir.path}/${asset.split('/').last}');
    if (!dest.existsSync()) {
      final bytes = await rootBundle.load(asset);
      await dest.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
  }

  return modelDir.path;
}
