import 'dart:typed_data';

import 'package:ai_gallery/features/debug_probe/data/debug_probe_notifier.dart';
import 'package:ai_gallery/features/debug_probe/domain/debug_probe_step.dart';
import 'package:ai_gallery/features/debug_probe/presentation/debug_probe_controller.dart';
import 'package:ai_gallery/features/debug_probe/presentation/widgets/copy_value_row.dart';
import 'package:ai_gallery/features/debug_probe/presentation/widgets/probe_section.dart';
import 'package:ai_gallery/features/debug_probe/presentation/widgets/vector_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

class DebugProbeScreen extends ConsumerStatefulWidget {
  const DebugProbeScreen({super.key});

  @override
  ConsumerState<DebugProbeScreen> createState() => _DebugProbeScreenState();
}

class _DebugProbeScreenState extends ConsumerState<DebugProbeScreen> {
  AssetEntity? _selectedAsset;
  Uint8List? _thumbnailBytes;

  Future<void> _pickImage() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;
    final assets = await albums.first.getAssetListRange(start: 0, end: 80);
    if (!mounted) return;

    final picked = await showModalBottomSheet<AssetEntity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssetPickerSheet(assets: assets),
    );
    if (picked == null) return;

    final thumb = await picked.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    if (!mounted) return;
    setState(() {
      _selectedAsset = picked;
      _thumbnailBytes = thumb;
    });
    ref
        .read(debugProbeNotifierProvider.notifier)
        .updateState(const DebugProbeState());
  }

  Future<void> _runProbe() async {
    if (_selectedAsset == null) return;
    final ctrl = await ref.read(debugProbeControllerProvider.future);
    ctrl.runProbe(_selectedAsset!);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debugProbeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Probe'),
        actions: [
          if (_selectedAsset != null)
            state.isRunning
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Run probe',
                    onPressed: _runProbe,
                  ),
        ],
      ),
      body: Column(
        children: [
          _ImagePickerCard(thumbnailBytes: _thumbnailBytes, onPick: _pickImage),
          const Divider(height: 1),
          Expanded(child: _StepList(state: state)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step list — grows as steps arrive
// ---------------------------------------------------------------------------

class _StepList extends StatelessWidget {
  final DebugProbeState state;

  const _StepList({required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.isRunning && state.steps.isEmpty && state.error == null) {
      return const Center(
        child: Text('Pick an image and tap ▶ to run the probe'),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: ${state.error}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      // +1 for the running indicator when still in progress
      itemCount: state.steps.length + (state.isRunning ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == state.steps.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _stepCard(state.steps[i]);
      },
    );
  }

  Widget _stepCard(DebugProbeStep step) {
    if (step is ImageLoadStep) return _imageLoadCard(step);
    if (step is PHashStep) return _pHashCard(step);
    if (step is ClipStep) return _clipCard(step);
    if (step is YoloStep) return _yoloCard(step);
    if (step is FaceStep) return _faceCard(step);
    return const SizedBox.shrink();
  }

  Widget _imageLoadCard(ImageLoadStep s) {
    final kb = (s.fileSizeBytes / 1024).toStringAsFixed(1);
    final mb = (s.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
    final sizeLabel = s.fileSizeBytes >= 1024 * 1024 ? '$mb MB' : '$kb KB';

    return ProbeSection(
      title: 'Image Loaded',
      accentColor: Colors.teal,
      timing: s.elapsed,
      copyAllText:
          'dimensions: ${s.width} × ${s.height}\nfile_size: $sizeLabel (${s.fileSizeBytes} bytes)',
      children: [
        CopyValueRow(label: 'dimensions', value: '${s.width} × ${s.height} px'),
        CopyValueRow(
          label: 'file size',
          value: '$sizeLabel (${s.fileSizeBytes} bytes)',
        ),
      ],
    );
  }

  Widget _pHashCard(PHashStep s) {
    return ProbeSection(
      title: 'pHash',
      accentColor: Colors.teal.shade700,
      timing: s.elapsed,
      copyAllText: 'phash: ${s.phash}',
      children: [
        CopyValueRow(
          label: 'algorithm',
          value: 'DCT 32×32 → 8×8 top-left → 64-bit',
        ),
        CopyValueRow(label: 'phash', value: s.phash),
      ],
    );
  }

  Widget _clipCard(ClipStep s) {
    return ProbeSection(
      title: 'MobileCLIP',
      accentColor: Colors.blue,
      timing: s.elapsed,
      copyAllText:
          'clip_embedding: [${s.embedding.map((v) => v.toStringAsFixed(6)).join(', ')}]',
      children: [
        CopyValueRow(label: 'model input', value: '[1, 3, 224, 224] float32'),
        CopyValueRow(
          label: 'preprocess',
          value: 'resize 224×224 → CHW → normalize CLIP μ/σ → L2-norm output',
        ),
        CopyValueRow(label: 'output shape', value: '[1, 512] → List<double>'),
        VectorDisplay(label: 'embedding', values: s.embedding),
      ],
    );
  }

  Widget _yoloCard(YoloStep s) {
    final copyLines = [
      'non_person (${s.nonPersonDetections.length}):',
      ...s.nonPersonDetections.map(
        (d) =>
            '  ${d.label} ${(d.confidence * 100).toStringAsFixed(1)}%'
            '  x=${d.bbox.x.toStringAsFixed(3)} y=${d.bbox.y.toStringAsFixed(3)}'
            ' w=${d.bbox.w.toStringAsFixed(3)} h=${d.bbox.h.toStringAsFixed(3)}',
      ),
      'persons (${s.personDetections.length}):',
      ...s.personDetections.asMap().entries.map((e) {
        final b = e.value.bbox;
        return '  person_${e.key + 1}'
            '  ${(e.value.confidence * 100).toStringAsFixed(1)}%'
            '  x=${b.x.toStringAsFixed(3)} y=${b.y.toStringAsFixed(3)}'
            ' w=${b.w.toStringAsFixed(3)} h=${b.h.toStringAsFixed(3)}';
      }),
    ].join('\n');

    return ProbeSection(
      title: 'YOLOv8',
      accentColor: Colors.orange,
      timing: s.elapsed,
      copyAllText: copyLines,
      children: [
        CopyValueRow(label: 'model input', value: '[1, 3, 640, 640] float32'),
        CopyValueRow(
          label: 'preprocess',
          value: 'letterbox 640×640 → CHW → ÷255',
        ),
        CopyValueRow(label: 'NMS thresholds', value: 'conf 0.35 / IoU 0.45'),
        CopyValueRow(
          label: 'non-person',
          value: '${s.nonPersonDetections.length} detection(s)',
        ),
        ...s.nonPersonDetections.map(
          (d) => CopyValueRow(
            label: '  ${d.label}',
            value:
                '${(d.confidence * 100).toStringAsFixed(1)}%  '
                'x=${d.bbox.x.toStringAsFixed(3)} y=${d.bbox.y.toStringAsFixed(3)} '
                'w=${d.bbox.w.toStringAsFixed(3)} h=${d.bbox.h.toStringAsFixed(3)}',
          ),
        ),
        CopyValueRow(
          label: 'persons',
          value: '${s.personDetections.length} → fed to face pipeline',
        ),
        ...s.personDetections.asMap().entries.map(
          (e) => CopyValueRow(
            label: '  person ${e.key + 1}',
            value:
                '${(e.value.confidence * 100).toStringAsFixed(1)}%  '
                'x=${e.value.bbox.x.toStringAsFixed(3)} y=${e.value.bbox.y.toStringAsFixed(3)} '
                'w=${e.value.bbox.w.toStringAsFixed(3)} h=${e.value.bbox.h.toStringAsFixed(3)}',
          ),
        ),
      ],
    );
  }

  Widget _faceCard(FaceStep s) {
    final b = s.bbox;
    final copyText = [
      'face_${s.faceIndex + 1}:',
      '  bbox: x=${b.x} y=${b.y} w=${b.w} h=${b.h}',
      '  facenet_ms: ${s.faceNetElapsed.inMilliseconds}',
      '  emotion_ms: ${s.emotionElapsed.inMilliseconds}',
      '  emotion: ${s.emotion.label} (${s.emotion.confidence.toStringAsFixed(4)})',
      '  face_embedding: [${s.faceEmbedding.map((v) => v.toStringAsFixed(6)).join(', ')}]',
    ].join('\n');

    return ProbeSection(
      title: 'Face ${s.faceIndex + 1}',
      accentColor: Colors.purple,
      timing: s.elapsed,
      copyAllText: copyText,
      children: [
        _subHeader('MobileFaceNet', Colors.purple, s.faceNetElapsed),
        CopyValueRow(label: 'model input', value: '[1, 3, 112, 112] float32'),
        CopyValueRow(
          label: 'preprocess',
          value:
              'crop bbox+20% → resize 112×112 → (x−127.5)/128 → CHW → L2-norm',
        ),
        CopyValueRow(
          label: 'person bbox',
          value:
              'x=${b.x.toStringAsFixed(3)} y=${b.y.toStringAsFixed(3)} '
              'w=${b.w.toStringAsFixed(3)} h=${b.h.toStringAsFixed(3)}',
        ),
        VectorDisplay(label: 'face embedding', values: s.faceEmbedding),
        const SizedBox(height: 8),
        _subHeader(
          'EfficientNet-B0 — Emotion',
          Colors.amber.shade700,
          s.emotionElapsed,
        ),
        CopyValueRow(label: 'model input', value: '[1, 3, 224, 224] float32'),
        CopyValueRow(
          label: 'preprocess',
          value: 'crop bbox+20% → resize 224×224 → ÷255 → CHW',
        ),
        CopyValueRow(
          label: 'output shape',
          value: '[1, 8] logits → softmax → argmax',
        ),
        CopyValueRow(label: 'predicted label', value: s.emotion.label),
        CopyValueRow(
          label: 'confidence',
          value: s.emotion.confidence.toStringAsFixed(4),
        ),
      ],
    );
  }

  Widget _subHeader(String text, Color color, Duration elapsed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${elapsed.inMilliseconds} ms',
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image picker card
// ---------------------------------------------------------------------------

class _ImagePickerCard extends StatelessWidget {
  final Uint8List? thumbnailBytes;
  final VoidCallback onPick;

  const _ImagePickerCard({required this.thumbnailBytes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: thumbnailBytes != null
                  ? Image.memory(thumbnailBytes!, fit: BoxFit.cover)
                  : const Icon(Icons.add_photo_alternate_outlined, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thumbnailBytes != null
                      ? 'Image selected'
                      : 'No image selected',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: onPick,
                  child: const Text('Pick from library'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asset picker sheet
// ---------------------------------------------------------------------------

class _AssetPickerSheet extends StatelessWidget {
  final List<AssetEntity> assets;

  const _AssetPickerSheet({required this.assets});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Pick an image',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: controller,
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: assets.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.of(context).pop(assets[i]),
                child: FutureBuilder<Uint8List?>(
                  future: assets[i].thumbnailDataWithSize(
                    const ThumbnailSize(120, 120),
                  ),
                  builder: (_, snap) => snap.data != null
                      ? Image.memory(snap.data!, fit: BoxFit.cover)
                      : const ColoredBox(color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
