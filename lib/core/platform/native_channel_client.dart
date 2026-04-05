import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'native_channel_client.g.dart';

/// Central delegator for all platform channel calls.
///
/// All [MethodChannel] constants and method names live here.
/// When a native call breaks, this is the single file to open.
class NativeChannelClient {
  static const _storageChannel  = MethodChannel('com.aigallery/storage');
  static const _throttleChannel = MethodChannel('com.aigallery/throttle');
  static const _bgChannel       = MethodChannel('com.aigallery/background');

  /// Free bytes on the device's internal storage.
  Future<int> getFreeBytes() async {
    return await _storageChannel.invokeMethod<int>('getFreeBytes') ?? 0;
  }

  /// Battery level in [0.0, 1.0]. Returns 1.0 on any channel failure.
  Future<double> getBatteryLevel() async {
    return await _throttleChannel.invokeMethod<double>('getBatteryLevel') ?? 1.0;
  }

  /// Current thermal state string: 'nominal', 'fair', 'serious', 'critical'.
  /// Always returns 'nominal' on Android (thermal gating is iOS-only).
  Future<String> getThermalState() async {
    if (!Platform.isIOS) return 'nominal';
    return await _throttleChannel.invokeMethod<String>('getThermalState') ?? 'nominal';
  }

  /// Schedules the BGProcessingTask on iOS.
  /// No-op on Android — WorkManager handles background scheduling directly.
  Future<void> scheduleIndexingTask() async {
    if (!Platform.isIOS) return;
    await _bgChannel.invokeMethod<void>('scheduleIndexingTask');
  }
}

@Riverpod(keepAlive: true)
NativeChannelClient nativeChannelClient(Ref ref) => NativeChannelClient();
