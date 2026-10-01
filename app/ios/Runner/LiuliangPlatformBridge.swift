import Flutter
import Foundation
import UserNotifications
import WidgetKit

/// Retain this object for the life of the Flutter engine.
final class LiuliangPlatformBridge: NSObject, UNUserNotificationCenterDelegate {
    private let widgets: FlutterMethodChannel
    private let notifications: FlutterMethodChannel
    private let schedule: FlutterMethodChannel
    private var pendingRefresh = false
    private let defaults = UserDefaults(suiteName: TrafficSnapshot.appGroup)

    private init(messenger: FlutterBinaryMessenger) {
        widgets = FlutterMethodChannel(name: "cn.liuliang/widgets", binaryMessenger: messenger)
        notifications = FlutterMethodChannel(name: "cn.liuliang/notifications", binaryMessenger: messenger)
        schedule = FlutterMethodChannel(name: "cn.liuliang/background_refresh_schedule", binaryMessenger: messenger)
        super.init()
    }

    static func register(messenger: FlutterBinaryMessenger) -> LiuliangPlatformBridge {
        let bridge = LiuliangPlatformBridge(messenger: messenger)
        UNUserNotificationCenter.current().delegate = bridge
        bridge.widgets.setMethodCallHandler { [weak bridge] call, result in
            guard let bridge else { result(FlutterError(code: "unavailable", message: "Widget bridge unavailable", details: nil)); return }
            bridge.handleWidget(call, result: result)
        }
        bridge.notifications.setMethodCallHandler { [weak bridge] call, result in
            guard let bridge else { result(FlutterError(code: "unavailable", message: "Notification bridge unavailable", details: nil)); return }
            bridge.handleNotification(call, result: result)
        }
        bridge.schedule.setMethodCallHandler { call, result in
            switch call.method {
            case "configure":
                if let minutes = call.arguments as? Int, minutes == 0 { result(true) }
                else { result(FlutterError(code: "unsupported_platform", message: "iOS 需要打开应用查询流量", details: nil)) }
            case "status":
                result(["intervalMinutes": 0, "lastStartedAt": 0, "lastFinishedAt": 0,
                        "lastOutcome": "unsupported_platform", "lastMessage": "打开应用查询后更新小组件"])
            default: result(FlutterMethodNotImplemented)
            }
        }
        return bridge
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Low-balance checks happen in the foreground, where the default is silent.
        completionHandler([.banner, .sound, .list])
    }

    /// AppDelegate/SceneDelegate delivers both cold-start and warm URLs here.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "liuliang", url.host == "refresh" else { return false }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingRefresh = true
            // Keep the flag until Dart consumes it after restoring accounts.
            // A handler can already exist while the dashboard is still restoring.
            self.widgets.invokeMethod("openFromWidget", arguments: nil)
        }
        return true
    }

    private func handleWidget(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateSnapshot":
            guard let raw = call.arguments as? [String: Any],
                  let snapshot = TrafficSnapshot.parse(raw), let defaults else {
                result(FlutterError(code: "invalid_payload", message: "Missing display snapshot or App Group", details: nil)); return
            }
            do {
                defaults.set(try snapshot.encoded(), forKey: TrafficSnapshot.storageKey)
                WidgetCenter.shared.reloadTimelines(ofKind: TrafficSnapshot.widgetKind)
                result(nil)
            } catch {
                result(FlutterError(code: "snapshot_failed", message: "Unable to save widget display data", details: nil))
            }
        case "clearSnapshot":
            guard let defaults else {
                result(FlutterError(code: "app_group_unavailable", message: "Unable to clear widget display data", details: nil)); return
            }
            defaults.removeObject(forKey: TrafficSnapshot.storageKey)
            WidgetCenter.shared.reloadTimelines(ofKind: TrafficSnapshot.widgetKind)
            result(nil)
        case "consumeLaunchRefresh":
            let pending = pendingRefresh
            pendingRefresh = false
            result(pending)
        case "requestPin":
            result(["status": "unsupported", "supported": false, "requested": false,
                    "reason": "请长按主屏幕空白处，选择添加小组件，再搜索流量小伙伴。"])
        case "installationStatus":
            WidgetCenter.shared.getCurrentConfigurations { configurations in
                DispatchQueue.main.async {
                    switch configurations {
                    case .success(let values):
                        let count = values.filter { $0.kind == TrafficSnapshot.widgetKind }.count
                        result(["status": count > 0 ? "already_added" : "not_added", "count": count])
                    case .failure:
                        result(["status": "unsupported", "reason": "暂时无法确认，请从主屏幕查看小组件。"])
                    }
                }
            }
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func handleNotification(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let center = UNUserNotificationCenter.current()
        switch call.method {
        case "requestPermission":
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { result(granted) }
            }
        case "notify":
            guard let args = call.arguments as? [String: Any], let id = args["id"] as? Int,
                  let title = args["title"] as? String, let body = args["body"] as? String else {
                result(FlutterError(code: "invalid_notification", message: "Missing notification fields", details: nil)); return
            }
            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    DispatchQueue.main.async { result(false) }; return
                }
                let content = UNMutableNotificationContent()
                content.title = String(title.prefix(120))
                content.body = String(body.prefix(500))
                content.sound = .default
                let request = UNNotificationRequest(identifier: "traffic_\(id)", content: content, trigger: nil)
                center.add(request) { error in
                    DispatchQueue.main.async { result(error == nil) }
                }
            }
        case "cancelAll":
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }
}
