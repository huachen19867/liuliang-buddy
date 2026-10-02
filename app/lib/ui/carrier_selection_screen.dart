import 'package:flutter/material.dart';

import '../data/models.dart';
import 'resort_theme.dart';

/// Lets the user choose which supported carriers the app should show.
///
/// The selectable list follows the carrier enum by default. Query support is
/// declared separately so a provider can be selectable while its balance
/// reader is still being integrated. Labels come from [Carrier.label], so this
/// screen does not need carrier-specific branches when the enum grows.
class CarrierSelectionScreen extends StatelessWidget {
  const CarrierSelectionScreen({
    super.key,
    this.availableCarriers = Carrier.values,
    this.querySupportedCarriers = Carrier.values,
    this.accountCounts = const {},
    this.onAddSecondAccount,
    this.onAccountCountsChanged,
    required this.selectedCarriers,
    required this.onSelectionChanged,
    required this.onContinue,
    this.isInitialSetup = true,
    this.demo = false,
  });

  final List<Carrier> availableCarriers;
  final List<Carrier> querySupportedCarriers;
  final Map<Carrier, int> accountCounts;
  final ValueChanged<Carrier>? onAddSecondAccount;
  final ValueChanged<Map<Carrier, int>>? onAccountCountsChanged;
  final Set<Carrier> selectedCarriers;
  final ValueChanged<Set<Carrier>> onSelectionChanged;
  final ValueChanged<Set<Carrier>> onContinue;
  final bool isInitialSetup;
  final bool demo;

  static const _ink = ResortPalette.ink;
  static const _mutedInk = ResortPalette.muted;
  static const _canvas = ResortPalette.canvas;
  static const _palette = <Color>[
    Color(0xFF4E83D9),
    Color(0xFFE58C79),
    Color(0xFF63A68C),
    Color(0xFF8B7AC7),
  ];

  @override
  Widget build(BuildContext context) {
    final carriers = availableCarriers.toSet().toList(growable: false);
    final selected = selectedCarriers.intersection(carriers.toSet());
    final orderedSelection = carriers
        .where(selected.contains)
        .toList(growable: false);
    final counts = {
      for (final carrier in orderedSelection)
        carrier: (accountCounts[carrier] ?? 1).clamp(1, 4).toInt(),
    };
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    final canContinue = orderedSelection.isNotEmpty && total <= 4;
    final title = isInitialSetup ? '先选好你的运营商' : '管理运营商';
    const subtitle = '选择运营商，再选择每家的号码数量。每家可选 1–4 张，合计最多 4 张。';

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(title),
                  if (demo) ...[
                    const SizedBox(height: 13),
                    const _DemoNotice(),
                  ],
                  const SizedBox(height: 15),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _mutedInk,
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ResortPaper(
                    color: const Color(0xFFF0F6F0),
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: ResortPalette.mint,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '这里只决定首页展示和查询哪些运营商，不读取 SIM 卡槽。每家运营商的查询支持状态会单独标明；取消选择只会隐藏对应卡片，不会删除已有本地记录或登录状态。',
                            style: TextStyle(
                              color: ResortPalette.ink,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '可选运营商',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '$total / 4 张已选择',
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (carriers.isEmpty)
                    const _EmptyCarriersCard()
                  else
                    for (var index = 0; index < carriers.length; index++) ...[
                      if (index > 0) const SizedBox(height: 11),
                      _CarrierOption(
                        key: ValueKey('carrier-option-${carriers[index].name}'),
                        carrier: carriers[index],
                        accent: _palette[index % _palette.length],
                        querySupported: querySupportedCarriers.contains(
                          carriers[index],
                        ),
                        selected: selected.contains(carriers[index]),
                        count: counts[carriers[index]] ?? 0,
                        onTap: () {
                          final next = {...selected};
                          if (!next.add(carriers[index])) {
                            next.remove(carriers[index]);
                          }
                          onSelectionChanged(Set.unmodifiable(next));
                        },
                      ),
                      if (selected.contains(carriers[index]))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (var count = 1; count <= 4; count++)
                                ChoiceChip(
                                  key: ValueKey(
                                    'carrier-count-${carriers[index].name}-$count',
                                  ),
                                  label: Text('$count 张'),
                                  selected: counts[carriers[index]] == count,
                                  onSelected:
                                      total -
                                              (counts[carriers[index]] ?? 1) +
                                              count >
                                          4
                                      ? null
                                      : onAccountCountsChanged != null
                                      ? (_) => onAccountCountsChanged!(
                                          Map.unmodifiable({
                                            ...counts,
                                            carriers[index]: count,
                                          }),
                                        )
                                      : count == 2 && onAddSecondAccount != null
                                      ? (_) =>
                                            onAddSecondAccount!(carriers[index])
                                      : null,
                                ),
                            ],
                          ),
                        ),
                    ],
                  const SizedBox(height: 22),
                  if (!canContinue)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        orderedSelection.isEmpty
                            ? '至少选择一家运营商后才能继续。'
                            : '合计最多 4 张，请减少号码数量后再保存。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      key: const ValueKey('carrier-selection-continue'),
                      onPressed: canContinue
                          ? () => onContinue(Set.unmodifiable(orderedSelection))
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: ResortPalette.mint,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE1DED8),
                        disabledForegroundColor: const Color(0xFF8C8A85),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                      label: Text(isInitialSetup ? '开始使用' : '保存选择'),
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

  Widget _buildHeader(String title) {
    return ResortMiniScene(
      title: title,
      subtitle: '把每个账号的余量收在一处',
      eyebrow: '海滨温泉 · 卡片整理所',
      mascotMessage: '每个账号都有自己的小房间。',
      height: 118,
    );
  }
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

class _CarrierOption extends StatelessWidget {
  const _CarrierOption({
    super.key,
    required this.carrier,
    required this.accent,
    required this.querySupported,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final Carrier carrier;
  final Color accent;
  final bool querySupported;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? accent : ResortPalette.border;
    return Semantics(
      button: true,
      selected: selected,
      label: '${carrier.label}，${selected ? '已选择$count张' : '未选择'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: resortMotionDuration(context, 160),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              color: selected ? ResortPalette.mintWash : ResortPalette.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
              boxShadow: selected
                  ? const []
                  : const [
                      BoxShadow(
                        color: Color(0x0C5B4637),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                ResortCarrierMark(carrier: carrier),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carrier.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF303845),
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        !querySupported
                            ? selected
                                  ? '已加入首页 · 余额查询接入中'
                                  : '余额查询接入中'
                            : selected
                            ? '已加入 $count 张 · 下方选择数量'
                            : '点按即可选择',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF858A93),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: resortMotionDuration(context, 160),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent : Colors.white,
                    border: Border.all(
                      color: selected ? accent : const Color(0xFFD7D1C8),
                      width: selected ? 0 : 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCarriersCard extends StatelessWidget {
  const _EmptyCarriersCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFECE4DA)),
      ),
      child: const Text(
        '目前没有可选择的运营商。',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF777D87), fontSize: 13),
      ),
    );
  }
}
