import '../data/models.dart';

enum QueryHealthKind {
  healthy,
  loginExpired,
  accessError,
  unreadFields,
  backgroundPaused,
  notConnected,
  checking,
}

enum QueryHealthAction {
  reconnect,
  retry,
  inspectFields,
  backgroundSettings,
  none,
}

/// Display-only diagnostics. No phone number, carrier response or credential.
class QueryAccountHealth {
  const QueryAccountHealth({
    required this.accountId,
    required this.label,
    required this.carrier,
    required this.kind,
    required this.detail,
    required this.action,
    this.lastValidDataAt,
    this.lastAttemptAt,
    this.backgroundNote,
  });
  final String accountId;
  final String label;
  final Carrier carrier;
  final QueryHealthKind kind;
  final String detail;
  final QueryHealthAction action;
  final DateTime? lastValidDataAt;
  final DateTime? lastAttemptAt;
  final String? backgroundNote;
}

class QueryHealthReport {
  const QueryHealthReport({
    required this.version,
    required this.refreshInterval,
    required this.backgroundSummary,
    required this.accounts,
    this.backgroundFinishedAt,
  });
  final String version;
  final String refreshInterval;
  final String backgroundSummary;
  final DateTime? backgroundFinishedAt;
  final List<QueryAccountHealth> accounts;
}

QueryAccountHealth diagnoseQuery({
  required String accountId,
  required String label,
  required Carrier carrier,
  required CarrierSnapshot snapshot,
  required bool checking,
  required bool cleanupPending,
  required bool authenticationPaused,
  required bool foregroundOnly,
  DateTime? lastAttemptAt,
  bool storagePending = false,
}) {
  final backgroundNote = foregroundOnly
      ? '此连接方式需打开应用更新'
      : authenticationPaused
      ? '重新验证前，自动查询已暂停'
      : null;
  QueryAccountHealth result(
    QueryHealthKind kind,
    String detail,
    QueryHealthAction action,
  ) => QueryAccountHealth(
    accountId: accountId,
    label: label,
    carrier: carrier,
    kind: kind,
    detail: detail,
    action: action,
    lastValidDataAt: snapshot.queriedAt,
    lastAttemptAt: lastAttemptAt,
    backgroundNote: backgroundNote,
  );
  if (cleanupPending) {
    return result(
      QueryHealthKind.backgroundPaused,
      '登录资料清理尚未完成，完成清理后才能继续连接',
      QueryHealthAction.backgroundSettings,
    );
  }
  if (checking) {
    return result(
      QueryHealthKind.checking,
      '正在等待本轮官网结果，原有数据保持原查询时间',
      QueryHealthAction.none,
    );
  }
  if (snapshot.status == QueryStatus.authExpired || authenticationPaused) {
    return result(
      QueryHealthKind.loginExpired,
      '官网验证需要恢复，旧数据没有更新；请重新验证号码',
      QueryHealthAction.reconnect,
    );
  }
  if (snapshot.status == QueryStatus.notConnected) {
    return result(
      QueryHealthKind.notConnected,
      '尚未建立该号码的查询连接',
      QueryHealthAction.reconnect,
    );
  }
  if (snapshot.status == QueryStatus.error) {
    return result(
      QueryHealthKind.accessError,
      snapshot.message?.contains('HTTP 403') == true
          ? '官网拒绝了本次访问，可能需要安全验证；这不等于登录已过期'
          : '本轮未取得可用结果，可以重试或打开官网确认',
      QueryHealthAction.retry,
    );
  }
  if (storagePending) {
    return result(
      QueryHealthKind.accessError,
      '数据已取得，但登录备份保存尚未完成；请重试',
      QueryHealthAction.retry,
    );
  }
  final unread = snapshot.buckets
      .where((row) => row.remainingBytes == null && !row.isUnlimited)
      .length;
  final moneyMissing = snapshot.balanceYuan == null;
  if (unread > 0 || moneyMissing) {
    return result(
      QueryHealthKind.unreadFields,
      '${unread > 0 ? '$unread 项流量余量尚未确认。' : ''}${moneyMissing ? '话费余额尚未取得。' : ''}已读数字继续保留。',
      QueryHealthAction.inspectFields,
    );
  }
  return result(
    QueryHealthKind.healthy,
    '最近结果可用；时间表示运营商查询记录',
    QueryHealthAction.none,
  );
}
