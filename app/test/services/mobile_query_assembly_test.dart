import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/carrier_accounts.dart';
import 'package:liuliang_app/data/carrier_selection.dart';
import 'package:liuliang_app/services/mobile_query_assembly.dart';
import 'package:liuliang_app/services/widget_bridge.dart';

void main() {
  final flow = CarrierSnapshot(
    carrier: Carrier.mobile,
    status: QueryStatus.success,
    queriedAt: DateTime(2026, 10, 2),
    buckets: const [
      TrafficBucket(
        name: '通用流量',
        kind: BucketKind.general,
        remainingBytes: 1073741824,
        rawUnit: 'GB',
      ),
    ],
  );
  test(
    'balance before flow survives cache and widget publication including zero',
    () async {
      final query = MobileQueryAssembly()..acceptBalance(0);
      expect(query.claimFlow(), isTrue);
      final merged = await query.assemble(flow);
      final restored = CarrierSnapshot.fromJson(merged.toJson());
      expect(restored.balanceYuan, 0);
      expect(restored.buckets.single.remainingBytes, 1073741824);
      final selection = CarrierSelection.complete([Carrier.mobile]);
      final payload = buildWidgetPayload(
        [restored],
        thresholdGb: 5,
        selection: selection,
        accounts: CarrierAccounts.fromSelection(selection),
        accountSnapshots: {'mobile': restored},
      );
      expect((payload['instances'] as List).first['balanceYuan'], 0);
    },
  );
  test('late balance merges without losing flow or query time', () async {
    final query = MobileQueryAssembly();
    final waiting = query.assemble(flow);
    query.acceptBalance(-2.50);
    final merged = await waiting;
    expect(merged.balanceYuan, -2.5);
    expect(merged.queriedAt, flow.queriedAt);
    expect(merged.generalRemainingBytes, flow.generalRemainingBytes);
  });
  test(
    'missing or invalid balance has bounded fallback and clears old money',
    () async {
      final query = MobileQueryAssembly()..acceptBalance(null);
      final merged = await query.assemble(
        flow.copyWith(balanceYuan: 99),
        wait: Duration.zero,
      );
      expect(merged.status, QueryStatus.success);
      expect(merged.balanceYuan, isNull);
      expect(merged.message, contains('话费余额暂未取得'));
      expect(merged.generalRemainingBytes, 1073741824);
    },
  );
  test('cancellation prevents money leaking into another query', () async {
    final query = MobileQueryAssembly()
      ..acceptBalance(10)
      ..cancel();
    final merged = await query.assemble(flow);
    expect(merged.balanceYuan, isNull);
    expect(query.claimFlow(), isFalse);
    final next = MobileQueryAssembly();
    expect(
      (await next.assemble(flow, wait: Duration.zero)).balanceYuan,
      isNull,
    );
  });
  test('duplicate allowance response cannot settle the query twice', () {
    final query = MobileQueryAssembly();
    expect(query.claimFlow(), isTrue);
    expect(query.claimFlow(), isFalse);
  });
  test(
    'authentication failure never becomes a fresh balance success',
    () async {
      final query = MobileQueryAssembly()..acceptBalance(10);
      const failed = CarrierSnapshot(
        carrier: Carrier.mobile,
        status: QueryStatus.authExpired,
      );
      final merged = await query.assemble(failed);
      expect(merged.status, QueryStatus.authExpired);
      expect(merged.balanceYuan, isNull);
      expect(merged.queriedAt, isNull);
    },
  );
}
