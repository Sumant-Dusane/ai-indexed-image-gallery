import 'dart:typed_data';

import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/rust/api.dart' as rust_api;
import 'package:ai_gallery/rust/features/detection/detection_types.dart';
import 'package:ai_gallery/rust/features/emotion/emotion_types.dart';
import 'package:ai_gallery/rust/frb_generated.dart';
import 'package:ai_gallery/rust/shared/types/bbox.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

/// Thin Dart wrapper over the Rust FFI bridge.
///
/// Callers use FRB bridge types directly — no intermediate model layer needed.
/// Phase 1: Rust functions are all `todo!()` — calls will panic at runtime.
/// Phase 2 will fill in the Rust implementations.
class InferenceRepository {
  /// Initialises the Flutter ↔ Rust bridge and all ONNX sessions from [modelDir].
  ///
  /// Must be called once at app startup before any inference method.
  /// Throws if the bridge fails to initialise or any model file is missing.
  Future<void> initModels(String modelDir) async {
    await RustLib.init();
    await rust_api.initModels(modelDir: modelDir);
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
      return await rust_api.detectObjects(pixels: pixels, width: width, height: height);
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
      return await rust_api.computePhash(pixels: pixels, width: width, height: height);
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
