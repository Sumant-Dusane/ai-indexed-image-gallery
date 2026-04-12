import 'package:ai_gallery/features/debug_probe/domain/debug_probe_step.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'debug_probe_notifier.g.dart';

class DebugProbeState {
  final bool isRunning;
  final List<DebugProbeStep> steps;
  final String? error;

  const DebugProbeState({
    this.isRunning = false,
    this.steps = const [],
    this.error,
  });
}

/// Holds the live probe state as steps accumulate.
@riverpod
class DebugProbeNotifier extends _$DebugProbeNotifier {
  @override
  DebugProbeState build() => const DebugProbeState();

  void updateState(DebugProbeState state) => this.state = state;
}
