@Tags(['acceptance'])
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/main.dart';
import 'package:liuliang_app/services/carrier_web.dart';
import 'package:liuliang_app/services/page_probe.dart';
import 'package:liuliang_app/services/widget_bridge.dart';
import 'package:liuliang_app/ui/carrier_browser_shell.dart';
import 'package:liuliang_app/ui/carrier_selection_screen.dart';
import 'package:liuliang_app/ui/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Reuse the plugin-boundary approach from web_query_round_flow_test.dart.
// The real FlowHome owns account identity, navigation, prompts and storage.
class _PromptPlatform extends InAppWebViewPlatform {
  final controllers = <_PromptController>[];

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    final controller = _PromptController(params);
    controllers.add(controller);
    return _PromptWidget(params, controller);
  }
}

class _PromptWidget extends PlatformInAppWebViewWidget {
  _PromptWidget(super.params, this.controller) : super.implementation();
  final _PromptController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.created) {
      controller.created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        params.onWebViewCreated?.call(controllerFromPlatform(controller));
      });
    }
    return const SizedBox.expand();
  }

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _PromptController extends PlatformInAppWebViewController {
  _PromptController(this.viewParams)
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'prompt-fixture'),
      );

  final PlatformInAppWebViewWidgetCreationParams viewParams;
  final handlers = <String, JavaScriptHandlerCallback>{};
  final loadedUrls = <String>[];
  bool created = false;
  WebUri currentUrl = WebUri(mobileQueryUrl);

  Future<dynamic> prompt(String mask, {String pageUrl = mobileLoginUrl}) async =>
      handlers['oneKeyPrompt']!([
        {'pageUrl': pageUrl, 'maskedPhone': mask},
      ]);

  void visit(String url) {
    currentUrl = WebUri(url);
    viewParams.onUpdateVisitedHistory?.call(
      InAppWebViewController.fromPlatform(platform: this),
      currentUrl,
      false,
    );
  }

  @override
  Future<WebUri?> getUrl() async => currentUrl;

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    currentUrl = urlRequest.url!;
    loadedUrls.add(currentUrl.toString());
  }

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) => handlers[handlerName] = callback;

  @override
  Future<void> addUserScript({required UserScript userScript}) async {}

  @override
  Future<void> removeUserScriptsByGroupName({required String groupName}) async {}

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async => null;

  @override
  Future<void> clearFocus() async {}

  @override
  Future<void> stopLoading() async {}

  @override
  void dispose({bool isKeepAlive = false}) {}
}

DashboardScreen _dashboard(WidgetTester tester) =>
    tester.widget<DashboardScreen>(find.byType(DashboardScreen));

CarrierBrowserShell _shell(WidgetTester tester) =>
    tester.widget<CarrierBrowserShell>(find.byType(CarrierBrowserShell));

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void _acceptanceWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  test('mask with internal revealed digits must not produce a false match', () {
    expect(
      compareMobileOneKeyMask('13812341234', '138**9**1234'),
      isNot(MobileOneKeyMatch.match),
      reason: 'The displayed 9 contradicts the stored number; unsupported masks '
          'may return unknown but cannot authorize a match.',
    );
  });

  test('mask length must not falsely confirm another length of phone', () {
    expect(
      compareMobileOneKeyMask('138991234', '138****1234'),
      isNot(MobileOneKeyMatch.match),
      reason: 'A seven-to-fifteen-digit account is allowed, but this mask '
          'cannot confirm a nine-digit number as the shown eleven-digit one.',
    );
  });

  late _PromptPlatform platform;
  late InAppWebViewPlatform? previousPlatform;
  const channels = [
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    WidgetBridge.channel,
    MethodChannel('cn.liuliang/background_refresh_schedule'),
    MethodChannel('cn.liuliang/notifications'),
    MethodChannel('cn.liuliang/system_surfaces'),
    MethodChannel('com.pichillilorenzo/flutter_inappwebview_webviewfeature'),
  ];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    previousPlatform = InAppWebViewPlatform.instance;
    platform = _PromptPlatform();
    InAppWebViewPlatform.instance = platform;
    FlutterSecureStorage.setMockInitialValues({});
    final selection = CarrierSelection.complete([Carrier.mobile]);
    final accounts = CarrierAccounts.fromSelection(selection).updateIdentity(
      'mobile',
      note: '验收卡',
      phoneNumber: '13812341234',
    );
    SharedPreferences.setMockInitialValues({
      'carrier_selection': selection.toStorageString(),
      CarrierAccounts.storageKey: accounts.toStorageString(),
      'connected_mobile': true,
      'snapshot_mobile': jsonEncode(
        CarrierSnapshot(
          carrier: Carrier.mobile,
          status: QueryStatus.authExpired,
        ).toJson(),
      ),
      'background_refresh_minutes': 0,
      'reminders': false,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'consumeLaunchRefresh') return false;
        if (call.method == 'deleteAccountProfiles') return true;
        return null;
      });
    }
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    InAppWebViewPlatform.instance = previousPlatform ?? _PromptPlatform();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<_PromptController> open(WidgetTester tester) async {
    await tester.pumpWidget(const FlowBuddyApp());
    await _drain(tester);
    _dashboard(tester).onConnectAccount!('mobile');
    await _drain(tester);
    final controller = platform.controllers.last;
    controller.visit(mobileLoginUrl);
    await _drain(tester);
    expect(controller.handlers, contains('oneKeyPrompt'));
    return controller;
  }

  _acceptanceWidgets('matching popup is user driven and official page can close', (
    tester,
  ) async {
    final controller = await open(tester);
    await controller.prompt('138****1234');
    await _drain(tester);
    expect(_shell(tester).message, contains('与该账号一致'));
    expect(find.byType(AlertDialog), findsNothing);
    _shell(tester).onClose();
    await _drain(tester);
    expect(find.byType(CarrierBrowserShell), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  _acceptanceWidgets('mismatch alert is dismissible and repeats are deduplicated', (
    tester,
  ) async {
    final controller = await open(tester);
    await controller.prompt('139****5678');
    await _drain(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(_shell(tester).message, contains('「暂不使用」'));
    await tester.tap(find.widgetWithText(TextButton, '知道了'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _drain(tester);
    expect(find.byType(AlertDialog), findsNothing);
    await controller.prompt('139****5678');
    await _drain(tester);
    expect(find.byType(AlertDialog), findsNothing);
    _shell(tester).onClose();
    await _drain(tester);
    expect(find.byType(CarrierBrowserShell), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  _acceptanceWidgets('hidden official page cannot raise popup guidance', (tester) async {
    final controller = await open(tester);
    _shell(tester).onClose();
    await _drain(tester);
    await controller.prompt('139****5678');
    await _drain(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CarrierBrowserShell), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  _acceptanceWidgets('leaving popup login route clears its obsolete hint', (
    tester,
  ) async {
    final controller = await open(tester);
    await controller.prompt('138****1234');
    await _drain(tester);
    expect(_shell(tester).message, contains('官网已弹出'));
    // The production JS stops polling on this route and emits no hide event.
    controller.visit(mobileQueryUrl);
    await _drain(tester);
    expect(_shell(tester).message, isNot(contains('官网已弹出')));
    await tester.pumpWidget(const SizedBox());
  });

  _acceptanceWidgets('starting query clears old authorization popup hint', (
    tester,
  ) async {
    final controller = await open(tester);
    await controller.prompt('138****1234');
    await _drain(tester);
    _shell(tester).onQuery();
    await _drain(tester);
    expect(controller.currentUrl.toString(), mobileQueryUrl);
    expect(_shell(tester).message, isNot(contains('官网已弹出')));
    await tester.pumpWidget(const SizedBox());
  });

  _acceptanceWidgets('late login payload on current query page must be rejected', (
    tester,
  ) async {
    final controller = await open(tester);
    controller.visit(mobileQueryUrl);
    await _drain(tester);
    await controller.prompt('139****5678');
    await _drain(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(_shell(tester).message, isNot(contains('139****5678')));
    await tester.pumpWidget(const SizedBox());
  });

  _acceptanceWidgets('updated account phone is used by the existing bridge handler', (
    tester,
  ) async {
    final controller = await open(tester);
    _dashboard(tester).onEditAccount!('mobile');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _drain(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '13812345678');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _drain(tester);
    expect(
      _dashboard(tester).accountEntries!.single.account.phoneNumber,
      '13812345678',
    );
    await controller.prompt('138****1234');
    await _drain(tester);
    expect(_shell(tester).message, contains('号码不一致'));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  _acceptanceWidgets('old bridge handler cannot contaminate rebuilt account page', (
    tester,
  ) async {
    final old = await open(tester);
    final oldHandler = old.handlers['oneKeyPrompt']!;
    _shell(tester).onClose();
    await _drain(tester);
    _dashboard(tester).onManageCarriers!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _drain(tester);
    final selection = tester.widget<CarrierSelectionScreen>(
      find.byType(CarrierSelectionScreen),
    );
    selection.onContinue(selection.selectedCarriers);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _drain(tester);
    _dashboard(tester).onConnectAccount!('mobile');
    await _drain(tester);
    expect(platform.controllers.last, isNot(same(old)));
    platform.controllers.last.visit(mobileLoginUrl);
    await _drain(tester);
    await Future<dynamic>.value(oldHandler([
      {'pageUrl': mobileLoginUrl, 'maskedPhone': '139****5678'},
    ]));
    await _drain(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(_shell(tester).message, isNot(contains('139****5678')));
    await tester.pumpWidget(const SizedBox());
  });
}
