import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/ui/widget_preview_card.dart';

void main() {
  testWidgets(
    'shows separate labels for same-carrier accounts and manual add guidance',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var addCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WidgetPreviewCard(
                widgetSupported: true,
                selectedCarriers: const [Carrier.mobile, Carrier.mobile],
                selectedAccountLabels: const ['中国移动 1', '中国移动 2'],
                onAddWidget: () => addCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('中国移动 1'), findsOneWidget);
      expect(find.text('中国移动 2'), findsOneWidget);
      expect(find.textContaining('长按桌面空白处'), findsOneWidget);
      await tester.tap(find.text('添加桌面卡片'));
      expect(addCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
