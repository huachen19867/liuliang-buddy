import 'package:flutter/services.dart';

class SystemSurfacesStatus {
  const SystemSurfacesStatus({
    required this.notificationEnabled,
    required this.tileEnabled,
    required this.notificationsAllowed,
    required this.tileAddSupported,
  });

  factory SystemSurfacesStatus.fromMap(Map<String, Object?> value) =>
      SystemSurfacesStatus(
        notificationEnabled: value['notificationEnabled'] == true,
        tileEnabled: value['tileEnabled'] == true,
        notificationsAllowed: value['notificationsAllowed'] == true,
        tileAddSupported: value['tileAddSupported'] == true,
      );

  final bool notificationEnabled;
  final bool tileEnabled;
  final bool notificationsAllowed;
  final bool tileAddSupported;
}

class SystemSurfaces {
  static const channel = MethodChannel('cn.liuliang/system_surfaces');
  static const _notifications = MethodChannel('cn.liuliang/notifications');

  static Future<SystemSurfacesStatus> status() => _read('getStatus');
  static Future<SystemSurfacesStatus> setNotificationEnabled(bool value) =>
      _read('setNotificationEnabled', value);
  static Future<SystemSurfacesStatus> setTileEnabled(bool value) =>
      _read('setTileEnabled', value);
  static Future<bool> requestPermission() async =>
      await _notifications.invokeMethod<bool>('requestPermission') ?? false;
  static Future<String> requestAddTile() async =>
      await channel.invokeMethod<String>('requestAddTile') ?? 'unavailable';

  static Future<SystemSurfacesStatus> _read(
    String method, [
    bool? value,
  ]) async {
    final data = await channel.invokeMapMethod<String, Object?>(method, value);
    if (data == null) {
      throw PlatformException(code: 'missing_status', message: '系统没有返回设置状态');
    }
    return SystemSurfacesStatus.fromMap(data);
  }
}
