import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  const expectedNames = {
    'ios-selection',
    'ios-dashboard',
    'ios-widget-guide',
    'ios-settings',
    'ios-failure',
  };
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      if (!expectedNames.contains(name) || bytes.isEmpty) return false;
      final output = File('build/ios-smoke/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
