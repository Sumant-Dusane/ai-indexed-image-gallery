import 'dart:typed_data';

import 'package:ai_gallery/src/rust/api.dart' as rust_api;
import 'package:ai_gallery/src/rust/features/detection/types.dart';
import 'package:ai_gallery/src/rust/features/emotion/types.dart';
import 'package:ai_gallery/src/rust/frb_generated.dart';
import 'package:ai_gallery/src/rust/shared/bbox.dart';

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
    final result = await rust_api.embedImage(
      pixels: pixels,
      width: width,
      height: height,
    );
    return result.toList();
  }

  /// Runs YOLO object detection on raw [pixels].
  ///
  /// Returns [Detection] instances from the FRB bridge.
  /// Callers (IndexingService) add [photoId] when persisting to the DB.
  Future<List<Detection>> detectObjects({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    return rust_api.detectObjects(pixels: pixels, width: width, height: height);
  }

  /// Computes a 128-dimensional face embedding from the face region described
  /// by [bbox] (normalised 0..1 coordinates).
  Future<List<double>> embedFace({
    required Uint8List pixels,
    required int width,
    required int height,
    required BBox bbox,
  }) async {
    final result = await rust_api.embedFace(
      pixels: pixels,
      width: width,
      height: height,
      bbox: bbox,
    );
    return result.toList();
  }

  /// Classifies the emotion in the face region described by [bbox].
  Future<EmotionResult> classifyEmotion({
    required Uint8List pixels,
    required int width,
    required int height,
    required BBox bbox,
  }) {
    return rust_api.classifyEmotion(
      pixels: pixels,
      width: width,
      height: height,
      bbox: bbox,
    );
  }

  /// Computes a 64-bit perceptual hash for [pixels], returned as a 16-char hex string.
  Future<String> computePhash({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    return rust_api.computePhash(pixels: pixels, width: width, height: height);
  }

  /// Computes a 512-dimensional CLIP text embedding for [query].
  Future<List<double>> embedText(String query) async {
    final result = await rust_api.embedText(query: query);
    return result.toList();
  }
}
