import 'package:flutter/material.dart';

import '../services/query_health.dart';
import 'resort_theme.dart';

/// A read-only diagnosis page. The report is already scrubbed by the caller;
/// this widget only renders its allow-listed labels, states, and actions.
class QueryHealthScreen extends StatefulWidget {
  const QueryHealthScreen({
    super.key,
    required this.report,
    required this.onAction,
  });

  final QueryHealthReport report;
  final Future<void> Function(String, QueryHealthAction) onAction;

  @override
  State<QueryHealthScreen> createState() => _QueryHealthScreenState();
}

class _QueryHealthScreenState extends State<QueryHealthScreen> {
  final Set<String> _busyAccounts = {};

  Future<void> _runAction(QueryAccountHealth account) async {
    if (_busyAccounts.contains(account.accountId) ||
        account.action == QueryHealthAction.none) {
      return;
    }
    setState(() => _busyAccounts.add(account.accountId));
    try {
      await widget.onAction(account.accountId, account.action);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这次操作没有完成，请稍后重试。')));
      }
    } finally {
      if (mounted) setState(() => _busyAccounts.remove(account.accountId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Scaffold(
      backgroundColor: ResortPalette.canvas,
      appBar: AppBar(
        title: const Text('查询状态'),
        backgroundColor: ResortPalette.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 5, 14, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReportSummary(report: report),
                  const SizedBox(height: 10),
                  _BackgroundSummary(report: report),
                  const SizedBox(height: 18),
                  _SectionHeading(count: report.accounts.length),
                  const SizedBox(height: 9),
                  if (report.accounts.isEmpty)
                    const _EmptyAccounts()
                  else
                    for (
                      var index = 0;
                      index < report.accounts.length;
                      index++
                    ) ...[
                      _AccountHealthCard(
                        account: report.accounts[index],
                        busy: _busyAccounts.contains(
                          report.accounts[index].accountId,
                        ),
                        onAction: () => _runAction(report.accounts[index]),
                      ),
                      if (index != report.accounts.length - 1)
                        const SizedBox(height: 9),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final QueryHealthReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ResortPalette.paper,
        border: Border.all(color: ResortPalette.border),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.info_outline_rounded,
            label: '应用版本',
            value: report.version,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Divider(height: 1, color: Color(0xFFE9EEE9)),
          ),
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: '自动刷新间隔',
            value: report.refreshInterval,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: ResortPalette.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: ResortPalette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: ResortPalette.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _BackgroundSummary extends StatelessWidget {
  const _BackgroundSummary({required this.report});

  final QueryHealthReport report;

  @override
  Widget build(BuildContext context) {
    final finishedAt = report.backgroundFinishedAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6DF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.sync_rounded,
              size: 18,
              color: ResortPalette.muted,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '后台查询',
                  style: TextStyle(
                    color: ResortPalette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.backgroundSummary,
                  style: const TextStyle(
                    color: ResortPalette.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (finishedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '最近结束 · ${_formatTimestamp(finishedAt)}',
                    style: const TextStyle(
                      color: ResortPalette.muted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          '账号状态',
          style: TextStyle(
            color: ResortPalette.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(
        '$count 个账号',
        style: const TextStyle(
          color: ResortPalette.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
    decoration: BoxDecoration(
      color: ResortPalette.paper,
      border: Border.all(color: ResortPalette.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      '还没有已选择的查询账号。',
      style: TextStyle(color: ResortPalette.muted, fontSize: 13),
    ),
  );
}

class _AccountHealthCard extends StatelessWidget {
  const _AccountHealthCard({
    required this.account,
    required this.busy,
    required this.onAction,
  });

  final QueryAccountHealth account;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(account.kind);
    final actionLabel = _actionLabel(account.action);
    final needsAction = actionLabel != null;
    final lastValid = account.lastValidDataAt;
    final lastAttempt = account.lastAttemptAt;
    final distinctAttempt =
        lastAttempt != null &&
            (lastValid == null || !lastAttempt.isAtSameMomentAs(lastValid))
        ? lastAttempt
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 9),
      decoration: BoxDecoration(
        color: ResortPalette.paper,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: status.color.withValues(alpha: .34)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B425D52),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResortCarrierMark(carrier: account.carrier),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        account.label,
                        style: const TextStyle(
                          color: ResortPalette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _StatusBadge(presentation: status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            account.detail,
            style: const TextStyle(
              color: ResortPalette.ink,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (account.backgroundNote case final note?
              when note.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(
                color: ResortPalette.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 7),
          _TimestampLine(
            label: lastValid == null ? '有效数据' : '上次有效数据',
            value: lastValid == null ? '尚无成功记录' : _formatTimestamp(lastValid),
            subdued: lastValid == null,
          ),
          if (distinctAttempt != null) ...[
            const SizedBox(height: 2),
            _TimestampLine(
              label: '最近尝试',
              value: _formatTimestamp(distinctAttempt),
              subdued: true,
            ),
          ],
          if (needsAction) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : onAction,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_actionIcon(account.action), size: 17),
                label: Text(busy ? '处理中' : actionLabel),
                style: TextButton.styleFrom(
                  foregroundColor: status.color,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimestampLine extends StatelessWidget {
  const _TimestampLine({
    required this.label,
    required this.value,
    this.subdued = false,
  });

  final String label;
  final String value;
  final bool subdued;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 84,
        child: Text(
          label,
          style: TextStyle(
            color: ResortPalette.muted,
            fontSize: 11,
            height: 1.35,
            fontWeight: subdued ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: subdued ? ResortPalette.muted : ResortPalette.ink,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _StatusPresentation {
  const _StatusPresentation(this.label, this.icon, this.color, this.wash);

  final String label;
  final IconData icon;
  final Color color;
  final Color wash;
}

_StatusPresentation _statusPresentation(QueryHealthKind kind) => switch (kind) {
  QueryHealthKind.healthy => const _StatusPresentation(
    '已正常读取',
    Icons.check_circle_outline_rounded,
    Color(0xFF43816D),
    Color(0xFFEAF4EF),
  ),
  QueryHealthKind.loginExpired => const _StatusPresentation(
    '登录已过期',
    Icons.login_rounded,
    Color(0xFFAC7047),
    Color(0xFFFFF1E6),
  ),
  QueryHealthKind.accessError => const _StatusPresentation(
    '访问错误',
    Icons.cloud_off_rounded,
    Color(0xFFB76F57),
    Color(0xFFFFF0EB),
  ),
  QueryHealthKind.unreadFields => const _StatusPresentation(
    '部分字段未读',
    Icons.fact_check_outlined,
    Color(0xFF7B6CA4),
    Color(0xFFF2EFF8),
  ),
  QueryHealthKind.backgroundPaused => const _StatusPresentation(
    '后台刷新已暂停',
    Icons.pause_circle_outline_rounded,
    Color(0xFF6E7982),
    Color(0xFFF0F2F3),
  ),
  QueryHealthKind.notConnected => const _StatusPresentation(
    '尚未连接',
    Icons.link_off_rounded,
    ResortPalette.muted,
    Color(0xFFF0F2EF),
  ),
  QueryHealthKind.checking => const _StatusPresentation(
    '检查中',
    Icons.sync_rounded,
    Color(0xFF548B82),
    Color(0xFFEAF4F2),
  ),
};

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.presentation});

  final _StatusPresentation presentation;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: presentation.wash,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(presentation.icon, size: 14, color: presentation.color),
        const SizedBox(width: 4),
        Text(
          presentation.label,
          style: TextStyle(
            color: presentation.color,
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

String? _actionLabel(QueryHealthAction action) => switch (action) {
  QueryHealthAction.reconnect => '重新登录',
  QueryHealthAction.retry => '重新查询',
  QueryHealthAction.inspectFields => '查看套餐明细',
  QueryHealthAction.backgroundSettings => '后台刷新设置',
  QueryHealthAction.none => null,
};

IconData _actionIcon(QueryHealthAction action) => switch (action) {
  QueryHealthAction.reconnect => Icons.login_rounded,
  QueryHealthAction.retry => Icons.refresh_rounded,
  QueryHealthAction.inspectFields => Icons.list_alt_rounded,
  QueryHealthAction.backgroundSettings => Icons.settings_outlined,
  QueryHealthAction.none => Icons.info_outline_rounded,
};

String _formatTimestamp(DateTime timestamp) {
  final value = timestamp.toLocal();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
