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

  static Future<BackgroundRefreshStatus> status() async {
    final value = await _channel.invokeMapMethod<String, Object?>('status');
    return BackgroundRefreshStatus.fromMap(value ?? const {});
  }
}

/// Execution diagnostics, separate from each carrier's successful query time.
class BackgroundRefreshStatus {
  const BackgroundRefreshStatus({
    required this.outcome,
    this.startedAt,
    this.finishedAt,
  });

  factory BackgroundRefreshStatus.fromMap(Map<String, Object?> value) {
    DateTime? timestamp(Object? raw) =>
        raw is int && raw > 0 ? DateTime.fromMillisecondsSinceEpoch(raw) : null;
    return BackgroundRefreshStatus(
      outcome: value['lastOutcome'] is String
          ? value['lastOutcome'] as String
          : 'never',
      startedAt: timestamp(value['lastStartedAt']),
      finishedAt: timestamp(value['lastFinishedAt']),
    );
  }

  final String outcome;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  String get label => switch (outcome) {
    'success' => '最近后台查询成功',
    'partial' => '部分号码后台查询成功',
    'no_result' => '后台未取得新数据，请打开官网验证',
    'no_eligible_accounts' => '暂无可后台查询的号码',
    'cleanup_required' => '网页登录数据尚待清除，后台查询已暂停',
    'cancelled' => '后台任务已让出或取消',
    'running' => '后台任务曾启动，结果尚未确认',
    'initialization_failed' || 'failed' || 'timeout' => '后台查询未完成',
    _ => '尚无后台查询记录',
  };
}
