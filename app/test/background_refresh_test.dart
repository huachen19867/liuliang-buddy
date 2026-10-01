import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/services/background_refresh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.liuliang/background_refresh_schedule');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'status reports execution separately from last balance timestamp',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'status');
            return {
              'intervalMinutes': 60,
              'lastStartedAt': 1000,
              'lastFinishedAt': 2000,
              'lastOutcome': 'no_result',
              'lastMessage': '',
            };
          });
      final status = await BackgroundRefreshScheduler.status();
      expect(status.outcome, 'no_result');
      expect(status.startedAt?.millisecondsSinceEpoch, 1000);
      expect(status.finishedAt?.millisecondsSinceEpoch, 2000);
      expect(status.label, contains('未取得新数据'));
    },
  );

  test('an interrupted run never presents an unverified success', () {
    final status = BackgroundRefreshStatus.fromMap({
      'lastStartedAt': 1000,
      'lastFinishedAt': 0,
      'lastOutcome': 'running',
    });
    expect(status.finishedAt, isNull);
    expect(status.label, contains('尚未确认'));
    expect(BackgroundRefreshStatus.fromMap({}).startedAt, isNull);
    expect(
      BackgroundRefreshStatus.fromMap({
        'lastOutcome': 'cleanup_required',
      }).label,
      contains('已暂停'),
    );
  });

  test('only supported intervals survive preference restore', () {
    expect(
      BackgroundRefreshInterval.fromMinutes(5),
      BackgroundRefreshInterval.off,
    );
    expect(
      BackgroundRefreshInterval.fromMinutes(60),
      BackgroundRefreshInterval.oneHour,
    );
    expect(
      BackgroundRefreshInterval.fromMinutes(120),
      BackgroundRefreshInterval.twoHours,
    );
    expect(
      BackgroundRefreshInterval.fromMinutes(1440),
      BackgroundRefreshInterval.oneDay,
    );
  });
}
