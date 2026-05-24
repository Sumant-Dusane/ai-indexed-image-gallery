import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/inference/image_tensor_utils.dart';
import 'package:ai_gallery/core/inference/inference_types.dart';
import 'package:ai_gallery/core/inference/phash.dart';
import 'package:ai_gallery/core/inference/yolo_postprocess.dart';
import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Single app-facing inference seam.
///
/// Callers pass RGB24 pixels and receive Dart-owned DTOs. ONNX Runtime sessions,
/// preprocessing, postprocessing, text tokenisation, and pHash stay hidden here.
class InferenceRepository {
  final OnnxRuntime _runtime = OnnxRuntime();

  OrtSession? _clipImageSession;
  OrtSession? _clipTextSession;
  OrtSession? _faceSession;
  OrtSession? _yoloSession;
  OrtSession? _emotionSession;
  dynamic _tokenizer;
  bool _initialized = false;

  /// Initialises all ONNX sessions and the CLIP tokenizer.
  ///
  /// Must be called once at app startup before inference methods. Safe to call
  /// multiple times; subsequent calls are no-ops.
  Future<void> initModels() async {
    if (_initialized) return;
    try {
      _clipImageSession = await _runtime.createSessionFromAsset(
        'assets/models/mobileclip_s1_image_int8.onnx',
      );
      _clipTextSession = await _runtime.createSessionFromAsset(
        'assets/models/mobileclip_s1_text_int8.onnx',
      );
      _faceSession = await _runtime.createSessionFromAsset(
        'assets/models/mobilefacenet_int8.onnx',
      );
      _yoloSession = await _runtime.createSessionFromAsset(
        'assets/models/yolov8n_int8.onnx',
      );
      _emotionSession = await _runtime.createSessionFromAsset(
        'assets/models/emotion_enet_b0_int8.onnx',
      );

      final String tokenizerJson = await rootBundle.loadString(
        'assets/models/bpe_vocab.json',
      );
      _tokenizer = TokenizerJsonLoader.fromJsonString(
        _normalizeTokenizerJsonForLoader(tokenizerJson),
      );
      _initialized = true;
    } catch (e, st) {
      AppLogger.inference(
        'init',
        'model initialisation failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Computes a 512-dimensional CLIP image embedding from raw RGB24 pixels.
  Future<List<double>> embedImage({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    return _guard('clip-image', () async {
      await initModels();
      final input = preprocessClipImage(pixels, width, height);
      final raw = await _runVector(
        session: _clipImageSession!,
        inputName: 'image',
        input: input,
        shape: const [1, 3, 224, 224],
        outputName: 'embedding',
      );
      return l2Normalize(raw);
    });
  }

  /// Runs YOLO object detection on raw RGB24 pixels.
  Future<List<Detection>> detectObjects({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    return _guard('detection', () async {
      await initModels();
      final letterbox = preprocessYolo(pixels, width, height);
      final raw = await _runVector(
        session: _yoloSession!,
        inputName: 'images',
        input: letterbox.data,
        shape: const [1, 3, 640, 640],
        outputName: 'output0',
      );
      return parseYoloOutput(raw, letterbox, width, height);
    });
  }

  /// Computes a 128-dimensional face embedding from the face region.
  Future<List<double>> embedFace({
    required Uint8List pixels,
    required int width,
    required int height,
    required BBox bbox,
  }) {
    return _guard('face', () async {
      await initModels();
      final input = preprocessFace(pixels, width, height, bbox);
      final raw = await _runVector(
        session: _faceSession!,
        inputName: 'face',
        input: input,
        shape: const [1, 3, 112, 112],
        outputName: 'embedding',
      );
      return l2Normalize(raw);
    });
  }

  /// Classifies the emotion in the face region described by [bbox].
  Future<EmotionResult> classifyEmotion({
    required Uint8List pixels,
    required int width,
    required int height,
    required BBox bbox,
  }) {
    return _guard('emotion', () async {
      await initModels();
      final input = preprocessEmotion(pixels, width, height, bbox);
      final logits = await _runVector(
        session: _emotionSession!,
        inputName: 'face',
        input: input,
        shape: const [1, 3, 224, 224],
        outputName: 'logits',
      );
      final probs = _softmax(logits);
      var bestIdx = 0;
      for (var i = 1; i < probs.length; i++) {
        if (probs[i] > probs[bestIdx]) bestIdx = i;
      }
      return EmotionResult(
        label: bestIdx == 7 ? 'neutral' : _emotionLabels[bestIdx],
        confidence: probs[bestIdx],
      );
    });
  }

  /// Computes a 64-bit perceptual hash, returned as a 16-char hex string.
  Future<String> computePhash({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    return _guard('phash', () async => computePhashDart(pixels, width, height));
  }

  /// Computes a 512-dimensional CLIP text embedding for [query].
  Future<List<double>> embedText(String query) {
    return _guard('clip-text', () async {
      await initModels();
      final encoding = _tokenizer.encode(query);
      final ids = List<int>.from(encoding.ids as Iterable);
      if (ids.length > 77) {
        ids.removeRange(77, ids.length);
      }
      while (ids.length < 77) {
        ids.add(0);
      }
      final raw = await _runVector(
        session: _clipTextSession!,
        inputName: 'tokens',
        input: Int32List.fromList(ids),
        shape: const [1, 77],
        outputName: 'embedding',
      );
      return l2Normalize(raw);
    });
  }

  Future<List<double>> _runVector({
    required OrtSession session,
    required String inputName,
    required dynamic input,
    required List<int> shape,
    required String outputName,
  }) async {
    final inputValue = await OrtValue.fromList(input, shape);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({inputName: inputValue});
      final output = outputs[outputName] ?? _singleOutput(outputs, outputName);
      if (output == null) {
        throw StateError(
          'ONNX output "$outputName" not found. '
          'Available outputs: ${outputs.keys.join(', ')}',
        );
      }
      final raw = await output.asFlattenedList();
      return raw.map((v) => (v as num).toDouble()).toList(growable: false);
    } finally {
      await inputValue.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    }
  }

  Future<T> _guard<T>(String module, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e, st) {
      AppLogger.inference(module, 'inference failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

OrtValue? _singleOutput(Map<String, OrtValue> outputs, String requestedName) {
  if (outputs.length != 1) return null;
  final entry = outputs.entries.single;
  AppLogger.inference(
    'onnx',
    'using output "${entry.key}" instead of requested "$requestedName"',
  );
  return entry.value;
}

const _emotionLabels = [
  'neutral',
  'happy',
  'sad',
  'surprised',
  'fear',
  'disgust',
  'angry',
  'contempt',
];

List<double> _softmax(List<double> logits) {
  final maxLogit = logits.reduce((a, b) => a > b ? a : b);
  final exp = logits.map((v) => math.exp(v - maxLogit)).toList(growable: false);
  final sum = exp.reduce((a, b) => a + b);
  return exp.map((v) => v / sum).toList(growable: false);
}

String _normalizeTokenizerJsonForLoader(String rawJson) {
  final data = jsonDecode(rawJson) as Map<String, dynamic>;
  final model = data['model'];
  if (model is! Map<String, dynamic>) return rawJson;

  final merges = model['merges'];
  if (merges is! List || merges.isEmpty || merges.first is String) {
    return rawJson;
  }

  model['merges'] = merges
      .map((merge) {
        if (merge is List && merge.length >= 2) {
          return '${merge[0]} ${merge[1]}';
        }
        return merge.toString();
      })
      .toList(growable: false);

  return jsonEncode(data);
}
