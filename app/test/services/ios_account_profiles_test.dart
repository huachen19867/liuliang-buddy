import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/services/ios_account_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('secondary WebView sends its store identifier at creation', () {
    final primary = AccountWebViewSettings().toMap();
    final secondary = AccountWebViewSettings(
      profileName: 'liuliang_mobile_2',
    ).toMap();
    expect(primary.containsKey('liuliangAccountProfile'), isFalse);
    expect(secondary['liuliangAccountProfile'], 'liuliang_mobile_2');
    expect(secondary['incognito'], isFalse);
  });

  test('profile cleanup requires an affirmative native completion', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(IOSAccountProfiles.channel, (
      call,
    ) async {
      if (call.method == 'liuliangSupportsAccountProfiles') return true;
      if (call.method == 'liuliangDeleteAccountProfiles') return false;
      return null;
    });
    addTearDown(
      () =>
          messenger.setMockMethodCallHandler(IOSAccountProfiles.channel, null),
    );
    expect(await IOSAccountProfiles.supported(), isTrue);
    await expectLater(
      IOSAccountProfiles.clearAll(),
      throwsA(isA<PlatformException>()),
    );
  });
}
