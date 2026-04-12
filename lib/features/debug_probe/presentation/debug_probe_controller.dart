import 'package:ai_gallery/features/debug_probe/data/debug_probe_notifier.dart';
import 'package:ai_gallery/features/debug_probe/data/debug_probe_repository.dart';
import 'package:ai_gallery/features/debug_probe/domain/debug_probe_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'debug_probe_controller.g.dart';

/// Orchestrates the probe: streams steps from [DebugProbeRepository] and
/// pushes accumulated state updates to [DebugProbeNotifier] after each step.
class DebugProbeController {
  final DebugProbeRepository _repo;
  final void Function(DebugProbeState) _onStateUpdate;

  DebugProbeController({
    required DebugProbeRepository repo,
    required void Function(DebugProbeState) onStateUpdate,
  })  : _repo = repo,
        _onStateUpdate = onStateUpdate;

  Future<void> runProbe(AssetEntity asset) async {
    final steps = <DebugProbeStep>[];
    _onStateUpdate(const DebugProbeState(isRunning: true));
    try {
      await for (final step in _repo.run(asset)) {
        steps.add(step);
        _onStateUpdate(DebugProbeState(isRunning: true, steps: List.of(steps)));
      }
      _onStateUpdate(DebugProbeState(isRunning: false, steps: List.of(steps)));
    } catch (e, _) {
      _onStateUpdate(DebugProbeState(
        isRunning: false,
        steps: List.of(steps),
        error: e.toString(),
      ));
    }
  }

  void reset() => _onStateUpdate(const DebugProbeState());
}

@riverpod
Future<DebugProbeController> debugProbeController(Ref ref) async {
  final repo = await ref.read(debugProbeRepositoryProvider.future);
  return DebugProbeController(
    repo: repo,
    onStateUpdate: (s) =>
        ref.read(debugProbeNotifierProvider.notifier).updateState(s),
  );
}
