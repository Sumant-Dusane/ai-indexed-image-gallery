const bool kDebugProbeEnabled = bool.fromEnvironment(
  'DEBUG_PROBE',
  defaultValue: false,
);

const int kDebugIndexLimit = kDebugProbeEnabled
    ? int.fromEnvironment('DEBUG_INDEX_LIMIT', defaultValue: 0)
    : 0;

const bool kDebugLimitedIndexingEnabled = kDebugIndexLimit > 0;

const bool kSyncEnabled = !kDebugProbeEnabled || kDebugLimitedIndexingEnabled;
