import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/traffic_summary.dart';
import 'widget_preview_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.snapshots,
    required this.thresholdGb,
    required this.onConnect,
    required this.onRefresh,
    required this.onRefreshAll,
    required this.onSettings,
    required this.onAbout,
    this.onAddWidget,
    this.widgetSupported = true,
    this.demo = false,
  });

  final List<CarrierSnapshot> snapshots;
  final double thresholdGb;
  final ValueChanged<Carrier> onConnect;
  final ValueChanged<Carrier> onRefresh;
  final VoidCallback onRefreshAll;
  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final VoidCallback? onAddWidget;
  final bool widgetSupported;
  final bool demo;

  static const _ink = Color(0xFF293448);
  static const _mutedInk = Color(0xFF777D87);
  static const _canvas = Color(0xFFFFF9F1);
  static const _mobileBlue = Color(0xFF4E83D9);
  static const _broadnetPeach = Color(0xFFE58C79);

  @override
  Widget build(BuildContext context) {
    final mobile = _snapshotFor(Carrier.mobile);
    final broadnet = _snapshotFor(Carrier.broadnet);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  if (demo) ...[
                    const SizedBox(height: 15),
                    const _DemoNotice(),
                  ],
                  const SizedBox(height: 18),
                  _SummaryCard(
                    mobile: mobile,
                    broadnet: broadnet,
                    thresholdGb: thresholdGb,
                    onRefreshAll: onRefreshAll,
                  ),
                  const SizedBox(height: 18),
                  _CarrierCard(
                    carrier: Carrier.mobile,
                    slotLabel: '移动卡',
                    snapshot: mobile,
                    accent: _mobileBlue,
                    onConnect: () => onConnect(Carrier.mobile),
                    onRefresh: () => onRefresh(Carrier.mobile),
                  ),
                  const SizedBox(height: 13),
                  _CarrierCard(
                    carrier: Carrier.broadnet,
                    slotLabel: '广电卡',
                    snapshot: broadnet,
                    accent: _broadnetPeach,
                    onConnect: () => onConnect(Carrier.broadnet),
                    onRefresh: () => onRefresh(Carrier.broadnet),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _FooterAction(
                          icon: Icons.tune_rounded,
                          label: '提醒设置',
                          onTap: onSettings,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FooterAction(
                          icon: Icons.info_outline_rounded,
                          label: '关于与说明',
                          onTap: onAbout,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WidgetPreviewCard(
                    widgetSupported: widgetSupported,
                    onAddWidget: onAddWidget,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '数据由运营商查询提供，更新时间显示在对应卡片中。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _mutedInk,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6D7),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Center(
            child: CustomPaint(
              size: Size(30, 30),
              painter: _CuteDropMarkPainter(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '流量小伙伴',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '两张卡的流量，清楚一点',
                style: theme.textTheme.bodySmall?.copyWith(color: _mutedInk),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onRefreshAll,
          tooltip: '刷新两张卡',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            fixedSize: const Size(46, 46),
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  CarrierSnapshot? _snapshotFor(Carrier carrier) {
    for (final snapshot in snapshots) {
      if (snapshot.carrier == carrier) return snapshot;
    }
    return null;
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9B8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1D58F)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined, color: Color(0xFF85652A), size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '界面演示 · 非真实流量',
              style: TextStyle(
                color: Color(0xFF6F5524),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.mobile,
    required this.broadnet,
    required this.thresholdGb,
    required this.onRefreshAll,
  });

  final CarrierSnapshot? mobile;
  final CarrierSnapshot? broadnet;
  final double thresholdGb;
  final VoidCallback onRefreshAll;

  @override
  Widget build(BuildContext context) {
    final hasTotal = _canAggregate(mobile) && _canAggregate(broadnet);
    final hasRecords =
        (mobile?.queriedAt != null && mobile!.buckets.isNotEmpty) ||
        (broadnet?.queriedAt != null && broadnet!.buckets.isNotEmpty);
    final bytes = hasTotal
        ? mobile!.generalRemainingBytes! + broadnet!.generalRemainingBytes!
        : 0;
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7D9),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFF3D7C8)),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 142,
            child: IgnorePointer(
              child: CustomPaint(painter: _CloudDropPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasTotal ? '通用流量总览' : '两张卡，一眼看清',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF5D514B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onRefreshAll,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6D5147),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.sync_rounded, size: 17),
                      label: const Text('全部刷新'),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                if (hasTotal) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatGb(bytes),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: const Color(0xFF3A414D),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          height: .95,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 4),
                        child: Text(
                          'GB',
                          style: TextStyle(
                            color: Color(0xFF71645D),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '两张卡的通用流量剩余合计',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF71645D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ThresholdHint(thresholdGb: thresholdGb),
                ] else ...[
                  Text(
                    hasRecords ? '各卡余量见下方，通用流量总览待确认。' : '连接运营商账号后，流量会显示在这里。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF71645D),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Row(
                    children: [
                      _MiniCarrierDot(color: Color(0xFF4E83D9)),
                      SizedBox(width: 6),
                      Text('中国移动', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 14),
                      _MiniCarrierDot(color: Color(0xFFE58C79)),
                      SizedBox(width: 6),
                      Text('中国广电', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canAggregate(CarrierSnapshot? snapshot) {
    return snapshot?.status == QueryStatus.success &&
        snapshot?.generalRemainingBytes != null;
  }
}

class _ThresholdHint extends StatelessWidget {
  const _ThresholdHint({required this.thresholdGb});

  final double thresholdGb;

  @override
  Widget build(BuildContext context) {
    final label = thresholdGb > 0
        ? '提醒线 ${thresholdGb.toStringAsFixed(thresholdGb % 1 == 0 ? 0 : 1)} GB'
        : '可在提醒设置中调整阈值';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6ED),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            size: 15,
            color: Color(0xFFAA7259),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF775C50),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarrierCard extends StatelessWidget {
  const _CarrierCard({
    required this.carrier,
    required this.slotLabel,
    required this.snapshot,
    required this.accent,
    required this.onConnect,
    required this.onRefresh,
  });

  final Carrier carrier;
  final String slotLabel;
  final CarrierSnapshot? snapshot;
  final Color accent;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = snapshot?.status ?? QueryStatus.notConnected;
    final trafficSummary = snapshot == null
        ? null
        : summarizeTraffic(snapshot!);
    final remainingBytes = trafficSummary?.remainingBytes;
    final totalBytes = trafficSummary?.totalBytes;
    final detailNotice = trafficSummary?.detailNotice;
    final isBusy = status == QueryStatus.loading;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFF1ECE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A54462E),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.sim_card_rounded, color: accent, size: 24),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            carrier.label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF303845),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _SlotTag(label: slotLabel, accent: accent),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      snapshot?.phoneMasked ?? _statusSubtitle(status),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A8E95),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF7),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trafficSummary?.label ??
                                (carrier == Carrier.broadnet &&
                                        status == QueryStatus.success
                                    ? '余额待确认'
                                    : '通用剩余'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF777D87),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (remainingBytes != null)
                            _BigUsageValue(bytes: remainingBytes)
                          else
                            Text(
                              '--',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF424B5A),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (totalBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '共 ${_formatGb(totalBytes)} GB',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A8E95),
                          ),
                        ),
                      ),
                  ],
                ),
                if (remainingBytes != null &&
                    totalBytes != null &&
                    totalBytes > 0) ...[
                  const SizedBox(height: 11),
                  _RemainingBar(
                    ratio: (remainingBytes / totalBytes).clamp(0.0, 1.0),
                    color: accent,
                  ),
                ],
                const SizedBox(height: 9),
                _DataFootnote(snapshot: snapshot, status: status),
                if (detailNotice != null && detailNotice.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    detailNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF92765F),
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (remainingBytes == null && status == QueryStatus.notConnected) ...[
            const SizedBox(height: 9),
            const Text(
              '连接后查看',
              style: TextStyle(color: Color(0xFF8A8E95), fontSize: 12),
            ),
          ],
          if (_detailBuckets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TrafficBucketList(buckets: _detailBuckets, accent: accent),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onConnect,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: .12),
                    foregroundColor: accent,
                    minimumSize: const Size(0, 43),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  icon: Icon(
                    status == QueryStatus.authExpired
                        ? Icons.login_rounded
                        : Icons.link_rounded,
                    size: 17,
                  ),
                  label: Text(
                    status == QueryStatus.authExpired ? '重新连接' : '连接号码',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                height: 43,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onRefresh,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF656D79),
                    side: const BorderSide(color: Color(0xFFECE7E0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  icon: isBusy
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('刷新'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<TrafficBucket> get _detailBuckets {
    return snapshot?.buckets
            .where(
              (bucket) =>
                  bucket.kind != BucketKind.general ||
                  bucket.remainingBytes == null,
            )
            .toList(growable: false) ??
        const [];
  }

  String _statusSubtitle(QueryStatus status) {
    switch (status) {
      case QueryStatus.notConnected:
        return '尚未连接';
      case QueryStatus.loading:
        return '正在同步';
      case QueryStatus.success:
        return '号码已连接';
      case QueryStatus.authExpired:
        return '需要重新登录';
      case QueryStatus.error:
        return '查询遇到问题';
    }
  }
}

class _BigUsageValue extends StatelessWidget {
  const _BigUsageValue({required this.bytes});

  final int bytes;

  @override
  Widget build(BuildContext context) {
    final value = _formatGb(bytes);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF303845),
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              height: 1,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 5, bottom: 2),
          child: Text(
            'GB',
            style: TextStyle(
              color: Color(0xFF777D87),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DataFootnote extends StatelessWidget {
  const _DataFootnote({required this.snapshot, required this.status});

  final CarrierSnapshot? snapshot;
  final QueryStatus status;

  @override
  Widget build(BuildContext context) {
    final hasCached = snapshot?.buckets.isNotEmpty ?? false;
    final queriedAt = snapshot?.queriedAt;
    final color = const Color(0xFF8A8E95);
    String text;

    switch (status) {
      case QueryStatus.success:
        text = '来源：运营商查询 · ${_formatQueryTime(queriedAt)}';
      case QueryStatus.loading:
        text = hasCached
            ? '正在刷新 · 显示上次查询 · ${_formatQueryTime(queriedAt)}'
            : '正在向运营商查询';
      case QueryStatus.authExpired:
        text = hasCached
            ? '登录已过期 · 以下为上次查询 · ${_formatQueryTime(queriedAt)}'
            : '登录已过期 · 重新连接后查询';
      case QueryStatus.error:
        final message = snapshot?.message;
        text = hasCached
            ? '查询失败 · 显示上次查询 · ${_formatQueryTime(queriedAt)}'
            : (message?.trim().isNotEmpty ?? false)
            ? message!.trim()
            : '查询失败 · 请检查连接后重试';
      case QueryStatus.notConnected:
        text = '来源：运营商查询 · 尚未连接';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          status == QueryStatus.success
              ? Icons.verified_outlined
              : Icons.info_outline_rounded,
          size: 14,
          color: status == QueryStatus.success
              ? const Color(0xFF70A58A)
              : color,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 10.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _TrafficBucketList extends StatefulWidget {
  const _TrafficBucketList({required this.buckets, required this.accent});

  final List<TrafficBucket> buckets;
  final Color accent;

  @override
  State<_TrafficBucketList> createState() => _TrafficBucketListState();
}

class _TrafficBucketListState extends State<_TrafficBucketList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleBuckets = _expanded
        ? widget.buckets
        : widget.buckets.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bucket in visibleBuckets)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _TrafficBucketRow(bucket: bucket, accent: widget.accent),
          ),
        if (widget.buckets.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: widget.accent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 17,
              ),
              label: Text(
                _expanded ? '收起套餐明细' : '查看全部 ${widget.buckets.length} 项',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrafficBucketRow extends StatelessWidget {
  const _TrafficBucketRow({required this.bucket, required this.accent});

  final TrafficBucket bucket;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bucketLabel = _bucketName(bucket);
    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: '查看 $bucketLabel 的完整套餐名称和余额详情',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showBucketDetails(context, bucket),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    bucketLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF717783),
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _bucketRemainingText(bucket),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFF4C5563),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFF9AA1AA),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _bucketName(TrafficBucket bucket) {
  if (bucket.name.isNotEmpty) return bucket.name;
  return bucket.kind == BucketKind.directed ? '定向流量' : '流量项';
}

String _bucketRemainingText(TrafficBucket bucket) {
  final remaining = bucket.remainingBytes;
  if (remaining != null) return '${_formatGb(remaining)} GB';
  final rawRemaining = bucket.rawRemaining?.trim();
  if (rawRemaining == null || rawRemaining.isEmpty) return '--';
  final rawUnit = bucket.rawUnit?.trim();
  if (rawUnit == null || rawUnit.isEmpty) {
    return '$rawRemaining（单位待确认）';
  }
  return '$rawRemaining $rawUnit';
}

String _bucketTotalText(TrafficBucket bucket) {
  final total = bucket.totalBytes;
  if (total == null) return '未提供可确认的套餐总量';
  return '${_formatGb(total)} GB';
}

void _showBucketDetails(BuildContext context, TrafficBucket bucket) {
  final name = _bucketName(bucket);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(name),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _BucketDetailValue(
              label: '剩余流量',
              value: _bucketRemainingText(bucket),
            ),
            const SizedBox(height: 12),
            _BucketDetailValue(label: '套餐总量', value: _bucketTotalText(bucket)),
            if (bucket.remainingBytes == null) ...[
              const SizedBox(height: 12),
              const Text(
                '此项余额或单位尚未确认，请对照官方页面。',
                style: TextStyle(color: Color(0xFF777D87), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

class _BucketDetailValue extends StatelessWidget {
  const _BucketDetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF777D87)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF303845),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingBar extends StatelessWidget {
  const _RemainingBar({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        color: color,
        backgroundColor: color.withValues(alpha: .12),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final QueryStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color foreground;
    late final Color background;
    switch (status) {
      case QueryStatus.notConnected:
        label = '未连接';
        foreground = const Color(0xFF797F89);
        background = const Color(0xFFF2F1EF);
      case QueryStatus.loading:
        label = '查询中';
        foreground = const Color(0xFF4D78BB);
        background = const Color(0xFFEAF1FB);
      case QueryStatus.success:
        label = '已同步';
        foreground = const Color(0xFF53866D);
        background = const Color(0xFFE9F4EC);
      case QueryStatus.authExpired:
        label = '待登录';
        foreground = const Color(0xFFAB7657);
        background = const Color(0xFFFFF0E4);
      case QueryStatus.error:
        label = '待检查';
        foreground = const Color(0xFFAE6B62);
        background = const Color(0xFFFFECE9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SlotTag extends StatelessWidget {
  const _SlotTag({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFFFFDF9),
        foregroundColor: const Color(0xFF667080),
        side: const BorderSide(color: Color(0xFFF0EAE2)),
        minimumSize: const Size(0, 47),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _MiniCarrierDot extends StatelessWidget {
  const _MiniCarrierDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CloudDropPainter extends CustomPainter {
  const _CloudDropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final softCloud = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .34);
    final lightDrop = Paint()
      ..color = const Color(0xFFEEA489).withValues(alpha: .34);
    final dropHighlight = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .48);

    final cloud = Path()
      ..moveTo(size.width * .21, size.height * .18)
      ..cubicTo(
        size.width * .21,
        size.height * .08,
        size.width * .38,
        size.height * .04,
        size.width * .46,
        size.height * .13,
      )
      ..cubicTo(
        size.width * .54,
        size.height * .04,
        size.width * .71,
        size.height * .09,
        size.width * .72,
        size.height * .20,
      )
      ..cubicTo(
        size.width * .86,
        size.height * .20,
        size.width * .89,
        size.height * .39,
        size.width * .74,
        size.height * .42,
      )
      ..lineTo(size.width * .25, size.height * .42)
      ..cubicTo(
        size.width * .11,
        size.height * .40,
        size.width * .10,
        size.height * .21,
        size.width * .21,
        size.height * .18,
      )
      ..close();
    canvas.drawPath(cloud, softCloud);

    final drop = Path()
      ..moveTo(size.width * .60, size.height * .43)
      ..cubicTo(
        size.width * .55,
        size.height * .54,
        size.width * .43,
        size.height * .67,
        size.width * .43,
        size.height * .78,
      )
      ..cubicTo(
        size.width * .43,
        size.height * .93,
        size.width * .72,
        size.height * .95,
        size.width * .72,
        size.height * .78,
      )
      ..cubicTo(
        size.width * .72,
        size.height * .66,
        size.width * .65,
        size.height * .54,
        size.width * .60,
        size.height * .43,
      )
      ..close();
    canvas.drawPath(drop, lightDrop);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .54, size.height * .68),
        width: size.width * .045,
        height: size.height * .13,
      ),
      dropHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant _CloudDropPainter oldDelegate) => false;
}

class _CuteDropMarkPainter extends CustomPainter {
  const _CuteDropMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dropPaint = Paint()..color = const Color(0xFFE58C79);
    final facePaint = Paint()..color = const Color(0xFFFFF7F0);
    final drop = Path()
      ..moveTo(size.width * .5, size.height * .03)
      ..cubicTo(
        size.width * .43,
        size.height * .18,
        size.width * .17,
        size.height * .47,
        size.width * .17,
        size.height * .66,
      )
      ..cubicTo(
        size.width * .17,
        size.height * .89,
        size.width * .34,
        size.height * .99,
        size.width * .5,
        size.height * .99,
      )
      ..cubicTo(
        size.width * .68,
        size.height * .99,
        size.width * .84,
        size.height * .87,
        size.width * .84,
        size.height * .66,
      )
      ..cubicTo(
        size.width * .84,
        size.height * .45,
        size.width * .58,
        size.height * .17,
        size.width * .5,
        size.height * .03,
      )
      ..close();
    canvas.drawPath(drop, dropPaint);
    canvas.drawCircle(
      Offset(size.width * .4, size.height * .58),
      1.65,
      facePaint,
    );
    canvas.drawCircle(
      Offset(size.width * .6, size.height * .58),
      1.65,
      facePaint,
    );
    final smile = Path()
      ..moveTo(size.width * .4, size.height * .7)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .78,
        size.width * .6,
        size.height * .7,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = facePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(size.width * .34, size.height * .34),
      1.4,
      Paint()..color = const Color(0xFFFFDCCB),
    );
  }

  @override
  bool shouldRepaint(covariant _CuteDropMarkPainter oldDelegate) => false;
}

String _formatGb(int bytes) {
  final value = bytes / (1024 * 1024 * 1024);
  return value < 100 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
}

String _formatQueryTime(DateTime? dateTime) {
  if (dateTime == null) return '时间暂不可用';
  final local = dateTime.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
