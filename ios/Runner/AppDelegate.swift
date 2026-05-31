import BackgroundTasks
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let bgTaskId = "com.aigallery.indexing"
  private static let bgChannelName = "com.aigallery/background"
  private static let storageChannelName = "com.aigallery/storage"
  private static let throttleChannelName = "com.aigallery/throttle"
  private static let pauseMethodName = "pauseIndexing"
  private static let startMethodName = "startIndexing"
  private static let completeMethodName = "completeIndexingTask"
  private var backgroundChannel: FlutterMethodChannel?
  private var activeIndexingTask: BGProcessingTask?

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
    setupStorageChannel(registry: engineBridge.pluginRegistry)
    setupThrottleChannel(registry: engineBridge.pluginRegistry)
  }

  // MARK: - BGProcessingTask

  private func registerBGProcessingTask() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: AppDelegate.bgTaskId,
      using: nil
    ) { [weak self] task in
      guard let processingTask = task as? BGProcessingTask else { return }
      self?.activeIndexingTask = processingTask
      processingTask.expirationHandler = { [weak self] in
        self?.backgroundChannel?.invokeMethod(AppDelegate.pauseMethodName, arguments: nil)
        self?.finishIndexingTask(success: false)
      }

      self?.scheduleIndexingTask()
      guard let channel = self?.backgroundChannel else {
        self?.finishIndexingTask(success: false)
        return
      }
      channel.invokeMethod(AppDelegate.startMethodName, arguments: nil)
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
    backgroundChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "scheduleIndexingTask":
        self?.scheduleIndexingTask()
        result(nil)
      case AppDelegate.completeMethodName:
        self?.finishIndexingTask(success: call.arguments as? Bool ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupStorageChannel(registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AiGalleryStoragePlugin") else { return }
    let channel = FlutterMethodChannel(
      name: AppDelegate.storageChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { _, result in
      do {
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let free = (attrs[.systemFreeSize] as? Int) ?? 0
        result(free)
      } catch {
        result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func setupThrottleChannel(registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AiGalleryThrottlePlugin") else { return }
    UIDevice.current.isBatteryMonitoringEnabled = true
    let channel = FlutterMethodChannel(
      name: AppDelegate.throttleChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getBatteryLevel":
        let level = UIDevice.current.batteryLevel
        result(level < 0 ? 1.0 : Double(level))
      case "getThermalState":
        result(Self.thermalStateName(ProcessInfo.processInfo.thermalState))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "nominal"
    }
  }

  private func finishIndexingTask(success: Bool) {
    guard let task = activeIndexingTask else { return }
    activeIndexingTask = nil
    task.setTaskCompleted(success: success)
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
