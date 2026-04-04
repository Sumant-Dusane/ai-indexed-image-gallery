import 'package:flutter/foundation.dart';

/// Subsystem tags. Add a new value here when a new subsystem needs logging.
enum LogCategory {
  gallery,
  indexing,
  pipeline,
  database,
  search,
  faces,
}

/// Lightweight debug logger. Zero dependencies; always a no-op in release.
///
/// ## Controlling output
///
/// Turn off everything:
///   AppLogger.enabled = false;
///
/// Silence one noisy subsystem:
///   AppLogger.disable(LogCategory.pipeline);
///
/// Re-enable it:
///   AppLogger.enable(LogCategory.pipeline);
///
/// ## Logging
///
/// Use the category shorthand for brevity:
///   AppLogger.gallery('loaded 42 assets');
///   AppLogger.indexing('queue drained', error: e, stackTrace: st);
///
/// Or the generic call if the category is dynamic:
///   AppLogger.log(LogCategory.pipeline, 'step A done');
class AppLogger {
  AppLogger._();

  /// Master switch. Automatically false in release builds.
  static bool enabled = kDebugMode;

  static final Map<LogCategory, bool> _flags = {
    for (final c in LogCategory.values) c: true,
  };

  /// Enable logging for [category].
  static void enable(LogCategory category) => _flags[category] = true;

  /// Disable logging for [category].
  static void disable(LogCategory category) => _flags[category] = false;

  /// Returns whether [category] is currently active.
  static bool isEnabled(LogCategory category) =>
      enabled && (_flags[category] ?? false);

  // ---------------------------------------------------------------------------
  // Core
  // ---------------------------------------------------------------------------

  static void log(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled || !(_flags[category] ?? false)) return;
    final tag = '[${_label(category)}]';
    debugPrint('$tag $message');
    if (error != null) debugPrint('$tag ERROR: $error');
    if (stackTrace != null) debugPrint('$tag\n$stackTrace');
  }

  // ---------------------------------------------------------------------------
  // Convenience shorthands — one per LogCategory
  // ---------------------------------------------------------------------------

  static void gallery(String msg, {Object? error, StackTrace? stackTrace}) =>
      log(LogCategory.gallery, msg, error: error, stackTrace: stackTrace);

  static void indexing(String msg, {Object? error, StackTrace? stackTrace}) =>
      log(LogCategory.indexing, msg, error: error, stackTrace: stackTrace);

  static void pipeline(String msg, {Object? error, StackTrace? stackTrace}) =>
      log(LogCategory.pipeline, msg, error: error, stackTrace: stackTrace);

  static void database(String msg, {Object? error, StackTrace? stackTrace}) =>
      log(LogCategory.database, msg, error: error, stackTrace: stackTrace);

  static void search(String msg, {Object? error, StackTrace? stackTrace}) =>
      log(LogCategory.search, msg, error: error, stackTrace: stackTrace);

  static void faces(String msg, {Object? error, StackTrace? stackTrace}) =>
      log(LogCategory.faces, msg, error: error, stackTrace: stackTrace);

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static String _label(LogCategory c) {
    switch (c) {
      case LogCategory.gallery:
        return 'GALLERY';
      case LogCategory.indexing:
        return 'INDEXING';
      case LogCategory.pipeline:
        return 'PIPELINE';
      case LogCategory.database:
        return 'DATABASE';
      case LogCategory.search:
        return 'SEARCH';
      case LogCategory.faces:
        return 'FACES';
    }
  }
}
