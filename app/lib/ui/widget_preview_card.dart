import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../data/models.dart';

/// A native-widget feature entry with a visual-only preview.
///
/// The preview deliberately contains no traffic values. Its colored bars are
/// decorative placeholders and do not read or imply account data.
class WidgetPreviewCard extends StatelessWidget {
  const WidgetPreviewCard({
    super.key,
    required this.widgetSupported,
    this.selectedCarriers = Carrier.values,
    this.selectedAccountLabels,
    this.onAddWidget,
  });

  final bool widgetSupported;
  final List<Carrier> selectedCarriers;
  final List<String>? selectedAccountLabels;
  final VoidCallback? onAddWidget;

  bool get _canAdd => widgetSupported && onAddWidget != null;

  String get _hint {
    if (!widgetSupported) return '请在安卓手机或 iPhone 添加';
    if (onAddWidget == null) return '桌面卡片入口暂不可用';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return '长按主屏幕→添加小组件→流量小伙伴；轻点卡片打开应用查询';
    }
    return '点卡片刷新；若系统没弹窗，长按桌面空白处→小组件→流量小伙伴';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5EF),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFEAECE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F0F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  color: Color(0xFF6482A7),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '流量放在桌面',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF303B4A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '少一步打开，最近查询一眼可见',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF777D87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _WidgetCardIllustration(
            selectedCarriers: selectedCarriers,
            accountLabels: selectedAccountLabels,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _canAdd ? onAddWidget : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF526B85),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE4E6E4),
              disabledForegroundColor: const Color(0xFF898E94),
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.add_to_home_screen_rounded, size: 18),
            label: const Text('添加桌面卡片'),
          ),
          const SizedBox(height: 7),
          Text(
            _hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF777D87),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetCardIllustration extends StatelessWidget {
  const _WidgetCardIllustration({
    required this.selectedCarriers,
    this.accountLabels,
  });

  final List<Carrier> selectedCarriers;
  final List<String>? accountLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .91),
            const Color(0xFFEAF0F2).withValues(alpha: .84),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .92)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C3C5060),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '桌面卡片样式预览',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF556476),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '示意',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF75818E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '— —',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF516174),
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '最近一次查询',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF7E8792),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 7,
                child: selectedCarriers.isEmpty
                    ? const Text(
                        '尚未选择运营商',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF737D89),
                          fontSize: 10,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var index = 0;
                            index < selectedCarriers.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 8),
                            _WidgetColorBar(
                              label:
                                  accountLabels != null &&
                                      index < accountLabels!.length
                                  ? accountLabels![index]
                                  : selectedCarriers[index].label,
                              color: _carrierColor(selectedCarriers[index]),
                              fraction: .28 - (index % 4) * .035,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WidgetColorBar extends StatelessWidget {
  const _WidgetColorBar({
    required this.label,
    required this.color,
    required this.fraction,
  });

  final String label;
  final Color color;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF737D89),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: .16),
              semanticsLabel: '$label 流量示意',
            ),
          ),
        ),
      ],
    );
  }
}

Color _carrierColor(Carrier carrier) => const [
  Color(0xFF4E83D9),
  Color(0xFFE58C79),
  Color(0xFF63A68C),
  Color(0xFF8B7AC7),
][carrier.index % 4];
