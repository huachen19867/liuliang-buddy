import 'package:flutter/material.dart';

import '../data/models.dart';

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
    required this.selectedCarriers,
    required this.onSelectionChanged,
    required this.onContinue,
    this.isInitialSetup = true,
    this.demo = false,
  });

  final List<Carrier> availableCarriers;
  final List<Carrier> querySupportedCarriers;
  final Set<Carrier> selectedCarriers;
  final ValueChanged<Set<Carrier>> onSelectionChanged;
  final ValueChanged<Set<Carrier>> onContinue;
  final bool isInitialSetup;
  final bool demo;

  static const _ink = Color(0xFF293448);
  static const _mutedInk = Color(0xFF777D87);
  static const _canvas = Color(0xFFFFF9F1);
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
    final canContinue = orderedSelection.isNotEmpty;
    final title = isInitialSetup ? '先选好你的运营商' : '管理运营商';
    final subtitle = isInitialSetup
        ? '选择正在使用的运营商，可以只选一家，也可以同时选几家。'
        : '选择要在首页展示和查询的运营商，至少保留一家。';

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(title),
                  if (demo) ...[
                    const SizedBox(height: 20),
                    const _DemoNotice(),
                  ],
                  const SizedBox(height: 23),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _mutedInk,
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBDD),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0xFFF4DCCB)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Color(0xFFBA785E),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '这里只决定首页展示和查询哪些运营商，不读取 SIM 卡槽。每家运营商的查询支持状态会单独标明；取消选择只会隐藏对应卡片，不会删除已有本地记录或登录状态。',
                            style: TextStyle(
                              color: Color(0xFF765B50),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
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
                        '${orderedSelection.length} 家已选择',
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
                        onTap: () {
                          final next = {...selected};
                          if (!next.add(carriers[index])) {
                            next.remove(carriers[index]);
                          }
                          onSelectionChanged(Set.unmodifiable(next));
                        },
                      ),
                    ],
                  const SizedBox(height: 22),
                  if (!canContinue)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        '至少选择一家运营商后才能继续。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                        backgroundColor: const Color(0xFF4E83D9),
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
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6D7),
            borderRadius: BorderRadius.circular(19),
          ),
          child: const Center(
            child: Icon(
              Icons.water_drop_rounded,
              color: Color(0xFFE58C79),
              size: 31,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                '挑选你想一起关注的流量伙伴',
                style: TextStyle(color: _mutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
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

class _CarrierOption extends StatelessWidget {
  const _CarrierOption({
    super.key,
    required this.carrier,
    required this.accent,
    required this.querySupported,
    required this.selected,
    required this.onTap,
  });

  final Carrier carrier;
  final Color accent;
  final bool querySupported;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? accent : const Color(0xFFECE4DA);
    return Semantics(
      button: true,
      selected: selected,
      label: '${carrier.label}，${selected ? '已选择' : '未选择'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF1E8) : Colors.white,
              borderRadius: BorderRadius.circular(21),
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
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.signal_cellular_alt_rounded,
                    color: accent,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
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
                            ? '已加入首页'
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
                  duration: const Duration(milliseconds: 160),
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
