import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadPreviewFonts() async {
  final sdkRoots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final String root) root,
    r'D:\AI\tools\flutter',
  ];
  var parent = File(Platform.resolvedExecutable).parent;
  while (parent.parent.path != parent.path) {
    sdkRoots.add(parent.path);
    parent = parent.parent;
  }
  File? materialIconsFile;
  for (final root in sdkRoots) {
    final candidate = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await candidate.exists()) {
      materialIconsFile = candidate;
      break;
    }
  }
  if (materialIconsFile == null) {
    throw StateError('Flutter Material Icons font was not found.');
  }
  final materialIconsBytes = await materialIconsFile.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(materialIconsBytes)))).load();

  final paths = [
    if (Platform.environment['LIULIANG_PREVIEW_CHINESE_FONT']
        case final String path)
      path,
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
    '/System/Library/Fonts/PingFang.ttc',
    '/System/Library/Fonts/STHeiti Medium.ttc',
    '/System/Library/Fonts/STHeiti Light.ttc',
    '/System/Library/Fonts/Supplemental/Songti.ttc',
  ];
  File? fontFile;
  for (final path in paths) {
    final candidate = File(path);
    if (await candidate.exists()) {
      fontFile = candidate;
      break;
    }
  }
  if (fontFile == null) {
    throw StateError(
      'Set LIULIANG_PREVIEW_CHINESE_FONT to a Chinese font for UI screenshots.',
    );
  }

  final bytes = await fontFile.readAsBytes();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  await (FontLoader('PreviewChinese')..addFont(Future.value(data))).load();
}
