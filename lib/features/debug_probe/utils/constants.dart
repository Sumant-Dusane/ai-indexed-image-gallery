const bool kDebugProbeEnabled = bool.fromEnvironment(
  'DEBUG_PROBE',
  defaultValue: false,
);

const bool kSyncEnabled = !kDebugProbeEnabled;
