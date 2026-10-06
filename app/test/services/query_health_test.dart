import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/query_health.dart';

void main() {
  final old = DateTime.utc(2026, 9, 30);
  QueryAccountHealth check(
    CarrierSnapshot snapshot, {
    bool cleanup = false,
    bool paused = false,
    bool checking = false,
    bool storage = false,
  }) => diagnoseQuery(
    accountId: 'mobile',
    label: '中国移动 1',
    carrier: Carrier.mobile,
    snapshot: snapshot,
    checking: checking,
    cleanupPending: cleanup,
    authenticationPaused: paused,
    foregroundOnly: false,
    storagePending: storage,
    lastAttemptAt: DateTime.utc(2026, 10, 6),
  );
  final valid = CarrierSnapshot(
    carrier: Carrier.mobile,
    status: QueryStatus.success,
    queriedAt: old,
    balanceYuan: 0,
    buckets: const [
      TrafficBucket(
        name: '通用流量',
        kind: BucketKind.general,
        remainingBytes: 0,
        rawUnit: 'GB',
      ),
    ],
  );
  test(
    'zero is healthy and attempt time never replaces old valid data time',
    () {
      final health = check(valid);
      expect(health.kind, QueryHealthKind.healthy);
      expect(health.lastValidDataAt, old);
      expect(health.lastAttemptAt, DateTime.utc(2026, 10, 6));
      final running = check(
        valid.copyWith(status: QueryStatus.loading),
        checking: true,
      );
      expect(running.kind, QueryHealthKind.checking);
      expect(running.action, QueryHealthAction.none);
      expect(running.lastValidDataAt, old);
    },
  );
  test('access rejection does not become authentication expiry', () {
    final denied = check(
      valid.copyWith(
        status: QueryStatus.error,
        message: 'HTTP 403 bearer SECRET phone 13812345678',
      ),
    );
    expect(denied.kind, QueryHealthKind.accessError);
    expect(denied.action, QueryHealthAction.retry);
    expect(denied.detail, isNot(contains('SECRET')));
    expect(denied.detail, isNot(contains('13812345678')));
    expect(check(valid, paused: true).kind, QueryHealthKind.loginExpired);
  });
  test(
    'incomplete fields preserve readable values without requesting re-login',
    () {
      final partial = check(
        valid.copyWith(
          balanceYuan: null,
          buckets: const [
            TrafficBucket(
              name: '已读项',
              kind: BucketKind.unknown,
              remainingBytes: 1,
              rawUnit: 'B',
            ),
            TrafficBucket(name: '缺项', kind: BucketKind.unknown),
          ],
        ),
      );
      expect(partial.kind, QueryHealthKind.unreadFields);
      expect(partial.detail, contains('1 项'));
      expect(partial.action, QueryHealthAction.inspectFields);
      expect(partial.lastValidDataAt, old);
    },
  );
  test('cleanup and storage failures have distinct real recovery actions', () {
    final blocked = check(valid, cleanup: true);
    expect(blocked.kind, QueryHealthKind.backgroundPaused);
    expect(blocked.action, QueryHealthAction.backgroundSettings);
    final localFailure = check(valid, storage: true);
    expect(localFailure.kind, QueryHealthKind.accessError);
    expect(localFailure.action, QueryHealthAction.retry);
    expect(localFailure.kind, isNot(QueryHealthKind.loginExpired));
  });
}
