import 'package:flutter/services.dart';

enum BackgroundRefreshInterval {
  off(0, '关闭'),
  oneHour(60, '每 1 小时'),
  twoHours(120, '每 2 小时'),
  oneDay(1440, '每天');

  const BackgroundRefreshInterval(this.minutes, this.label);

  final int minutes;
  final String label;

  static BackgroundRefreshInterval fromMinutes(int? minutes) =>
      BackgroundRefreshInterval.values.firstWhere(
        (value) => value.minutes == minutes,
        orElse: () => BackgroundRefreshInterval.off,
      );
}

class BackgroundRefreshScheduler {
  static const MethodChannel _channel = MethodChannel(
    'cn.liuliang/background_refresh_schedule',
  );

  static Future<void> configure(BackgroundRefreshInterval interval) async {
    await _channel.invokeMethod<void>('configure', interval.minutes);
  }
}
