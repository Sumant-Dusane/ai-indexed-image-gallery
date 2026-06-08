import 'dart:async';

import 'package:ai_gallery/core/db/schema.dart';
import 'package:ai_gallery/core/debug/app_logger.dart';
import 'package:ai_gallery/core/providers/database_provider.dart';
import 'package:ai_gallery/core/providers/indexing_notifier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingCompleteKey = 'onboarding_complete';

String storageEstimate(int photoCount) {
  final mb = 90 + (photoCount * 3 / 1024).ceil();
  return 'AI Gallery needs approximately $mb MB to analyse your $photoCount photos.';
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Timer? _phaseTimer;
  bool _hasSceneEmbedding = false;
  bool _hasDetection = false;
  bool _hasFace = false;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _refreshPhaseCounts();
    _phaseTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshPhaseCounts(),
    );
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(indexingNotifierProvider, (_, next) {
      if (next.total > 0 && next.indexed >= next.total) {
        _completeAndOpenGallery();
      }
    });

    final indexingState = ref.watch(indexingNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final total = indexingState.total;
    final indexed = indexingState.indexed.clamp(0, total);
    final progress = total == 0 ? null : indexed / total;
    final showStorageEstimate = total > 0 && indexingState.indexed == 0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.photo_library_rounded,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'AI Gallery',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(flex: 2),
              if (showStorageEstimate) ...[
                _StorageEstimateRow(text: storageEstimate(total)),
                const SizedBox(height: 18),
              ],
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text(
                total == 0
                    ? 'Preparing your photo library'
                    : 'Analysing ${_formatNumber(indexed)} of ${_formatNumber(total)} photos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              _PhaseRow(
                label: 'Scenes and places',
                isComplete: _hasSceneEmbedding,
              ),
              const SizedBox(height: 12),
              _PhaseRow(label: 'Objects and things', isComplete: _hasDetection),
              const SizedBox(height: 12),
              _PhaseRow(label: 'People', isComplete: _hasFace),
              const Spacer(flex: 3),
              TextButton(
                onPressed: _completeAndOpenGallery,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPhaseCounts() async {
    if (_hasSceneEmbedding && _hasDetection && _hasFace) return;

    try {
      final db = await ref.read(databaseProvider.future);
      final sceneCount = _hasSceneEmbedding
          ? 1
          : db
                    .select(
                      'SELECT COUNT(*) AS count FROM ${Tables.photoEmbeddings}',
                    )
                    .first['count']
                as int;
      final detectionCount = _hasDetection
          ? 1
          : db
                    .select(
                      'SELECT COUNT(*) AS count FROM ${Tables.detections}',
                    )
                    .first['count']
                as int;
      final faceCount = _hasFace
          ? 1
          : db
                    .select('SELECT COUNT(*) AS count FROM ${Tables.faces}')
                    .first['count']
                as int;

      if (!mounted) return;
      setState(() {
        _hasSceneEmbedding = _hasSceneEmbedding || sceneCount > 0;
        _hasDetection = _hasDetection || detectionCount > 0;
        _hasFace = _hasFace || faceCount > 0;
      });
    } catch (error, stackTrace) {
      AppLogger.database(
        'Failed to refresh onboarding phase counts.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _completeAndOpenGallery() async {
    if (_completing) return;
    _completing = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);

    if (!mounted) return;
    context.go('/');
  }
}

class _StorageEstimateRow extends StatelessWidget {
  final String text;

  const _StorageEstimateRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String label;
  final bool isComplete;

  const _PhaseRow({required this.label, required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 22,
          color: isComplete ? Colors.green : colorScheme.outline,
        ),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
