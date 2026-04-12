import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/providers/inference_repository_provider.dart';
import 'package:ai_gallery/core/repositories/inference_repository.dart';
import 'package:ai_gallery/core/repositories/photo_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/debug_probe_step.dart';

part 'debug_probe_repository.g.dart';

/// Runs each pipeline step sequentially and yields a [DebugProbeStep] as soon
/// as that step completes with its measured elapsed time.
///
/// Sequential execution is intentional: each model inference is timed
/// individually, errors are isolated to the exact step that failed, and we
/// avoid any ONNX Runtime first-load concurrency issues.
class DebugProbeRepository {
  final InferenceRepository _inference;

  DebugProbeRepository(this._inference);

  Stream<DebugProbeStep> run(AssetEntity asset) async* {
    final photoRepo = PhotoRepository();
    final sw = Stopwatch();

    // ── Step 1: Load & decode ────────────────────────────────────────────────
    AppLogger.pipeline('[probe] loading image');
    sw..reset()..start();
    final bytesAndPath = await photoRepo.getFullResBytesAndPath(asset);
    if (bytesAndPath == null) throw StateError('Could not load bytes for selected asset');
    final rgb = await photoRepo.decodeToRgb(bytesAndPath.bytes);
    sw.stop();
    AppLogger.pipeline('[probe] image decoded ${rgb.width}×${rgb.height} in ${sw.elapsedMilliseconds} ms');
    yield ImageLoadStep(
      width: rgb.width,
      height: rgb.height,
      fileSizeBytes: bytesAndPath.bytes.length,
      elapsed: sw.elapsed,
    );

    // ── Step 2: pHash ────────────────────────────────────────────────────────
    AppLogger.pipeline('[probe] computing pHash');
    sw..reset()..start();
    final phash = await _inference.computePhash(
      pixels: rgb.pixels,
      width: rgb.width,
      height: rgb.height,
    );
    sw.stop();
    AppLogger.pipeline('[probe] pHash=$phash in ${sw.elapsedMilliseconds} ms');
    yield PHashStep(phash: phash, elapsed: sw.elapsed);

    // ── Step 3: CLIP embedding ───────────────────────────────────────────────
    AppLogger.pipeline('[probe] running MobileCLIP');
    sw..reset()..start();
    final clip = await _inference.embedImage(
      pixels: rgb.pixels,
      width: rgb.width,
      height: rgb.height,
    );
    sw.stop();
    AppLogger.pipeline('[probe] CLIP done — ${clip.length} dims in ${sw.elapsedMilliseconds} ms');
    yield ClipStep(embedding: clip, elapsed: sw.elapsed);

    // ── Step 4: YOLO detection ───────────────────────────────────────────────
    AppLogger.pipeline('[probe] running YOLOv8');
    sw..reset()..start();
    final detections = await _inference.detectObjects(
      pixels: rgb.pixels,
      width: rgb.width,
      height: rgb.height,
    );
    sw.stop();
    final persons = detections.where((d) => d.label.toLowerCase() == 'person').toList();
    final nonPersons = detections.where((d) => d.label.toLowerCase() != 'person').toList();
    AppLogger.pipeline(
      '[probe] YOLO done — ${detections.length} detections '
      '(${persons.length} persons, ${nonPersons.length} objects) '
      'in ${sw.elapsedMilliseconds} ms',
    );
    yield YoloStep(
      nonPersonDetections: nonPersons,
      personDetections: persons,
      elapsed: sw.elapsed,
    );

    // ── Step 5: Per-person — FaceNet then Emotion ────────────────────────────
    for (var i = 0; i < persons.length; i++) {
      final bbox = persons[i].bbox;

      AppLogger.pipeline('[probe] running MobileFaceNet for person ${i + 1}');
      sw..reset()..start();
      final faceEmb = await _inference.embedFace(
        pixels: rgb.pixels,
        width: rgb.width,
        height: rgb.height,
        bbox: bbox,
      );
      final faceNetElapsed = sw.elapsed;
      AppLogger.pipeline('[probe] FaceNet done — ${faceEmb.length} dims in ${faceNetElapsed.inMilliseconds} ms');

      AppLogger.pipeline('[probe] running Emotion classifier for person ${i + 1}');
      sw..reset()..start();
      final emotion = await _inference.classifyEmotion(
        pixels: rgb.pixels,
        width: rgb.width,
        height: rgb.height,
        bbox: bbox,
      );
      final emotionElapsed = sw.elapsed;
      AppLogger.pipeline('[probe] Emotion done — ${emotion.label} (${emotion.confidence.toStringAsFixed(3)}) in ${emotionElapsed.inMilliseconds} ms');

      yield FaceStep(
        faceIndex: i,
        bbox: bbox,
        faceEmbedding: faceEmb,
        faceNetElapsed: faceNetElapsed,
        emotionElapsed: emotionElapsed,
        emotion: emotion,
        elapsed: faceNetElapsed + emotionElapsed,
      );
    }

    AppLogger.pipeline('[probe] all steps complete');
  }
}

@riverpod
Future<DebugProbeRepository> debugProbeRepository(Ref ref) async {
  final inference = await ref.read(inferenceRepositoryProvider.future);
  return DebugProbeRepository(inference);
}
