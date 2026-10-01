import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var platformBridge: LiuliangPlatformBridge?
  private var pendingWidgetURL: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    platformBridge = LiuliangPlatformBridge.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    if let url = pendingWidgetURL {
      _ = platformBridge?.handle(url: url)
      pendingWidgetURL = nil
    }
  }

  @discardableResult
  func handleWidgetURL(_ url: URL) -> Bool {
    guard url.scheme == "liuliang", url.host == "refresh" else { return false }
    if let bridge = platformBridge {
      return bridge.handle(url: url)
    }
    pendingWidgetURL = url
    return true
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return handleWidgetURL(url) || super.application(app, open: url, options: options)
  }
}
