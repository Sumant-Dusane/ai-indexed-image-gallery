import BackgroundTasks
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let bgTaskId = "com.aigallery.indexing"
  private static let bgChannelName = "com.aigallery/background"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerBGProcessingTask()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupBackgroundChannel(registry: engineBridge.pluginRegistry)
  }

  // MARK: - BGProcessingTask

  private func registerBGProcessingTask() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: AppDelegate.bgTaskId,
      using: nil
    ) { task in
      guard let processingTask = task as? BGProcessingTask else { return }
      processingTask.expirationHandler = {
        // Dart-side pause() will be called when the app resumes; just mark incomplete.
        processingTask.setTaskCompleted(success: false)
      }
      // The app is in the background — indexing will resume on next foreground launch.
      processingTask.setTaskCompleted(success: true)
    }
  }

  private func setupBackgroundChannel(registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AiGalleryBackgroundPlugin") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: AppDelegate.bgChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "scheduleIndexingTask":
        self?.scheduleIndexingTask()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func scheduleIndexingTask() {
    let request = BGProcessingTaskRequest(identifier: AppDelegate.bgTaskId)
    request.requiresExternalPower = true
    request.requiresNetworkConnectivity = false
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // Non-fatal: foreground indexing still runs. Log and continue.
      print("[AppDelegate] BGTaskScheduler submit failed: \(error)")
    }
  }
}
