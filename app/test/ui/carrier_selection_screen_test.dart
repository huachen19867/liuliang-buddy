import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/ui/carrier_selection_screen.dart';

void main() {
  setUpAll(_loadPreviewFonts);

  testWidgets('首次选择页清楚说明用途并标记演示数据', (tester) async {
    await tester.pumpWidget(_host(selected: {Carrier.mobile}, demo: true));
    await tester.pumpAndSettle();

    expect(find.text('先选好你的运营商'), findsOneWidget);
    expect(find.text('界面演示 · 非真实流量'), findsOneWidget);
    expect(find.textContaining('可以只选一家，也可以同时选几家'), findsOneWidget);
    expect(find.textContaining('不读取 SIM 卡槽'), findsOneWidget);
    expect(find.text('中国移动'), findsOneWidget);
    expect(find.text('中国广电'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('支持选择单家或多家并将当前选择交给继续回调', (tester) async {
    final changes = <Set<Carrier>>[];
    final submitted = <Set<Carrier>>[];
    await tester.pumpWidget(
      _host(
        selected: {Carrier.mobile},
        onChanged: changes.add,
        onContinue: submitted.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('carrier-option-broadnet')),
    );
    await tester.tap(find.byKey(const ValueKey('carrier-option-broadnet')));
    await tester.pumpAndSettle();
    expect(changes, hasLength(1));
    expect(changes.single, {Carrier.mobile, Carrier.broadnet});

    await tester.tap(find.byKey(const ValueKey('carrier-selection-continue')));
    await tester.pumpAndSettle();
    expect(submitted, hasLength(1));
    expect(submitted.single, {Carrier.mobile, Carrier.broadnet});
    expect(tester.takeException(), isNull);
  });

  testWidgets('至少选一家；单运营商配置可独立继续并支持管理文案', (tester) async {
    final changes = <Set<Carrier>>[];
    final submitted = <Set<Carrier>>[];
    await tester.pumpWidget(
      _host(
        available: const [Carrier.broadnet],
        selected: const {},
        isInitialSetup: false,
        onChanged: changes.add,
        onContinue: submitted.add,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('管理运营商'), findsOneWidget);
    expect(find.text('保存选择'), findsOneWidget);
    expect(find.text('中国移动'), findsNothing);
    expect(find.text('至少选择一家运营商后才能继续。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('carrier-selection-continue')),
          )
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('carrier-option-broadnet')),
    );
    await tester.tap(find.byKey(const ValueKey('carrier-option-broadnet')));
    await tester.pumpAndSettle();
    expect(changes.single, {Carrier.broadnet});
    await tester.tap(find.byKey(const ValueKey('carrier-selection-continue')));
    await tester.pumpAndSettle();
    expect(submitted.single, {Carrier.broadnet});
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 像素小屏的大字布局可滚动且没有溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(selected: {Carrier.mobile}, textScale: 1.4));
    await tester.pumpAndSettle();

    expect(find.text('先选好你的运营商'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('carrier-selection-continue')),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _host({
  List<Carrier> available = const [Carrier.mobile, Carrier.broadnet],
  required Set<Carrier> selected,
  ValueChanged<Set<Carrier>>? onChanged,
  ValueChanged<Set<Carrier>>? onContinue,
  bool isInitialSetup = true,
  bool demo = false,
  double textScale = 1,
}) {
  var selectedState = selected;
  return MaterialApp(
    home: StatefulBuilder(
      builder: (context, setState) => MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: CarrierSelectionScreen(
          availableCarriers: available,
          selectedCarriers: selectedState,
          onSelectionChanged: (next) {
            setState(() => selectedState = next);
            onChanged?.call(next);
          },
          onContinue: onContinue ?? (_) {},
          isInitialSetup: isInitialSetup,
          demo: demo,
        ),
      ),
    ),
  );
}

Future<void> _loadPreviewFonts() async {
  const materialIconsPath =
      r'D:\AI\tools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
  final materialIconsFile = File(materialIconsPath);
  if (await materialIconsFile.exists()) {
    final materialIconsBytes = await materialIconsFile.readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(materialIconsBytes)))).load();
  }

  const paths = [r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\simhei.ttf'];
  for (final path in paths) {
    final fontFile = File(path);
    if (await fontFile.exists()) {
      final bytes = await fontFile.readAsBytes();
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      await (FontLoader('PreviewChinese')..addFont(Future.value(data))).load();
      break;
    }
  }
}
