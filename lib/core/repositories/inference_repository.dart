import 'dart:io';

import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/rust/api.dart' as rust_api;
import 'package:ai_gallery/rust/features/detection/detection_types.dart';
import 'package:ai_gallery/rust/features/emotion/emotion_types.dart';
import 'package:ai_gallery/rust/frb_generated.dart';
import 'package:ai_gallery/rust/shared/types/bbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:path_provider/path_provider.dart';

/// Thin Dart wrapper over the Rust FFI bridge.
///
/// Callers use FRB bridge types directly — no intermediate model layer needed.
/// Phase 1: Rust functions are all `todo!()` — calls will panic at runtime.
/// Phase 2 will fill in the Rust implementations.
class InferenceRepository {
  /// Initialises the Flutter ↔ Rust bridge and all ONNX sessions.
  ///
  /// Copies model assets to the documents directory on first launch,
  /// then passes the resolved path to the Rust bridge.
  /// Must be called once at app startup before any inference method.
  /// Throws if the bridge fails to initialise or any model file is missing.
  Future<void> initModels() async {
    final modelDir = await _prepareModelDir();
    await RustLib.init();
    await rust_api.initModels(modelDir: modelDir);
  }

  Future<String> _prepareModelDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    await modelDir.create(recursive: true);
    AppLogger.pipeline(
      'model dir: ${modelDir.path} | exists=${modelDir.existsSync()}',
    );

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    AppLogger.pipeline('total assets in manifest: ${allAssets.length}');

    final assets = allAssets
        .where(
          (k) =>
              k.startsWith('assets/models/') &&
              (k.endsWith('.onnx') || k.endsWith('.json')),
        )
        .toList();
    AppLogger.pipeline('model assets matched: ${assets.length} → $assets');

    for (final asset in assets) {
      final dest = File('${modelDir.path}/${asset.split('/').last}');
      if (dest.existsSync()) {
        AppLogger.pipeline('skip (exists): ${dest.path}');
        continue;
      }
      try {
        final bytes = await rootBundle.load(asset);
        await dest.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        AppLogger.pipeline(
          'copied: ${dest.path} (${bytes.lengthInBytes} bytes)',
        );
      } catch (e, st) {
        AppLogger.pipeline('FAILED to copy $asset', error: e, stackTrace: st);
      }
    }

    return modelDir.path;
  }

  /// Computes a 512-dimensional CLIP image embedding from raw [pixels]
  /// (RGB24, row-major) of size [width]×[height].
  Future<List<double>> embedImage({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    try {
      final result = await rust_api.embedImage(
        pixels: pixels,
        width: width,
        height: height,
      );
      return result.toList();
    } on PanicException catch (e, st) {
      AppLogger.rust('clip', e.message, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Runs YOLO object detection on raw [pixels].
  ///
  /// Returns [Detection] instances from the FRB bridge.
  /// Callers (IndexingService) add [photoId] when persisting to the DB.
  Future<List<Detection>> detectObjects({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    try {
      return await rust_api.detectObjects(
        pixels: pixels,
        width: width,
        height: height,
      );
    } on PanicException catch (e, st) {
      AppLogger.rust('detection', e.message, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Computes a 128-dimensional face embedding from the face region described
  /// by [bbox] (normalised 0..1 coordinates).
  Future<List<double>> embedFace({
    required Uint8List pixels,
    required int width,
    required int height,
    required BBox bbox,
  }) async {
    try {
      final result = await rust_api.embedFace(
        pixels: pixels,
        width: width,
        height: height,
        bbox: bbox,
      );
      return result.toList();
    } on PanicException catch (e, st) {
      AppLogger.rust('face', e.message, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Classifies the emotion in the face region described by [bbox].
  Future<EmotionResult> classifyEmotion({
    required Uint8List pixels,
    required int width,
    required int height,
    required BBox bbox,
  }) async {
    try {
      return await rust_api.classifyEmotion(
        pixels: pixels,
        width: width,
        height: height,
        bbox: bbox,
      );
    } on PanicException catch (e, st) {
      AppLogger.rust('emotion', e.message, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Computes a 64-bit perceptual hash for [pixels], returned as a 16-char hex string.
  Future<String> computePhash({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    try {
      return await rust_api.computePhash(
        pixels: pixels,
        width: width,
        height: height,
      );
    } on PanicException catch (e, st) {
      AppLogger.rust('phash', e.message, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Computes a 512-dimensional CLIP text embedding for [query].
  Future<List<double>> embedText(String query) async {
    try {
      final result = await rust_api.embedText(query: query);
      return result.toList();
    } on PanicException catch (e, st) {
      AppLogger.rust('clip', e.message, error: e, stackTrace: st);
      rethrow;
    }
  }
}
