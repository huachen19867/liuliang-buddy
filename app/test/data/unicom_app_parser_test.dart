import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/data/traffic_summary.dart';
import 'package:liuliang_app/data/unicom_app_parser.dart';

// Synthetic protocol fixtures. No account, token or captured user response.
void main() {
  const mb = 1024 * 1024;
  Map<String, dynamic> row({
    String name = '国内通用流量',
    Object? total = '1024',
    Object? used = '256',
    Object? remaining = '768',
    Map<String, dynamic> extra = const {},
  }) => {
    'feePolicyName': name,
    'total': total,
    'use': used,
    'remain': remaining,
    ...extra,
  };
  Map<String, dynamic> response(List<Map<String, dynamic>> details) => {
    'code': '0000',
    'resources': [
      {'type': 'flow', 'details': details},
    ],
  };

  test('exact App endpoint MB schema retains total and remaining', () {
    final queriedAt = DateTime.utc(2026, 10, 2);
    final snapshot = parseUnicomAppPackage(
      response([row()]),
      queriedAt: queriedAt,
      phoneMasked: '138****1234',
    );
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.queriedAt, queriedAt);
    expect(snapshot.phoneMasked, '138****1234');
    expect(snapshot.buckets.single.rawUnit, 'MB');
    expect(snapshot.generalRemainingBytes, 768 * mb);
    expect(snapshot.generalTotalBytes, 1024 * mb);
    expect(snapshot.balanceYuan, isNull);
  });

  test('remaining zero wins over positive total minus used', () {
    final snapshot = parseUnicomAppPackage(response([row(remaining: 0)]));
    expect(snapshot.generalRemainingBytes, 0);
    expect(snapshot.buckets.single.isUnlimited, isFalse);
  });

  test('derive remaining only when absent and total/use are comparable', () {
    final snapshot = parseUnicomAppPackage(response([row(remaining: null)]));
    expect(snapshot.generalRemainingBytes, 768 * mb);
    expect(snapshot.message, contains('总量减已用量'));
    for (final remaining in ['', '-1', 'NaN', true]) {
      expect(
        parseUnicomAppPackage(response([row(remaining: remaining)])).status,
        QueryStatus.error,
        reason: '$remaining must not be silently recomputed',
      );
    }
  });

  test('explicit byte units are honored; unknown units never inherit MB', () {
    final snapshot = parseUnicomAppPackage(
      response([
        row(total: 2, used: 0.5, remaining: 1.5, extra: {'unit': 'GB'}),
      ]),
    );
    expect(snapshot.generalRemainingBytes, 1536 * mb);
    for (final unit in [null, '', '03', '分钟', 'TB', true]) {
      expect(
        parseUnicomAppPackage(
          response([
            row(extra: {'unit': unit}),
          ]),
        ).status,
        QueryStatus.error,
        reason: '$unit',
      );
    }
    final resourceUnit = response([row()]);
    (resourceUnit['resources'] as List).single['unit'] = 'KB';
    expect(
      parseUnicomAppPackage(resourceUnit).generalRemainingBytes,
      768 * 1024,
    );
  });

  test('unlimited requires an explicit value, not zero or a package title', () {
    final explicit = parseUnicomAppPackage(
      response([row(total: '不限量', remaining: null)]),
    );
    expect(explicit.status, QueryStatus.success);
    expect(explicit.hasUnlimitedAllowance, isTrue);
    expect(explicit.generalRemainingBytes, isNull);
    final zero = parseUnicomAppPackage(
      response([row(name: '通用不限量套餐', total: 0, used: 0, remaining: 0)]),
    );
    expect(zero.generalRemainingBytes, 0);
    expect(zero.hasUnlimitedAllowance, isFalse);
    for (final total in [-1, '99999999999999999']) {
      final snapshot = parseUnicomAppPackage(
        response([row(total: total, remaining: null)]),
      );
      expect(snapshot.status, QueryStatus.error);
      expect(snapshot.hasUnlimitedAllowance, isFalse);
    }
    final limitedFlag = parseUnicomAppPackage(
      response([
        row(extra: {'limited': 1}),
      ]),
    );
    expect(limitedFlag.hasUnlimitedAllowance, isFalse);
  });

  test('directed name wins; absent category evidence remains unknown', () {
    final snapshot = parseUnicomAppPackage(
      response([
        row(),
        row(name: '国内流量', remaining: 100, extra: {'flowType': '1'}),
        row(name: '通用套餐', remaining: 50, extra: {'addUpItemName': '视频定向流量'}),
      ]),
    );
    expect(snapshot.buckets.map((entry) => entry.kind), [
      BucketKind.general,
      BucketKind.unknown,
      BucketKind.directed,
    ]);
    expect(snapshot.generalRemainingBytes, 768 * mb);
    expect(
      summarizeTrafficGroup(snapshot, BucketKind.directed).remainingBytes,
      50 * mb,
    );
    expect(
      summarizeTrafficGroup(snapshot, BucketKind.unknown).remainingBytes,
      100 * mb,
    );
  });

  test('resource totals and voice amounts never enter flow categories', () {
    final data = response([row()]);
    final resources = data['resources'] as List;
    resources.single['remain'] = 100000;
    resources.single['total'] = 200000;
    resources.add({
      'type': 'voice',
      'details': [row(remaining: 300)],
    });
    final snapshot = parseUnicomAppPackage(data);
    expect(snapshot.buckets, hasLength(1));
    expect(snapshot.generalRemainingBytes, 768 * mb);
    expect(snapshot.allowances, isEmpty);
  });

  test('identical rows in flow and MlFlowdetailsList are counted once', () {
    final data = response([row()]);
    (data['resources'] as List).add({
      'type': 'MlFlowdetailsList',
      'details': [row()],
    });
    final snapshot = parseUnicomAppPackage(data);
    expect(snapshot.buckets, hasLength(1));
    expect(snapshot.generalRemainingBytes, 768 * mb);
  });

  test('conflicting duplicate packages suppress only the affected sum', () {
    final snapshot = parseUnicomAppPackage(
      response([
        row(),
        row(remaining: 700),
        row(name: '视频定向流量', remaining: 100),
      ]),
    );
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets, hasLength(2));
    expect(snapshot.generalRemainingBytes, isNull);
    expect(
      summarizeTrafficGroup(snapshot, BucketKind.general).isComplete,
      isFalse,
    );
    expect(
      summarizeTrafficGroup(snapshot, BucketKind.directed).remainingBytes,
      100 * mb,
    );
    expect(snapshot.message, contains('重复套餐'));
  });

  test('incomplete rows prevent partial general balance becoming a total', () {
    final snapshot = parseUnicomAppPackage(
      response([
        row(),
        row(name: '额外通用流量', extra: {'unit': 'unknown'}),
      ]),
    );
    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.buckets, hasLength(2));
    expect(snapshot.generalRemainingBytes, isNull);
    expect(summarizeTraffic(snapshot), isNull);
  });

  test('invalid amounts do not become zero or an unlimited sentinel', () {
    for (final remaining in [
      true,
      {},
      double.nan,
      double.infinity,
      'NaN',
      'Infinity',
      '1e6',
      '-1',
    ]) {
      expect(
        parseUnicomAppPackage(response([row(remaining: remaining)])).status,
        QueryStatus.error,
      );
    }
    expect(
      parseUnicomAppPackage(response([row(remaining: 2048)])).status,
      QueryStatus.error,
    );
    expect(
      parseUnicomAppPackage(
        response([row(used: 2048, remaining: null)]),
      ).status,
      QueryStatus.error,
    );
  });

  test('explicit authentication failures reject leftover success data', () {
    for (final code in ['999999', '999998', 'AUTH_FAILED', 'LOGIN_REQUIRED']) {
      final data = {
        ...response([row()]),
        'code': code,
      };
      final snapshot = parseUnicomAppPackage(data);
      expect(snapshot.status, QueryStatus.authExpired);
      expect(snapshot.buckets, isEmpty);
    }
    expect(
      parseUnicomAppPackage(response([row()]), httpStatus: 403).status,
      QueryStatus.authExpired,
    );
    expect(
      parseUnicomAppPackage(response([row()]), httpStatus: 502).status,
      QueryStatus.error,
    );
    expect(
      parseUnicomAppPackage({
        ...response([row()]),
        'dsc': '请重新登录',
      }).status,
      QueryStatus.authExpired,
    );
    expect(
      parseUnicomAppPackage({
        ...response([row()]),
        'code': 'ECS000047',
      }).status,
      QueryStatus.error,
    );
  });

  test('empty, malformed and unbounded detail resources fail safely', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'code': '0000'},
      response([]),
      {
        'code': '0000',
        'resources': [null],
      },
      {
        'code': '0000',
        'resources': [
          {'type': 'flow', 'details': null},
        ],
      },
      {
        'code': '0000',
        'resources': [
          {
            'type': 'flow',
            'details': [true],
          },
        ],
      },
      response(List.generate(501, (_) => row())),
    ]) {
      expect(parseUnicomAppPackage(data).status, QueryStatus.error);
    }
  });

  test('only confirmed curntbalancecust yuan is returned, including debt', () {
    for (final balance in <num>[0, 12.34, -5.25]) {
      expect(
        parseUnicomAppBalance({'code': '0000', 'curntbalancecust': '$balance'}),
        balance,
      );
    }
    for (final balance in [null, '', true, 'NaN', 'Infinity', '12元', '1.001']) {
      expect(
        parseUnicomAppBalance({'code': '0000', 'curntbalancecust': balance}),
        isNull,
      );
    }
    expect(
      parseUnicomAppBalance({
        'code': '0000',
        'balance': 50,
        'realfeecustnew': 8,
      }),
      isNull,
    );
    expect(
      parseUnicomAppBalance({'code': '999999', 'curntbalancecust': '50'}),
      isNull,
    );
    expect(
      parseUnicomAppBalance({
        'code': '0000',
        'curntbalancecust': '50',
      }, httpStatus: 500),
      isNull,
    );
  });

  test('fee failure leaves a successful package snapshot intact', () {
    final snapshot = parseUnicomAppPackage(response([row()]));
    final result = snapshot.copyWith(
      balanceYuan: parseUnicomAppBalance({'code': '999998'}),
    );
    expect(result.status, QueryStatus.success);
    expect(result.generalRemainingBytes, 768 * mb);
    expect(result.balanceYuan, isNull);
  });
}
