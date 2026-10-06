import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/background_refresh_runner.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _ReadFailure { throws, hangs }

class _RunResult {
  const _RunResult({
    required this.report,
    required this.snapshot,
    required this.authRequired,
    required this.secureCalls,
    required this.events,
  });

  final Map<String, Object?> report;
  final CarrierSnapshot snapshot;
  final bool? authRequired;
  final List<MethodCall> secureCalls;
  final List<MethodCall> events;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const background = MethodChannel('cn.liuliang/background_refresh');
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  Future<_RunResult> runCase(_ReadFailure failure) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final previousPlatform = FlutterSecureStoragePlatform.instance;
    final previousTargetPlatform = debugDefaultTargetPlatformOverride;
    final secureCalls = <MethodCall>[];
    final events = <MethodCall>[];
    final pendingReads = <Completer<String?>>[];
    final terminalEvent = Completer<void>();
    Map<String, Object?>? completionReport;
    var failed = false;
    final selection = CarrierSelection.complete([Carrier.unicom]);
    final accounts = CarrierAccounts.fromSelection(selection).updateIdentity(
      Carrier.unicom.name,
      note: '测试账号',
      phoneNumber: '13800000000',
    );
    final account = accounts.find(Carrier.unicom.name)!;
    final oldTime = DateTime(2026, 10, 5, 8, 30);
    final oldSnapshot = CarrierSnapshot(
      carrier: Carrier.unicom,
      status: QueryStatus.success,
      queriedAt: oldTime,
      balanceYuan: 9.25,
      buckets: const [
        TrafficBucket(
          name: '旧通用流量',
          kind: BucketKind.general,
          remainingBytes: 64 * 1024 * 1024,
          totalBytes: 4 * 1024 * 1024 * 1024,
        ),
      ],
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterSecureStoragePlatform.instance = MethodChannelFlutterSecureStorage();
    SharedPreferences.setMockInitialValues({
      'carrier_selection': selection.toStorageString(),
      CarrierAccounts.storageKey: accounts.toStorageString(),
      account.connectedKey: true,
      account.snapshotKey: jsonEncode(oldSnapshot.toJson()),
      'unicom_query_method_${account.id}': 'app',
      'background_refresh_minutes': 60,
      'background_auth_required_${account.id}': false,
    });

    messenger.setMockMethodCallHandler(secure, (call) async {
      secureCalls.add(call);
      if (call.method == 'read') {
        if (failure == _ReadFailure.throws) {
          throw PlatformException(code: 'synthetic-storage-read-failure');
        }
        final pending = Completer<String?>();
        pendingReads.add(pending);
        return pending.future;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(background, (call) async {
      events.add(call);
      switch (call.method) {
        case 'isTaskCurrent':
          return true;
        case 'completed':
          completionReport = Map<String, Object?>.from(call.arguments as Map);
          if (!terminalEvent.isCompleted) terminalEvent.complete();
          return null;
        case 'failed':
          failed = true;
          if (!terminalEvent.isCompleted) terminalEvent.complete();
          return null;
      }
      return null;
    });

    try {
      await runBackgroundRefreshEntrypoint();
      final startReply = await messenger.handlePlatformMessage(
        background.name,
        background.codec.encodeMethodCall(const MethodCall('start')),
        null,
      );
      expect(background.codec.decodeEnvelope(startReply!), isTrue);
      await terminalEvent.future;
      if (failed || completionReport == null) {
        throw StateError('background runner did not complete the query');
      }

      // Resolve the native replies left behind by Future.timeout so the test
      // messenger has no pending secure-storage messages after the run.
      for (final pending in pendingReads) {
        if (!pending.isCompleted) pending.complete(null);
      }
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final savedSnapshot = CarrierSnapshot.fromJson(
        jsonDecode(prefs.getString(account.snapshotKey)!)
            as Map<String, dynamic>,
      );
      return _RunResult(
        report: completionReport!,
        snapshot: savedSnapshot,
        authRequired: prefs.getBool('background_auth_required_${account.id}'),
        secureCalls: List.unmodifiable(secureCalls),
        events: List.unmodifiable(events),
      );
    } finally {
      for (final pending in pendingReads) {
        if (!pending.isCompleted) pending.complete(null);
      }
      messenger.setMockMethodCallHandler(secure, null);
      messenger.setMockMethodCallHandler(background, null);
      background.setMethodCallHandler(null);
      FlutterSecureStoragePlatform.instance = previousPlatform;
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
    }
  }

  void expectPreservedFailure(_RunResult result) {
    expect(result.report['outcome'], 'no_result');
    expect(result.authRequired, isFalse);
    expect(result.snapshot.status, QueryStatus.error);
    expect(result.snapshot.queriedAt, DateTime(2026, 10, 5, 8, 30));
    expect(result.snapshot.balanceYuan, 9.25);
    expect(result.snapshot.buckets.single.remainingBytes, 64 * 1024 * 1024);
    expect(result.snapshot.message, contains('本地会话'));
    expect(result.secureCalls.map((call) => call.method), everyElement('read'));
    expect(
      result.secureCalls.map((call) => (call.arguments as Map)['key']),
      everyElement('unicom_app_session_unicom'),
    );
    expect(result.events.first.method, 'ready');
    expect(result.events.last.method, 'completed');
    expect(result.events.last.arguments, result.report);
  }

  test(
    'throws on App-session reads preserve old data without auth gating',
    () async {
      final result = await runCase(_ReadFailure.throws);
      expectPreservedFailure(result);
      expect(result.secureCalls, hasLength(2));
    },
  );

  test('hung App-session reads time out twice and preserve old data', () async {
    final result = await runCase(_ReadFailure.hangs);
    expectPreservedFailure(result);
    expect(result.secureCalls, hasLength(2));
  });
}
