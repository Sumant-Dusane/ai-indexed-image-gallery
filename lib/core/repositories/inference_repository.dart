import 'dart:typed_data';

import '../models/detection.dart';

/// Thin Dart wrapper over the Rust FFI bridge.
///
/// Phase 1: all methods are stubs returning empty/dummy data.
/// Phase 2 will replace each stub body with the real bridge call once
/// `flutter_rust_bridge_codegen generate` has been run over `rust/src/api.rs`.
class InferenceRepository {
  /// Initialises all ONNX sessions from [modelDir].
  ///
  /// Must be called once before any inference method. Throws if any model
  /// file is missing.
  Future<void> initModels(String modelDir) async {
    // TODO(phase2): await rustApi.initModels(modelDir: modelDir);
  }

  /// Computes a 512-dimensional CLIP image embedding from raw [pixels]
  /// (RGB24, row-major) of size [width]×[height].
  Future<List<double>> embedImage({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    // TODO(phase2): return rustApi.embedImage(pixels: pixels, width: width, height: height);
    return List.filled(512, 0.0);
  }

  /// Runs YOLO object detection on raw [pixels].
  ///
  /// Returns a list of [Detection] instances (may be empty).
  Future<List<Detection>> detectObjects({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    // TODO(phase2): map rustApi.detectObjects results to Detection models.
    return [];
  }

  /// Computes a 128-dimensional face embedding from the face region described
  /// by [bboxX], [bboxY], [bboxW], [bboxH] (all normalised 0..1).
  Future<List<double>> embedFace({
    required Uint8List pixels,
    required int width,
    required int height,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
  }) async {
    // TODO(phase2): return rustApi.embedFace(...)
    return List.filled(128, 0.0);
  }

  /// Classifies the emotion in the face region.
  ///
  /// Returns a map with keys `emotion` (String) and `confidence` (double).
  Future<Map<String, dynamic>> classifyEmotion({
    required Uint8List pixels,
    required int width,
    required int height,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
  }) async {
    // TODO(phase2): return rustApi.classifyEmotion(...)
    return {'emotion': 'neutral', 'confidence': 0.0};
  }

  /// Computes a 64-bit perceptual hash for [pixels], returned as a hex string.
  Future<String> computePhash({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    // TODO(phase2): return rustApi.computePhash(...)
    return '0000000000000000';
  }

  /// Computes a 512-dimensional CLIP text embedding for [query].
  Future<List<double>> embedText(String query) async {
    // TODO(phase2): return rustApi.embedText(query: query)
    return List.filled(512, 0.0);
  }
}
