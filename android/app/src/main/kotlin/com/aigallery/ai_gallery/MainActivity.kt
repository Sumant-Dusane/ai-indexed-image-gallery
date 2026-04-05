package com.aigallery.ai_gallery

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aigallery/storage")
      .setMethodCallHandler { call, result ->
        if (call.method == "getFreeBytes") {
          val stat = StatFs(Environment.getDataDirectory().path)
          result.success(stat.availableBytes)
        } else {
          result.notImplemented()
        }
      }
  }
}
