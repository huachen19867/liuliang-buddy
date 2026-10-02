import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/carrier_accounts.dart';
import '../data/traffic_summary.dart';
import 'widget_preview_card.dart';
import 'resort_theme.dart';

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
    this.selectedCarriers,
    this.accountEntries,
    this.cleanupPending = false,
    this.onConnectAccount,
    this.onRefreshAccount,
    this.onEditAccount,
    this.onManageCarriers,
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
  final Set<Carrier>? selectedCarriers;
  final List<DashboardAccountEntry>? accountEntries;
  final bool cleanupPending;
  final ValueChanged<String>? onConnectAccount;
  final ValueChanged<String>? onRefreshAccount;
  final ValueChanged<String>? onEditAccount;
  final VoidCallback? onManageCarriers;
  final VoidCallback? onAddWidget;
  final bool widgetSupported;
  final bool demo;

  static const _mutedInk = ResortPalette.muted;
  static const _canvas = ResortPalette.canvas;
  static const _mobileBlue = Color(0xFF4E83D9);
  static const _broadnetPeach = Color(0xFFE58C79);
  static const _carrierPalette = <Color>[
    _mobileBlue,
    _broadnetPeach,
    Color(0xFF63A68C),
    Color(0xFF8B7AC7),
  ];

  @override
  Widget build(BuildContext context) {
    final chosen = selectedCarriers ?? snapshots.map((s) => s.carrier).toSet();
    final carriers = Carrier.values
        .where(chosen.contains)
        .toList(growable: false);
    final entries = accountEntries == null
        ? [
            for (final carrier in carriers)
              _DashboardCarrier(
                accountId: carrier.name,
                carrier: carrier,
                slotLabel: _carrierCardLabel(carrier),
                balanceYuan: _snapshotFor(carrier)?.balanceYuan,
                snapshot: _snapshotFor(carrier),
                accent: _carrierPalette[carrier.index % _carrierPalette.length],
              ),
          ]
        : [
            for (final entry in accountEntries!)
              _DashboardCarrier(
                accountId: entry.account.id,
                carrier: entry.account.carrier,
                slotLabel: entry.account.displayName,
                phoneHint: entry.account.phoneHint,
                balanceYuan: entry.snapshot?.balanceYuan,
                snapshot: entry.snapshot,
                accent:
                    _carrierPalette[entry.account.carrier.index %
                        _carrierPalette.length],
              ),
          ];
    final theme = Theme.of(context);
    final compact = entries.length >= 3;

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(carriers, compact: compact),
                  if (cleanupPending) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: ResortPalette.mintWash,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ResortPalette.border),
                      ),
                      child: const Text(
                        '本地登录资料还没清理完。请到提醒设置重试清除，完成前已暂停所有号码查询。',
                        style: TextStyle(
                          color: Color(0xFF765B50),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  if (demo) ...[
                    const SizedBox(height: 15),
                    const _DemoNotice(),
                  ],
                  const SizedBox(height: 18),
                  _SummaryCard(
                    entries: entries,
                    thresholdGb: thresholdGb,
                    onRefreshAll: onRefreshAll,
                  ),
                  if (compact)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${entries.length} 个号码 · 可分别查询',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _mutedInk,
                        ),
                      ),
                    ),
                  for (var index = 0; index < entries.length; index++) ...[
                    SizedBox(
                      height: compact
                          ? 10
                          : index == 0
                          ? 18
                          : 13,
                    ),
                    _CarrierCard(
                      key: ValueKey('account-card-${entries[index].accountId}'),
                      accountId: entries[index].accountId,
                      compact: compact,
                      carrier: entries[index].carrier,
                      slotLabel: entries[index].slotLabel,
                      phoneHint:
                          entries[index].phoneHint ??
                          _safeMaskedPhone(
                            entries[index].snapshot?.phoneMasked,
                          ),
                      balanceYuan: entries[index].balanceYuan,
                      snapshot: entries[index].snapshot,
                      accent: entries[index].accent,
                      onEdit: onEditAccount == null
                          ? null
                          : () => onEditAccount!(entries[index].accountId),
                      onConnect: () => onConnectAccount == null
                          ? onConnect(entries[index].carrier)
                          : onConnectAccount!(entries[index].accountId),
                      onRefresh: () => onRefreshAccount == null
                          ? onRefresh(entries[index].carrier)
                          : onRefreshAccount!(entries[index].accountId),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (onManageCarriers != null) ...[
                    _FooterAction(
                      icon: Icons.tune_rounded,
                      label: '运营商设置',
                      onTap: onManageCarriers!,
                    ),
                    const SizedBox(height: 10),
                  ],
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
                    selectedCarriers: entries.map((e) => e.carrier).toList(),
                    selectedAccountLabels: accountEntries
                        ?.map((e) => e.account.displayName)
                        .toList(),
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

  Widget _buildHeader(List<Carrier> carriers, {bool compact = false}) {
    final carrierCaption = carriers.isEmpty
        ? '先选择运营商'
        : carriers.length == 1
        ? '${carriers.single.label}的流量，清楚一点'
        : '多家运营商的流量，清楚一点';
    if (compact) {
      return ResortPaper(
        color: ResortPalette.mintWash,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '流量小伙伴',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ResortPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    carrierCaption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ResortPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 64,
              height: 64,
              child: ResortMascotSticker(message: '查询一下，今天也安心出发。'),
            ),
          ],
        ),
      );
    }
    return ResortMiniScene(
      title: '流量小伙伴',
      subtitle: carrierCaption,
      eyebrow: '海滨温泉 · 余量小站',
      mascotMessage: '查询一下，今天也安心出发。',
      height: 118,
    );
  }

  CarrierSnapshot? _snapshotFor(Carrier carrier) {
    for (final snapshot in snapshots) {
      if (snapshot.carrier == carrier) return snapshot;
    }
    return null;
  }
}

class _DashboardCarrier {
  const _DashboardCarrier({
    required this.accountId,
    required this.carrier,
    required this.slotLabel,
    this.phoneHint,
    this.balanceYuan,
    required this.snapshot,
    required this.accent,
  });

  final String accountId;
  final Carrier carrier;
  final String slotLabel;
  final String? phoneHint;
  final num? balanceYuan;
  final CarrierSnapshot? snapshot;
  final Color accent;
}

String? _safeMaskedPhone(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  if (RegExp(r'^\d{1,4}\*{2,}\d{2,4}$').hasMatch(text)) return text;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return null;
  final prefixLength = digits.length >= 10 ? 3 : 1;
  return '${digits.substring(0, prefixLength)}****${digits.substring(digits.length - 4)}';
}

class DashboardAccountEntry {
  const DashboardAccountEntry(this.account, this.snapshot);

  final CarrierAccount account;
  final CarrierSnapshot? snapshot;
}

String _carrierCardLabel(Carrier carrier) {
  final name = carrier.label.startsWith('中国')
      ? carrier.label.substring('中国'.length)
      : carrier.label;
  return '$name卡';
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2D4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEEDCA7)),
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
    required this.entries,
    required this.thresholdGb,
    required this.onRefreshAll,
  });

  final List<_DashboardCarrier> entries;
  final double thresholdGb;
  final VoidCallback onRefreshAll;

  @override
  Widget build(BuildContext context) {
    final hasGeneralTotal =
        entries.isNotEmpty &&
        entries.every(
          (entry) =>
              entry.snapshot?.status == QueryStatus.success &&
              entry.snapshot?.generalRemainingBytes != null,
        );
    final single = entries.length == 1 ? entries.single : null;
    final singleSummary =
        single?.snapshot == null ||
            single?.snapshot?.status != QueryStatus.success
        ? null
        : summarizeTraffic(single!.snapshot!);
    final hasSinglePackageTotal = singleSummary?.label == '套餐明细合计';
    final hasSingleEstimate = singleSummary?.isEstimate == true;
    final hasSingleBalance = hasSinglePackageTotal || hasSingleEstimate;
    final singleMessage = single?.snapshot?.message?.trim();
    final singleStatusMessage =
        single != null &&
            single.snapshot?.status != QueryStatus.success &&
            (singleMessage?.isNotEmpty ?? false)
        ? singleMessage
        : null;
    final hasRecords = entries.any(
      (entry) =>
          entry.snapshot?.queriedAt != null &&
          entry.snapshot!.buckets.isNotEmpty,
    );
    final bytes = hasGeneralTotal
        ? entries.fold<int>(
            0,
            (sum, entry) => sum + entry.snapshot!.generalRemainingBytes!,
          )
        : hasSingleBalance
        ? singleSummary!.remainingBytes
        : 0;
    final showAmount = hasGeneralTotal || hasSingleBalance;
    final hasUnlimited = entries.any(
      (entry) =>
          entry.snapshot?.status == QueryStatus.success &&
          entry.snapshot?.hasUnlimitedAllowance == true,
    );
    final headline = hasGeneralTotal
        ? '通用流量总览'
        : hasSingleBalance
        ? singleSummary!.label
        : hasUnlimited
        ? '含不限量套餐'
        : entries.isEmpty
        ? '尚未选择运营商'
        : entries.length == 1
        ? '${entries.single.carrier.label}的流量'
        : '所选运营商，一眼看清';
    final explanation = hasGeneralTotal
        ? entries.length == 1
              ? '${entries.single.carrier.label}的通用流量剩余'
              : '所选运营商的通用流量剩余合计'
        : hasSingleBalance
        ? singleSummary!.detailNotice ?? '已查询套餐余额'
        : hasUnlimited
        ? '官网标注不限量，达量后的使用规则请查看下方套餐说明。'
        : singleStatusMessage ??
              (entries.isEmpty
                  ? '选择至少一家运营商后，这里会显示对应流量。'
                  : hasRecords
                  ? '余额见下方，完整的通用流量合计待确认。'
                  : '连接已选择的运营商账号后，流量会显示在这里。');
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EF),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFD6E6DC), width: 1.15),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ResortPalette.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: entries.isEmpty ? null : onRefreshAll,
                  style: TextButton.styleFrom(
                    foregroundColor: ResortPalette.mint,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 17),
                  label: const Text('刷新所选'),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (showAmount) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasSingleEstimate)
                    const Padding(
                      padding: EdgeInsets.only(right: 3, bottom: 3),
                      child: Text(
                        '约',
                        style: TextStyle(
                          color: ResortPalette.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    _formatGb(bytes),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: ResortPalette.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      'GB',
                      style: TextStyle(
                        color: ResortPalette.muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        explanation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ResortPalette.muted,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasGeneralTotal) ...[
                const SizedBox(height: 7),
                _ThresholdHint(thresholdGb: thresholdGb),
              ],
              if (hasSinglePackageTotal) ...[
                const SizedBox(height: 5),
                const _SummaryScopeNote(),
              ],
            ] else ...[
              Text(
                explanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ResortPalette.muted,
                  height: 1.3,
                ),
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 13,
                  runSpacing: 5,
                  children: [
                    for (final entry in entries)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MiniCarrierDot(color: entry.accent),
                          const SizedBox(width: 6),
                          Text(
                            entry.slotLabel,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryScopeNote extends StatelessWidget {
  const _SummaryScopeNote();

  @override
  Widget build(BuildContext context) => const Text(
    '适用范围以各套餐规则为准',
    style: TextStyle(
      color: Color(0xFF71645D),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );
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
    super.key,
    required this.accountId,
    this.compact = false,
    required this.carrier,
    required this.slotLabel,
    required this.phoneHint,
    required this.balanceYuan,
    required this.snapshot,
    required this.accent,
    required this.onEdit,
    required this.onConnect,
    required this.onRefresh,
  });

  final Carrier carrier;
  final String accountId;
  final bool compact;
  final String slotLabel;
  final String? phoneHint;
  final num? balanceYuan;
  final CarrierSnapshot? snapshot;
  final Color accent;
  final VoidCallback? onEdit;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = snapshot?.status ?? QueryStatus.notConnected;
    final trafficSummary = snapshot == null
        ? null
        : summarizeTraffic(snapshot!);
    final singleUnknownBucket = snapshot?.buckets.length == 1
        ? snapshot!.buckets.single
        : null;
    final canShowUnknownBucket =
        carrier != Carrier.mobile &&
        singleUnknownBucket?.kind == BucketKind.unknown &&
        singleUnknownBucket?.remainingBytes != null &&
        (singleUnknownBucket?.rawUnit?.trim().isNotEmpty ?? false);
    final remainingBytes =
        trafficSummary?.remainingBytes ??
        (canShowUnknownBucket ? singleUnknownBucket!.remainingBytes : null);
    final totalBytes =
        trafficSummary?.totalBytes ??
        (canShowUnknownBucket ? singleUnknownBucket!.totalBytes : null);
    final remainingLabel =
        trafficSummary?.label ??
        (canShowUnknownBucket
            ? '套餐余量'
            : status == QueryStatus.success &&
                  snapshot?.hasUnlimitedAllowance == true
            ? '套餐标注'
            : status == QueryStatus.success
            ? '余额待确认'
            : '流量余量');
    final partialEstimateNotice =
        status == QueryStatus.success &&
            carrier == Carrier.telecom &&
            trafficSummary == null
        ? snapshot?.message?.trim()
        : null;
    final detailNotice =
        trafficSummary?.detailNotice ??
        (status == QueryStatus.success &&
                snapshot?.hasUnlimitedAllowance == true
            ? snapshot?.message?.trim()
            : null) ??
        ((partialEstimateNotice?.isNotEmpty ?? false)
            ? partialEstimateNotice
            : null);
    final isBusy = status == QueryStatus.loading;
    final theme = Theme.of(context);

    return ResortPaper(
      ticketNotches: true,
      padding: EdgeInsets.all(compact ? 11 : 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ResortCarrierMark(carrier: carrier),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            carrier.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: ResortPalette.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _SlotTag(label: slotLabel, accent: accent),
                        Text(
                          phoneHint ?? '号码未备注',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ResortPalette.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: status),
                  if (onEdit != null) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 48,
                      height: 42,
                      child: IconButton(
                        tooltip: '编辑备注与号码',
                        onPressed: onEdit,
                        style: IconButton.styleFrom(
                          foregroundColor: ResortPalette.lavender,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 42),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 21),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: compact ? 9 : 15),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF4E6E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: ResortPalette.pink,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '话费余额',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ResortPalette.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      balanceYuan == null
                          ? '--'
                          : '¥${balanceYuan!.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ResortPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            remainingLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ResortPalette.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (remainingBytes != null)
                            _BigUsageValue(
                              bytes: remainingBytes,
                              isEstimate: trafficSummary?.isEstimate ?? false,
                            )
                          else if (snapshot?.status == QueryStatus.success &&
                              snapshot?.hasUnlimitedAllowance == true)
                            Text(
                              '不限量',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: ResortPalette.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            Text(
                              '--',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: ResortPalette.ink,
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
                            color: ResortPalette.muted,
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
          const SizedBox(height: 9),
          _TrafficCategoryRow(snapshot: snapshot, status: status),
          if (remainingBytes == null && status == QueryStatus.notConnected) ...[
            const SizedBox(height: 9),
            const Text(
              '连接后查看',
              style: TextStyle(color: Color(0xFF8A8E95), fontSize: 12),
            ),
          ],
          if (compact)
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                key: ValueKey('account-details-$accountId'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('套餐与通话明细', style: TextStyle(fontSize: 12)),
                children: [
                  _ServiceAllowances(snapshot: snapshot, status: status),
                  if (_detailBuckets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TrafficBucketList(
                      buckets: _detailBuckets,
                      accent: accent,
                      estimated: carrier == Carrier.telecom,
                    ),
                  ],
                ],
              ),
            )
          else ...[
            const SizedBox(height: 12),
            _ServiceAllowances(snapshot: snapshot, status: status),
            if (_detailBuckets.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TrafficBucketList(
                buckets: _detailBuckets,
                accent: accent,
                estimated: carrier == Carrier.telecom,
              ),
            ],
          ],
          SizedBox(height: compact ? 6 : 13),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onConnect,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: .13),
                    foregroundColor: accent,
                    minimumSize: const Size(0, 48),
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
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onRefresh,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ResortPalette.ink,
                    side: const BorderSide(color: ResortPalette.border),
                    minimumSize: const Size(0, 48),
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
}

class _TrafficCategoryRow extends StatelessWidget {
  const _TrafficCategoryRow({required this.snapshot, required this.status});

  final CarrierSnapshot? snapshot;
  final QueryStatus status;

  @override
  Widget build(BuildContext context) {
    final categories = <(String, BucketKind, Color, Color)>[
      ('通用流量', BucketKind.general, ResortPalette.mint, ResortPalette.mintWash),
      (
        '定向流量',
        BucketKind.directed,
        ResortPalette.lavender,
        ResortPalette.lavenderWash,
      ),
      ('其他流量', BucketKind.unknown, ResortPalette.pink, ResortPalette.pinkWash),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(12);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 270 || scale > 16;
        final itemWidth = compact
            ? (constraints.maxWidth - 7) / 2
            : (constraints.maxWidth - 14) / 3;
        return Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final (label, kind, color, wash) in categories)
              SizedBox(
                width: itemWidth,
                child: _TrafficCategoryChip(
                  label: label,
                  kind: kind,
                  color: color,
                  wash: wash,
                  snapshot: snapshot,
                  status: status,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrafficCategoryChip extends StatelessWidget {
  const _TrafficCategoryChip({
    required this.label,
    required this.kind,
    required this.color,
    required this.wash,
    required this.snapshot,
    required this.status,
  });

  final String label;
  final BucketKind kind;
  final Color color;
  final Color wash;
  final CarrierSnapshot? snapshot;
  final QueryStatus status;

  @override
  Widget build(BuildContext context) {
    final group = snapshot == null
        ? const TrafficGroupSummary()
        : summarizeTrafficGroup(snapshot!, kind);
    final unknownPurpose = kind == BucketKind.unknown;
    final value = group.isUnlimited
        ? unknownPurpose
              ? '不限量 · 用途待确认'
              : '不限量'
        : group.isComplete && group.remainingBytes != null
        ? '${group.isEstimated ? '约 ' : ''}${_formatGb(group.remainingBytes!)} GB${unknownPurpose ? ' · 用途待确认' : ''}'
        : status == QueryStatus.notConnected
        ? '待连接'
        : unknownPurpose
        ? '用途待确认'
        : '待确认';
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: .95),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ResortPalette.ink,
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceAllowances extends StatelessWidget {
  const _ServiceAllowances({required this.snapshot, required this.status});

  final CarrierSnapshot? snapshot;
  final QueryStatus status;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _tile(context, AllowanceKind.voice),
      _tile(context, AllowanceKind.sms),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(12) > 15) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tiles[0], const SizedBox(height: 8), tiles[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 8),
            Expanded(child: tiles[1]),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, AllowanceKind kind) {
    final voice = kind == AllowanceKind.voice;
    final items =
        snapshot?.allowances.where((item) => item.kind == kind).toList() ??
        const <ServiceAllowance>[];
    final ink = voice ? const Color(0xFF547F76) : const Color(0xFF857297);
    final hasMms = items.any((item) => item.label.contains('彩信'));
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: voice ? const Color(0xFFF0F8F4) : const Color(0xFFF7F2FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                voice ? Icons.phone_rounded : Icons.chat_bubble_outline_rounded,
                size: 15,
                color: ink,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  voice
                      ? '通话余量'
                      : hasMms
                      ? '短信 / 彩信余量'
                      : '短信余量',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (items.isEmpty)
            Text(
              status == QueryStatus.notConnected ? '等待连接' : '余量待确认',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7D838C)),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const Divider(height: 17),
              Text(
                items[index].label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF707580)),
              ),
              const SizedBox(height: 3),
              Text(
                items[index].overage != null
                    ? '${items[index].isEstimated ? '约超出' : '超出'} ${_number(items[index].overage!)} ${items[index].canonicalUnit}'
                    : items[index].isUnlimited
                    ? '不限量'
                    : items[index].remaining == null
                    ? '剩余待确认'
                    : '${items[index].isEstimated ? '约剩余' : '剩余'} ${_number(items[index].remaining!)} ${items[index].canonicalUnit}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              if (items[index].total != null)
                Text(
                  '共 ${_number(items[index].total!)} ${items[index].canonicalUnit}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF858A92),
                  ),
                ),
              if (items[index].scope?.trim().isNotEmpty ?? false)
                Text(
                  items[index].scope!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF858A92),
                  ),
                ),
              if (items[index].remaining == null &&
                  items[index].overage == null &&
                  !items[index].isUnlimited &&
                  items[index].rawUnit?.trim().isNotEmpty == true &&
                  items[index].rawUnit != items[index].canonicalUnit)
                Text(
                  '官网单位：${items[index].rawUnit}，暂未换算',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF858A92),
                  ),
                ),
            ],
        ],
      ),
    );
  }

  String _number(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
}

class _BigUsageValue extends StatelessWidget {
  const _BigUsageValue({required this.bytes, this.isEstimate = false});

  final int bytes;
  final bool isEstimate;

  @override
  Widget build(BuildContext context) {
    final value = _formatGb(bytes);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isEstimate)
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 2),
            child: Text(
              '约',
              style: TextStyle(
                color: Color(0xFF777D87),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
    final hasCached =
        snapshot != null &&
        (snapshot!.buckets.isNotEmpty ||
            snapshot!.allowances.isNotEmpty ||
            snapshot!.hasUnlimitedAllowance);
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
        final message = snapshot?.message?.trim();
        text = hasCached
            ? '查询失败${(message?.isNotEmpty ?? false) ? ' · $message' : ''} · 显示上次查询 · ${_formatQueryTime(queriedAt)}'
            : (message?.isNotEmpty ?? false)
            ? message!
            : '查询失败 · 请检查连接后重试';
      case QueryStatus.notConnected:
        final message = snapshot?.message?.trim();
        text = (message?.isNotEmpty ?? false) ? message! : '来源：运营商查询 · 尚未连接';
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
  const _TrafficBucketList({
    required this.buckets,
    required this.accent,
    required this.estimated,
  });

  final List<TrafficBucket> buckets;
  final Color accent;
  final bool estimated;

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
            child: _TrafficBucketRow(
              bucket: bucket,
              accent: widget.accent,
              estimated: widget.estimated,
            ),
          ),
        if (widget.buckets.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: widget.accent,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 6),
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
  const _TrafficBucketRow({
    required this.bucket,
    required this.accent,
    required this.estimated,
  });

  final TrafficBucket bucket;
  final Color accent;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    final bucketLabel = _bucketName(bucket);
    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: '查看 $bucketLabel 的完整套餐名称和${estimated ? '估算余额' : '余额'}详情',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () =>
              _showBucketDetails(context, bucket, estimated: estimated),
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
                    _bucketRemainingText(bucket, estimated: estimated),
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

String _bucketRemainingText(TrafficBucket bucket, {bool estimated = false}) {
  final remaining = bucket.remainingBytes;
  if (bucket.isUnlimited) return '不限量';
  if (remaining != null) {
    return '${estimated ? '约 ' : ''}${_formatGb(remaining)} GB';
  }
  final rawRemaining = bucket.rawRemaining?.trim();
  if (rawRemaining == null || rawRemaining.isEmpty) return '--';
  final rawUnit = bucket.rawUnit?.trim();
  if (rawUnit == null || rawUnit.isEmpty) {
    return '$rawRemaining（单位待确认）';
  }
  return '$rawRemaining $rawUnit';
}

String _bucketTotalText(TrafficBucket bucket) {
  if (bucket.isUnlimited) return '不限量套餐（以官网规则为准）';
  final total = bucket.totalBytes;
  if (total == null) return '未提供可确认的套餐总量';
  return '${_formatGb(total)} GB';
}

void _showBucketDetails(
  BuildContext context,
  TrafficBucket bucket, {
  bool estimated = false,
}) {
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
              label: estimated ? '剩余流量（估算）' : '剩余流量',
              value: _bucketRemainingText(bucket, estimated: estimated),
            ),
            const SizedBox(height: 12),
            _BucketDetailValue(label: '套餐总量', value: _bucketTotalText(bucket)),
            if (estimated) ...[
              const SizedBox(height: 12),
              const Text(
                '剩余值按官网已用量与总量的显示值估算，可能有舍入差异；套餐适用范围以官网规则为准。',
                style: TextStyle(color: Color(0xFF777D87), fontSize: 12),
              ),
            ],
            if (bucket.isUnlimited) ...[
              const SizedBox(height: 12),
              const Text(
                '官网标注不限量；达量后可能限速，具体规则以官网为准。',
                style: TextStyle(color: Color(0xFF777D87), fontSize: 12),
              ),
            ] else if (bucket.remainingBytes == null && estimated) ...[
              const SizedBox(height: 8),
              const Text(
                '此项已用量或总量无法确认，因此不展示估算余额。',
                style: TextStyle(color: Color(0xFF777D87), fontSize: 12),
              ),
            ] else if (bucket.remainingBytes == null) ...[
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
        backgroundColor: ResortPalette.paper,
        foregroundColor: ResortPalette.mint,
        side: const BorderSide(color: ResortPalette.border),
        minimumSize: const Size(0, 48),
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
